# iOS Authentication Implementation Guide

## Overview
This guide covers the complete authentication implementation for the Calycal iOS app, including Apple Sign-In, state management, and backend integration.

## Architecture Overview

### Authentication Flow
```
1. User taps "Sign in with Apple"
2. iOS presents Apple Sign-In sheet
3. User authenticates with Apple
4. App receives Apple ID token
5. App sends token to backend (/functions/v1/auth/apple-signin)
6. Backend verifies token and creates/updates user
7. Backend returns session tokens
8. App stores tokens securely
9. App navigates to main interface
```

### State Management
```
AppState (ObservableObject)
├── AuthenticationState
│   ├── isAuthenticated: Bool
│   ├── currentUser: User?
│   ├── isLoading: Bool
│   └── error: String?
├── AuthManager (handles authentication logic)
└── TokenManager (handles secure token storage)
```

## Implementation Steps

### 1. Project Setup

#### Add Apple Sign-In Capability
1. Open your Xcode project
2. Select your target
3. Go to "Signing & Capabilities"
4. Click "+" and add "Sign in with Apple"

#### Add Required Frameworks
```swift
import AuthenticationServices
import Security
import Combine
```

### 2. Data Models

#### User Model
```swift
struct User: Codable, Identifiable {
    let id: String
    let email: String?
    let name: String?
    let appleId: String?
    let dailyCalorieGoal: Int?
    let dailyProteinGoal: Double?
    let dailyFatGoal: Double?
    let dailyCarbGoal: Double?
    let units: String?
    let timezoneOffset: Int?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case name
        case appleId = "apple_id"
        case dailyCalorieGoal = "daily_calorie_goal"
        case dailyProteinGoal = "daily_protein_goal"
        case dailyFatGoal = "daily_fat_goal"
        case dailyCarbGoal = "daily_carb_goal"
        case units
        case timezoneOffset = "timezone_offset"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

#### Session Model
```swift
struct Session: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}
```

#### Authentication Response
```swift
struct AuthResponse: Codable {
    let success: Bool
    let user: User?
    let session: Session?
    let error: String?
}
```

### 3. Secure Token Storage

#### KeychainManager
```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private let service = "com.calycal.app"
    private let account = "auth_tokens"
    
    private init() {}
    
    func saveTokens(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete existing tokens first
        SecItemDelete(query as CFDictionary)
        
        // Save new tokens
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    func loadTokens() throws -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return try JSONDecoder().decode(Session.self, from: data)
    }
    
    func deleteTokens() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
}
```

### 4. Authentication Manager

#### AuthManager
```swift
import AuthenticationServices
import Combine

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let backendURL = "YOUR_SUPABASE_URL"
    
    override init() {
        super.init()
        checkExistingSession()
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() {
        isLoading = true
        error = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut() {
        do {
            try KeychainManager.shared.deleteTokens()
            isAuthenticated = false
            currentUser = nil
        } catch {
            self.error = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Session Management
    
    private func checkExistingSession() {
        do {
            if let session = try KeychainManager.shared.loadTokens() {
                // Validate session and get current user
                validateSession(session)
            }
        } catch {
            print("Failed to load existing session: \(error)")
        }
    }
    
    private func validateSession(_ session: Session) {
        // Make API call to validate token and get current user
        guard let url = URL(string: "\(backendURL)/functions/v1/auth/profile") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        self.error = error.localizedDescription
                        self.signOut()
                    }
                },
                receiveValue: { response in
                    if response.success, let user = response.user {
                        self.currentUser = user
                        self.isAuthenticated = true
                    } else {
                        self.signOut()
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Backend Integration
    
    private func authenticateWithBackend(identityToken: String, user: ASAuthorizationAppleIDCredential) {
        guard let url = URL(string: "\(backendURL)/functions/v1/auth/apple-signin") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let authRequest = [
            "identityToken": identityToken,
            "user": [
                "id": user.user,
                "email": user.email,
                "name": user.fullName?.formatted()
            ]
        ] as [String: Any]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: authRequest)
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: AuthResponse.self, decoder: JSONDecoder())
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    self.isLoading = false
                    if case .failure(let error) = completion {
                        self.error = error.localizedDescription
                    }
                },
                receiveValue: { response in
                    if response.success, let session = response.session, let user = response.user {
                        do {
                            try KeychainManager.shared.saveTokens(session)
                            self.currentUser = user
                            self.isAuthenticated = true
                        } catch {
                            self.error = "Failed to save session: \(error.localizedDescription)"
                        }
                    } else {
                        self.error = response.error ?? "Authentication failed"
                    }
                }
            )
            .store(in: &cancellables)
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityToken = appleIDCredential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to get Apple ID credentials"
            isLoading = false
            return
        }
        
        authenticateWithBackend(identityToken: identityTokenString, user: appleIDCredential)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isLoading = false
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                self.error = "Sign in was canceled"
            case .failed:
                self.error = "Sign in failed"
            case .invalidResponse:
                self.error = "Invalid response from Apple"
            case .notHandled:
                self.error = "Sign in not handled"
            case .unknown:
                self.error = "Unknown error occurred"
            @unknown default:
                self.error = "Unexpected error occurred"
            }
        } else {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}
```

### 5. App State Management

#### AppState
```swift
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var authManager = AuthManager()
    
    var isAuthenticated: Bool {
        authManager.isAuthenticated
    }
    
    var currentUser: User? {
        authManager.currentUser
    }
    
    var isLoading: Bool {
        authManager.isLoading
    }
    
    var error: String? {
        authManager.error
    }
}
```

### 6. UI Implementation

#### SignInView
```swift
import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // App Logo and Title
            VStack(spacing: 20) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Calycal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your nutrition with AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign In Button
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            // Handle successful sign in
                            appState.authManager.signInWithApple()
                        }
                    case .failure(let error):
                        appState.authManager.error = error.localizedDescription
                    }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .padding(.horizontal, 40)
            
            if appState.isLoading {
                ProgressView()
                    .padding()
            }
            
            if let error = appState.error {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}
```

#### MainAppView
```swift
import SwiftUI

struct MainAppView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
            } else {
                SignInView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            // Check for existing session on app launch
            appState.authManager.checkExistingSession()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            DiaryView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Diary")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
    }
}
```

#### ProfileView
```swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(appState.currentUser?.name ?? "User")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(appState.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Settings Button
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Sign Out Button
                Button("Sign Out") {
                    appState.authManager.signOut()
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}
```

### 7. Network Layer

#### APIClient
```swift
import Foundation
import Combine

class APIClient {
    static let shared = APIClient()
    
    private let baseURL = "YOUR_SUPABASE_URL"
    private var session: Session?
    
    private init() {
        loadSession()
    }
    
    private func loadSession() {
        session = try? KeychainManager.shared.loadTokens()
    }
    
    func request<T: Codable>(_ endpoint: String, method: String = "GET", body: [String: Any]? = nil) -> AnyPublisher<T, Error> {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            return Fail(error: APIError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let session = session {
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

enum APIError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(Error)
}
```

### 8. Environment Configuration

#### Configuration
```swift
struct Configuration {
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    static let appleClientId = "com.calycal.app"
}
```

## Testing

### Unit Tests
```swift
import XCTest
@testable import Calycal

class AuthManagerTests: XCTestCase {
    var authManager: AuthManager!
    
    override func setUp() {
        super.setUp()
        authManager = AuthManager()
    }
    
    override func tearDown() {
        authManager = nil
        super.tearDown()
    }
    
    func testSignOut() {
        // Given
        authManager.isAuthenticated = true
        authManager.currentUser = User(id: "test", email: "test@example.com", name: "Test User")
        
        // When
        authManager.signOut()
        
        // Then
        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
    }
}
```

## Security Considerations

### Token Security
- Tokens are stored securely in the Keychain
- Tokens are automatically validated on app launch
- Failed token validation triggers sign out

### Apple Sign-In Security
- Apple ID tokens are verified on the backend
- User ID from Apple is validated against the token
- Secure token exchange with the backend

### Network Security
- All API calls use HTTPS
- Authorization headers are included for authenticated requests
- Error handling for network failures

## Troubleshooting

### Common Issues

1. **Apple Sign-In not working**
   - Verify "Sign in with Apple" capability is added
   - Check bundle identifier matches Apple Developer configuration
   - Ensure proper entitlements

2. **Token storage issues**
   - Check Keychain access permissions
   - Verify service and account identifiers
   - Handle Keychain errors gracefully

3. **Network errors**
   - Verify backend URL configuration
   - Check network connectivity
   - Handle API errors appropriately

### Debug Tips

1. Enable network logging in development
2. Use Xcode's network inspector
3. Add comprehensive error logging
4. Test with different Apple ID accounts

## Next Steps

1. Implement token refresh logic
2. Add offline support
3. Implement biometric authentication
4. Add user profile editing
5. Implement push notifications
6. Add analytics and crash reporting

This implementation provides a solid foundation for authentication in your iOS app with proper security, state management, and user experience. 
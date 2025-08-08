import Foundation
import AuthenticationServices
import Combine
import Supabase

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        checkExistingSession()
        testNetworkConnection() // Test network connectivity
    }
    
    // MARK: - Apple Sign-In
    
    func signInWithApple() {
        isLoading = true
        error = nil
        
        // Clear any cached sessions before Apple Sign-In to ensure we use anon key
        print("🧹 Clearing any cached sessions before Apple Sign-In...")
        do {
            try KeychainManager.shared.deleteTokens()
            print("✅ Cached sessions cleared")
        } catch {
            print("⚠️ Failed to clear cached sessions: \(error)")
        }
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func processAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
        guard let identityToken = credential.identityToken,
              let identityTokenString = String(data: identityToken, encoding: .utf8) else {
            error = "Failed to get Apple ID credentials"
            isLoading = false
            return
        }
        
        authenticateWithBackend(identityToken: identityTokenString, user: credential)
    }
    
    func signOut() {
        do {
            try KeychainManager.shared.deleteTokens()
            clearAppleIDCredentials()
            
            // Clear APIClient session
            APIClient.shared.clearSession()
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            
            print("✅ Sign out completed - all sessions cleared")
        } catch {
            DispatchQueue.main.async {
                self.error = "Failed to sign out: \(error.localizedDescription)"
            }
        }
    }
    
    func clearAllAuthenticationData() {
        do {
            // Clear keychain tokens
            try KeychainManager.shared.deleteTokens()
            
            // Clear Apple ID credentials
            clearAppleIDCredentials()
            
            // Reset app state
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.error = "✅ All authentication data cleared. You can now sign in fresh with Apple ID."
            }
            
            print("✅ All authentication data cleared successfully")
            print("ℹ️ Next time you try to sign in, you may see a 'canceled' error first - this is normal!")
        } catch {
            print("❌ Failed to clear authentication data: \(error)")
            DispatchQueue.main.async {
                self.error = "Failed to clear authentication data: \(error.localizedDescription)"
            }
        }
    }
    
    private func clearAppleIDCredentials() {
        // Clear Apple ID credentials from the system
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.createRequest() // This helps clear any cached state
        
        // You can also try to revoke Apple ID credentials if needed
        // Note: This requires user interaction and may not always work
        print("🔄 Apple ID credentials cleared")
    }
    
    func debugCurrentAuthenticationState() {
        print("🔍 === Authentication Debug Info ===")
        
        // Check if we have stored tokens
        if let session = try? KeychainManager.shared.loadTokens() {
            print("✅ Found stored session:")
            print("   - Access Token: \(String(session.accessToken.prefix(20)))...")
            print("   - Refresh Token: \(String(session.refreshToken.prefix(20)))...")
        } else {
            print("❌ No stored session found")
        }
        
        // Check authentication state
        print("📱 Current app state:")
        print("   - isAuthenticated: \(isAuthenticated)")
        print("   - currentUser: \(currentUser?.email ?? "nil")")
        print("   - isLoading: \(isLoading)")
        print("   - error: \(error ?? "nil")")
        
        print("🔍 === End Debug Info ===")
    }
    
    // MARK: - Session Management
    
    func checkExistingSession() {
        Task {
            do {
                guard let session = try KeychainManager.shared.loadTokens() else {
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                    return
                }
                
                // Update APIClient with loaded session
                APIClient.shared.updateSession(session)
                print("🔄 Loaded existing session and updated APIClient")
                
                // Validate session with backend
                guard let url = URL(string: "\(Configuration.supabaseURL)/functions/v1/auth-profile") else {
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    // Session is invalid, clear it
                    try KeychainManager.shared.deleteTokens()
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                    return
                }
                
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                
                DispatchQueue.main.async {
                    if authResponse.success, let user = authResponse.user {
                        self.currentUser = user
                        self.isAuthenticated = true
                    } else {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                }
            } catch {
                print("No existing session: \(error)")
                DispatchQueue.main.async {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    

    
    // MARK: - Network Testing
    
    func testNetworkConnection() {
        // Debug current authentication state first
        debugCurrentAuthenticationState()
        
        Task {
            do {
                // Test 1: Basic connectivity
                let urlString = "\(Configuration.supabaseURL)/rest/v1/"
                print("Testing connection to: \(urlString)")
                print("Using auth key: \(String(Configuration.supabaseAnonKey.prefix(20)))...")
                print("Full JWT payload: \(Configuration.supabaseAnonKey)")
                
                guard let url = URL(string: urlString) else {
                    print("Invalid URL")
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(Configuration.supabaseAnonKey, forHTTPHeaderField: "apikey")
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Network test - Status: \(httpResponse.statusCode)")
                    if httpResponse.statusCode != 200 {
                        print("Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
                    } else {
                        print("Network test successful!")
                    }
                } else {
                    print("Network test failed - Invalid response")
                }
                
                // Test 2: Functions endpoint
                await testFunctionsEndpoint()
                
            } catch {
                print("Network test failed: \(error)")
            }
        }
    }
    
    private func testFunctionsEndpoint() async {
        do {
            let urlString = "\(Configuration.supabaseURL)/functions/v1/"
            print("Testing functions endpoint: \(urlString)")
            
            guard let url = URL(string: urlString) else {
                print("Invalid functions URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("Bearer \(Configuration.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Functions test - Status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("Functions response: \(String(data: data, encoding: .utf8) ?? "No data")")
                } else {
                    print("Functions endpoint accessible!")
                }
            }
        } catch {
            print("Functions test failed: \(error)")
        }
    }
    
    // MARK: - Backend Integration
    
    private func authenticateWithBackend(identityToken: String, user: ASAuthorizationAppleIDCredential) {
        Task {
            do {
                let urlString = "\(Configuration.supabaseURL)/functions/v1/auth-apple-signin"
                print("🔍 === APPLE SIGN-IN DEBUG ===")
                print("Attempting to connect to: \(urlString)")
                
                // Check if there's a cached session that might interfere
                if let cachedSession = try? KeychainManager.shared.loadTokens() {
                    print("⚠️ WARNING: Found cached session that might interfere:")
                    print("   - Cached Access Token: \(String(cachedSession.accessToken.prefix(20)))...")
                    print("   - Cached Refresh Token: \(String(cachedSession.refreshToken.prefix(20)))...")
                } else {
                    print("✅ No cached session found - this is good for Apple Sign-In")
                }
                
                guard let url = URL(string: urlString) else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = "Invalid backend URL"
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                // Log exactly what we're sending
                let authHeader = "Bearer \(Configuration.supabaseAnonKey)"
                print("🔑 Authorization Header being sent:")
                print("   - Full header: \(authHeader)")
                print("   - Token prefix: \(String(Configuration.supabaseAnonKey.prefix(20)))...")
                print("   - Token length: \(Configuration.supabaseAnonKey.count) characters")
                
                // Decode and verify the JWT structure
                let jwtParts = Configuration.supabaseAnonKey.components(separatedBy: ".")
                print("🔐 JWT Structure Analysis:")
                print("   - Parts count: \(jwtParts.count)")
                if jwtParts.count == 3 {
                    print("   - Header: \(jwtParts[0])")
                    print("   - Payload: \(jwtParts[1])")
                    print("   - Signature: \(String(jwtParts[2].prefix(10)))...")
                } else {
                    print("   - ⚠️ Invalid JWT structure (expected 3 parts)")
                }
                
                request.setValue(authHeader, forHTTPHeaderField: "Authorization")
                
                let authRequest = [
                    "identityToken": identityToken,
                    "user": [
                        "id": user.user,
                        "email": user.email,
                        "name": user.fullName?.formatted()
                    ]
                ] as [String: Any]
                
                print("📤 Request Body:")
                print("   - Identity Token: \(String(identityToken.prefix(20)))...")
                print("   - User ID: \(user.user)")
                print("   - Email: \(user.email ?? "nil")")
                print("   - Name: \(user.fullName?.formatted() ?? "nil")")
                
                request.httpBody = try JSONSerialization.data(withJSONObject: authRequest)
                
                print("🌐 Sending request...")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = "Invalid response from server"
                    }
                    return
                }
                
                print("📥 Response received:")
                print("   - Status Code: \(httpResponse.statusCode)")
                print("   - Headers: \(httpResponse.allHeaderFields)")
                
                guard httpResponse.statusCode == 200 else {
                    let responseText = String(data: data, encoding: .utf8) ?? "No response data"
                    print("❌ Backend error response: \(responseText)")
                    print("🔍 === END APPLE SIGN-IN DEBUG ===")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = "Backend authentication failed (Status: \(httpResponse.statusCode)): \(responseText)"
                    }
                    return
                }
                
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                
                print("✅ Authentication successful!")
                print("   - Success: \(authResponse.success)")
                print("   - User: \(authResponse.user?.email ?? "nil")")
                print("   - User ID: \(authResponse.user?.id ?? "nil")")
                print("   - Session access token: \(String(authResponse.session?.accessToken.prefix(20) ?? "nil"))...")
                print("   - Session expires in: \(authResponse.session?.expiresIn ?? 0) seconds")
                print("🔍 === END APPLE SIGN-IN DEBUG ===")
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if authResponse.success, let session = authResponse.session, let user = authResponse.user {
                        // Save tokens securely
                        do {
                            try KeychainManager.shared.saveTokens(session)
                            
                            // Update APIClient with new session
                            APIClient.shared.updateSession(session)
                            
                            self.currentUser = user
                            self.isAuthenticated = true
                            
                            print("✅ Session saved and APIClient updated successfully")
                        } catch {
                            self.error = "Failed to save session: \(error.localizedDescription)"
                        }
                    } else {
                        self.error = authResponse.error ?? "Authentication failed"
                    }
                }
            } catch {
                print("Network error: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "Network error: \(error.localizedDescription)"
                }
            }
        }
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
        print("Apple Sign-In Error: \(error)")
        print("Error Domain: \(error._domain)")
        print("Error Code: \(error._code)")
        
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("ℹ️ Apple Sign-In was canceled - this is normal after clearing credentials")
                self.error = "Sign in was canceled. This is normal after clearing data. Please try again."
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
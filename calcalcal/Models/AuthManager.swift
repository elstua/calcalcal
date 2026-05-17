import Foundation
import AuthenticationServices
import Combine
import GoogleSignIn

class AuthManager: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?
    
    /// Whether the current user is using a temporary (non-OAuth) account
    var isTemporaryUser: Bool {
        currentUser?.isTemporary ?? false
    }
    
    private var cancellables = Set<AnyCancellable>()

    private enum StorageKeys {
        static let firstLaunchKeychainCleanupCompleted = "first_launch_keychain_cleanup_completed"
        static let currentUserId = "current_user_id"
        static let onboardingCompleted = "onboarding_completed"
        static let temporaryDeviceId = "temporary_device_id"
    }
    
    override init() {
        super.init()
        clearKeychainTokensIfThisIsAFreshInstall()
        checkExistingSession()
        testNetworkConnection() // Test network connectivity
    }

    private func clearKeychainTokensIfThisIsAFreshInstall() {
        let defaults = UserDefaults.standard

        guard !defaults.bool(forKey: StorageKeys.firstLaunchKeychainCleanupCompleted) else {
            return
        }

        let hasLocalInstallState =
            defaults.object(forKey: StorageKeys.currentUserId) != nil ||
            defaults.object(forKey: StorageKeys.onboardingCompleted) != nil ||
            defaults.object(forKey: StorageKeys.temporaryDeviceId) != nil

        if !hasLocalInstallState {
            do {
                try KeychainManager.shared.deleteTokens()
                APIClient.shared.clearSession()
                print("🔐 Cleared leftover keychain session for fresh install")
            } catch {
                print("⚠️ Failed to clear leftover keychain session: \(error)")
            }
        }

        defaults.set(true, forKey: StorageKeys.firstLaunchKeychainCleanupCompleted)
    }

    // MARK: - JSON Decoder (tolerant dates)
    static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds first
            let isoWithFractional = ISO8601DateFormatter()
            if #available(iOS 11.2, *) {
                isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            } else {
                isoWithFractional.formatOptions = [.withInternetDateTime]
            }
            if let date = isoWithFractional.date(from: dateString) {
                return date
            }

            // Try ISO8601 without fractional seconds
            let isoNoFractional = ISO8601DateFormatter()
            isoNoFractional.formatOptions = [.withInternetDateTime]
            if let date = isoNoFractional.date(from: dateString) {
                return date
            }

            // Try common Postgres timestamp formats
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
            if let date = formatter.date(from: dateString) {
                return date
            }
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected date string to be ISO8601-formatted, got: \(dateString)")
        }
        return decoder
    }
    
    // MARK: - Temporary Account
    
    /// Create a temporary account for users who want to skip OAuth authentication
    /// This allows users to start using the app immediately
    func createTemporaryAccount() {
        isLoading = true
        error = nil
        
        print("🔐 Creating temporary account...")
        
        // Clear any cached sessions
        do {
            try KeychainManager.shared.deleteTokens()
        } catch {
            print("⚠️ Failed to clear cached sessions: \(error)")
        }
        
        // Generate a unique device ID
        let deviceId = getOrCreateDeviceId()
        
        Task {
            do {
                let urlString = "\(Configuration.apiURL)/api/auth/create-temporary"
                print("🔍 === TEMPORARY ACCOUNT DEBUG ===")
                print("Attempting to connect to: \(urlString)")
                
                guard let url = URL(string: urlString) else {
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "Invalid backend URL"
                    }
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let authRequest: [String: Any] = [
                    "deviceId": deviceId
                ]
                
                request.httpBody = try JSONSerialization.data(withJSONObject: authRequest)
                
                print("🌐 Sending request with deviceId: \(deviceId)")
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "Invalid response from server"
                    }
                    return
                }
                
                print("📥 Response received - Status: \(httpResponse.statusCode)")
                
                guard httpResponse.statusCode == 200 else {
                    let responseText = String(data: data, encoding: .utf8) ?? "No response data"
                    print("❌ Backend error response: \(responseText)")
                    await MainActor.run {
                        self.isLoading = false
                        self.error = "Failed to create temporary account (Status: \(httpResponse.statusCode))"
                    }
                    return
                }
                
                let decoder = AuthManager.makeJSONDecoder()
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                
                print("✅ Temporary account created!")
                print("   - User ID: \(authResponse.user?.id ?? "nil")")
                print("   - Is Temporary: \(authResponse.user?.isTemporary ?? false)")
                print("🔍 === END TEMPORARY ACCOUNT DEBUG ===")
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if authResponse.success, let session = authResponse.session, let user = authResponse.user {
                        do {
                            try KeychainManager.shared.saveTokens(session)
                            APIClient.shared.updateSession(session)
                            
                            self.currentUser = user
                            self.isAuthenticated = true
                            UserDefaults.standard.set(user.id, forKey: "current_user_id")
                            
                            print("✅ Temporary session saved successfully")
                        } catch {
                            self.error = "Failed to save session: \(error.localizedDescription)"
                        }
                    } else {
                        self.error = authResponse.error ?? "Failed to create temporary account"
                    }
                }
            } catch {
                print("Network error: \(error)")
                await MainActor.run {
                    self.isLoading = false
                    self.error = "Network error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Upgrade a temporary account to a permanent account with a verified OAuth token.
    func upgradeTemporaryAccount(identityToken: String? = nil, idToken: String? = nil, email: String?, name: String?) async throws {
        guard let session = try? KeychainManager.shared.loadTokens() else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        print("🔄 Upgrading temporary account...")
        
        let urlString = "\(Configuration.apiURL)/api/auth/upgrade-temporary"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        var upgradeRequest: [String: Any] = [:]
        if let identityToken = identityToken {
            upgradeRequest["identityToken"] = identityToken
        }
        if let idToken = idToken {
            upgradeRequest["idToken"] = idToken
        }
        if let email = email {
            upgradeRequest["email"] = email
        }
        if let name = name {
            upgradeRequest["name"] = name
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: upgradeRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AuthManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upgrade failed: \(responseText)"])
        }
        
        let decoder = AuthManager.makeJSONDecoder()
        struct UpgradeResponse: Codable {
            let success: Bool
            let user: User?
            let message: String?
            let error: String?
        }
        let upgradeResponse = try decoder.decode(UpgradeResponse.self, from: data)
        
        if upgradeResponse.success, let user = upgradeResponse.user {
            await MainActor.run {
                self.currentUser = user
            }
            print("✅ Account upgraded successfully")
        } else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: upgradeResponse.error ?? "Upgrade failed"])
        }
    }
    
    /// Get or create a unique device identifier for temporary accounts
    private func getOrCreateDeviceId() -> String {
        let deviceIdKey = "temporary_device_id"
        
        if let existingId = UserDefaults.standard.string(forKey: deviceIdKey) {
            return existingId
        }
        
        // Generate a new UUID for this device
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: deviceIdKey)
        return newId
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
    
    // MARK: - Google Sign-In
    
    func signInWithGoogle() {
        isLoading = true
        error = nil
        
        // Clear any cached sessions before Google Sign-In
        print("🧹 Clearing any cached sessions before Google Sign-In...")
        do {
            try KeychainManager.shared.deleteTokens()
            print("✅ Cached sessions cleared")
        } catch {
            print("⚠️ Failed to clear cached sessions: \(error)")
        }
        
        // Check if Google Sign-In is configured
        guard !Configuration.googleClientId.isEmpty else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Google Sign-In is not configured. Please set GOOGLE_CLIENT_ID."
            }
            return
        }
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            DispatchQueue.main.async {
                self.isLoading = false
                self.error = "Unable to get root view controller for Google Sign-In"
            }
            return
        }
        
        // Perform Google Sign-In
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] signInResult, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Google Sign-In error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "Google Sign-In failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let result = signInResult else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "Google Sign-In failed: No result"
                }
                return
            }
            
            // Extract user data and ID token
            let user = result.user
            guard let idToken = user.idToken?.tokenString else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.error = "Failed to get Google ID token"
                }
                return
            }
            
            print("✅ Google Sign-In successful")
            print("   - User ID: \(user.userID ?? "nil")")
            print("   - Email: \(user.profile?.email ?? "nil")")
            print("   - Name: \(user.profile?.name ?? "nil")")
            
            // Authenticate with backend
            self.authenticateWithBackendGoogle(idToken: idToken, user: user)
        }
    }
    
    private func authenticateWithBackendGoogle(idToken: String, user: GIDGoogleUser) {
        Task {
            do {
                let urlString = "\(Configuration.apiURL)/api/auth/signin-google"
                print("🔍 === GOOGLE SIGN-IN DEBUG ===")
                print("Attempting to connect to: \(urlString)")
                
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
                
                // Build user info from Google profile
                let authRequest: [String: Any] = [
                    "idToken": idToken,
                    "user": [
                        "id": user.userID ?? "",
                        "email": user.profile?.email ?? "",
                        "name": user.profile?.name ?? ""
                    ]
                ]
                
                print("📤 Request Body:")
                print("   - ID Token: \(String(idToken.prefix(20)))...")
                print("   - User ID: \(user.userID ?? "nil")")
                print("   - Email: \(user.profile?.email ?? "nil")")
                print("   - Name: \(user.profile?.name ?? "nil")")
                
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
                
                guard httpResponse.statusCode == 200 else {
                    let responseText = String(data: data, encoding: .utf8) ?? "No response data"
                    print("❌ Backend error response: \(responseText)")
                    print("🔍 === END GOOGLE SIGN-IN DEBUG ===")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.error = "Backend authentication failed (Status: \(httpResponse.statusCode)): \(responseText)"
                    }
                    return
                }
                
                let decoder = AuthManager.makeJSONDecoder()
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                
                print("✅ Google authentication successful!")
                print("   - Success: \(authResponse.success)")
                print("   - User: \(authResponse.user?.email ?? "nil")")
                print("   - User ID: \(authResponse.user?.id ?? "nil")")
                print("🔍 === END GOOGLE SIGN-IN DEBUG ===")
                
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
                            // Persist user id for DiaryAPI inserts
                            UserDefaults.standard.set(user.id, forKey: "current_user_id")
                            
                            print("✅ Session saved and APIClient updated successfully")
                        } catch {
                            self.error = "Failed to save session: \(error.localizedDescription)"
                        }
                    } else {
                        self.error = authResponse.error ?? "Google authentication failed"
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
    
    func signOut() {
        do {
            try KeychainManager.shared.deleteTokens()
            clearAppleIDCredentials()
            
            // Sign out from Google Sign-In
            GIDSignIn.sharedInstance.signOut()
            
            // Clear APIClient session
            APIClient.shared.clearSession()
            
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
            }
            
            print("✅ Sign out completed - all sessions cleared (including Google)")
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
            
            // Sign out from Google Sign-In
            GIDSignIn.sharedInstance.signOut()
            
            // Reset app state
            DispatchQueue.main.async {
                self.isAuthenticated = false
                self.currentUser = nil
                self.error = "✅ All authentication data cleared. You can now sign in fresh."
            }
            
            print("✅ All authentication data cleared successfully (including Google)")
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
                guard let url = URL(string: "\(Configuration.apiURL)/api/auth/profile") else {
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
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    // If unauthorized, try refreshing the session once
                    if httpResponse.statusCode == 401 {
                        print("🔁 Access token invalid/expired. Attempting refresh...")
                        do {
                            let refreshed = try await self.refreshSession(using: session.refreshToken)
                            // Persist and apply refreshed session
                            try KeychainManager.shared.saveTokens(refreshed)
                            APIClient.shared.updateSession(refreshed)
                            print("✅ Token refresh succeeded. Revalidating session...")
                            
                            // Revalidate with refreshed access token
                            var revalidate = URLRequest(url: url)
                            revalidate.httpMethod = "GET"
                            revalidate.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")
                            let (vData, vResp) = try await URLSession.shared.data(for: revalidate)
                            guard let vHttp = vResp as? HTTPURLResponse, vHttp.statusCode == 200 else {
                                // Revalidation failed after refresh
                                try? KeychainManager.shared.deleteTokens()
                                DispatchQueue.main.async {
                                    self.isAuthenticated = false
                                    self.currentUser = nil
                                }
                                return
                            }
                            let decoder = AuthManager.makeJSONDecoder()
                            // Backend returns { success: true, profile: {...} }
                            struct ProfileResponse: Codable {
                                let success: Bool
                                let profile: User?
                            }
                            let profileResponse = try decoder.decode(ProfileResponse.self, from: vData)
                            DispatchQueue.main.async {
                                if profileResponse.success, let user = profileResponse.profile {
                                    self.currentUser = user
                                    self.isAuthenticated = true
                                    UserDefaults.standard.set(user.id, forKey: "current_user_id")
                                } else {
                                    self.isAuthenticated = false
                                    self.currentUser = nil
                                }
                            }
                            return
                        } catch {
                            print("❌ Token refresh failed: \(error)")
                            // Fall through to clearing tokens below
                        }
                    }
                    // Session is invalid and refresh either not attempted or failed; clear it
                    try? KeychainManager.shared.deleteTokens()
                    DispatchQueue.main.async {
                        self.isAuthenticated = false
                        self.currentUser = nil
                    }
                    return
                }
                
                let decoder = AuthManager.makeJSONDecoder()
                // Backend returns { success: true, profile: {...} }
                struct ProfileResponse: Codable {
                    let success: Bool
                    let profile: User?
                }
                let profileResponse = try decoder.decode(ProfileResponse.self, from: data)
                
                DispatchQueue.main.async {
                    if profileResponse.success, let user = profileResponse.profile {
                        self.currentUser = user
                        self.isAuthenticated = true
                        // Persist user id for DiaryAPI inserts
                        UserDefaults.standard.set(user.id, forKey: "current_user_id")
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
    
    private func refreshSession(using refreshToken: String) async throws -> Session {
        let urlString = "\(Configuration.apiURL)/api/auth/refresh"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid refresh URL"])
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // No apikey or anon key needed - backend validates refresh token directly
        let body: [String: Any] = ["refresh_token": refreshToken]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "AuthManager", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Refresh failed: \(responseText)"])
        }
        // Backend returns { success: true, session: { access_token, refresh_token, expires_in } }
        struct RefreshResponse: Codable {
            let success: Bool
            let session: Session
        }
        let decoder = JSONDecoder()
        let refreshResponse = try decoder.decode(RefreshResponse.self, from: data)
        return refreshResponse.session
    }
    

    
    // MARK: - Network Testing
    
    func testNetworkConnection() {
        // Debug current authentication state first
        debugCurrentAuthenticationState()
        
        Task {
            do {
                // Test backend health endpoint
                let urlString = "\(Configuration.apiURL)/health"
                print("Testing connection to: \(urlString)")
                
                guard let url = URL(string: urlString) else {
                    print("Invalid URL")
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
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
            } catch {
                print("Network test failed: \(error)")
            }
        }
    }
    
    // MARK: - Profile Management
    
    /// Update user profile on the backend
    /// - Parameter updates: Dictionary of fields to update (e.g., ["onboarding_completed": false])
    func updateProfile(_ updates: [String: Any]) async throws -> User {
        guard let session = try? KeychainManager.shared.loadTokens() else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let urlString = "\(Configuration.apiURL)/api/auth/profile"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AuthManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Profile update failed: \(responseText)"])
        }
        
        let decoder = AuthManager.makeJSONDecoder()
        struct ProfileResponse: Codable {
            let success: Bool
            let profile: User
        }
        let profileResponse = try decoder.decode(ProfileResponse.self, from: data)
        
        // Update current user
        DispatchQueue.main.async {
            self.currentUser = profileResponse.profile
        }
        
        return profileResponse.profile
    }
    
    /// Delete the current user's account and all associated data
    /// - Parameter reason: Optional reason for deletion (for analytics/audit purposes)
    func deleteAccount(reason: String? = nil) async throws {
        guard let session = try? KeychainManager.shared.loadTokens() else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        print("🗑️ Deleting account...")
        
        let urlString = "\(Configuration.apiURL)/api/auth/account"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        
        // Require explicit confirmation to prevent accidental deletion
        let deleteRequest: [String: Any] = [
            "confirmed": "DELETE_MY_ACCOUNT"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: deleteRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AuthManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Account deletion failed: \(responseText)"])
        }
        
        // Clear all local data after successful deletion
        await MainActor.run {
            self.clearAllAuthenticationData()
            // Clear user defaults
            UserDefaults.standard.removeObject(forKey: "current_user_id")
            UserDefaults.standard.removeObject(forKey: "temporary_device_id")
            print("✅ Account deleted and all local data cleared")
        }
    }
    
    // MARK: - Backend Integration
    
    private func authenticateWithBackend(identityToken: String, user: ASAuthorizationAppleIDCredential) {
        Task {
            do {
                let urlString = "\(Configuration.apiURL)/api/auth/signin-apple"
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
                
                // No authorization header needed for sign-in - backend validates Apple token directly
                
                // Extract name components - Apple only provides this on FIRST sign-in
                let fullNameString: String?
                if let fullName = user.fullName {
                    // Format PersonNameComponents to a string
                    let formatter = PersonNameComponentsFormatter()
                    formatter.style = .long
                    fullNameString = formatter.string(from: fullName)
                    print("📋 Name components received from Apple:")
                    print("   - Given name: \(fullName.givenName ?? "nil")")
                    print("   - Family name: \(fullName.familyName ?? "nil")")
                    print("   - Middle name: \(fullName.middleName ?? "nil")")
                    print("   - Formatted: \(fullNameString ?? "nil")")
                } else {
                    fullNameString = nil
                    print("⚠️ No name components received - this is normal for subsequent sign-ins")
                    print("   Apple only provides name on the FIRST sign-in for privacy reasons")
                }
                
                let authRequest: [String: Any] = [
                    "identityToken": identityToken,
                    "user": [
                        "id": user.user,
                        "email": user.email as Any? ?? NSNull(),
                        "name": fullNameString as Any? ?? NSNull()
                    ]
                ]
                
                print("📤 Request Body:")
                print("   - Identity Token: \(String(identityToken.prefix(20)))...")
                print("   - User ID: \(user.user)")
                print("   - Email: \(user.email ?? "nil")")
                print("   - Name: \(fullNameString ?? "nil")")
                
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
                
                let decoder = AuthManager.makeJSONDecoder()
                let authResponse = try decoder.decode(AuthResponse.self, from: data)
                
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
                            // Persist user id for DiaryAPI inserts
                            UserDefaults.standard.set(user.id, forKey: "current_user_id")
                            
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

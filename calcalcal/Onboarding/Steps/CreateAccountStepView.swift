import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

/// Final onboarding step for temporary users - prompts them to create a permanent account.
/// Similar to AuthChoiceView but without the "Continue" button and with different messaging.
struct CreateAccountStepView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var coordinator: OnboardingCoordinator
    
    @State private var isUpgrading = false
    @State private var upgradeError: String?
    
    /// Whether this view is being shown from ContentView (not part of onboarding flow)
    private var isStandaloneView: Bool {
        // If coordinator hasn't started, we're in standalone mode
        !coordinator.isCompleted && coordinator.currentStep == .aboutApp
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: 16) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 8)
                
                Text("One last step")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Create an account to sync your data\nacross devices and prevent data loss")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 40)
            
            Spacer()
            
            // OAuth buttons
            VStack(spacing: 16) {
                // Apple Sign-In
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        handleAppleUpgrade(result: result)
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .disabled(isUpgrading)
                
                // Google Sign-In
                GoogleSignInButton(
                    viewModel: GoogleSignInButtonViewModel(
                        scheme: .dark,
                        style: .wide,
                        state: .normal
                    )
                ) {
                    handleGoogleUpgrade()
                }
                .frame(height: 50)
                .disabled(isUpgrading)
            }
            .padding(.horizontal, 24)
            
            // Loading indicator
            if isUpgrading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                    Text("Creating account...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            // Error message
            if let error = upgradeError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
            
            Spacer()
                .frame(height: 40)
        }
        .padding()
        .overlay(alignment: .bottom) {
            // Debug button for development
            #if DEBUG
            debugResetButton
            #endif
        }
    }
    
    // MARK: - Debug Helpers
    
    #if DEBUG
    @ViewBuilder
    private var debugResetButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    debugResetTemporaryUser()
                }) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Temp User")
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
    
    private func debugResetTemporaryUser() {
        print("🔧 DEBUG: Resetting temporary user state including backend...")
        
        Task {
            do {
                // Get current user info before clearing local data
                let currentUserId = UserDefaults.standard.string(forKey: "current_user_id")
                let deviceId = UserDefaults.standard.string(forKey: "temporary_device_id")
                
                // Clear all authentication data
                try KeychainManager.shared.deleteTokens()
                
                // Clear Google Sign-In
                GIDSignIn.sharedInstance.signOut()
                
                // Clear Apple ID credentials
                let appleIDProvider = ASAuthorizationAppleIDProvider()
                appleIDProvider.createRequest()
                
                // Clear user defaults
                UserDefaults.standard.removeObject(forKey: "current_user_id")
                UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                UserDefaults.standard.removeObject(forKey: "temporary_device_id")
                
                // Clean up backend if we have device info
                if let deviceId = deviceId {
                    await debugCleanupTemporaryByDevice(deviceId: deviceId)
                }
                
                await MainActor.run {
                    // Force immediate state reset
                    appState.authManager.isAuthenticated = false
                    appState.authManager.currentUser = nil
                    appState.authManager.isLoading = false
                    appState.authManager.error = nil
                    
                    // Clear APIClient session
                    APIClient.shared.clearSession()
                    
                    print("✅ DEBUG: Temporary user reset complete - showing AuthChoiceView")
                    
                    // Force immediate UI update
                    appState.objectWillChange.send()
                }
            } catch {
                print("❌ DEBUG: Failed to reset temporary user: \(error)")
                await MainActor.run {
                    upgradeError = "Debug reset failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Clean up temporary account by device ID
    private func debugCleanupTemporaryByDevice(deviceId: String) async {
        print("🔧 DEBUG: Cleaning up temporary account for device: \(deviceId)")
        
        do {
            let cleanupUrl = URL(string: "\(Configuration.apiURL)/api/auth/debug/cleanup-temporary-by-device")!
            var cleanupRequest = URLRequest(url: cleanupUrl)
            cleanupRequest.httpMethod = "POST"
            cleanupRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["deviceId": deviceId]
            cleanupRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: cleanupRequest)
            if let httpResponse = response as? HTTPURLResponse {
                print("🔧 DEBUG: Device cleanup response: \(httpResponse.statusCode)")
                if let responseJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔧 DEBUG: Device cleanup response: \(responseJson)")
                }
            }
            
        } catch {
            print("🔧 DEBUG: Device-based cleanup failed: \(error)")
        }
    }
    #endif
    
    // MARK: - Apple Upgrade
    
    private func handleAppleUpgrade(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let _ = String(data: identityToken, encoding: .utf8) else {
                upgradeError = "Failed to get Apple credentials"
                return
            }
            
            isUpgrading = true
            upgradeError = nil
            
            // Extract user info
            let fullNameString: String?
            if let fullName = appleIDCredential.fullName {
                let formatter = PersonNameComponentsFormatter()
                formatter.style = .long
                fullNameString = formatter.string(from: fullName)
            } else {
                fullNameString = nil
            }
            
            Task {
                do {
                    try await appState.authManager.upgradeTemporaryAccount(
                        appleId: appleIDCredential.user,
                        googleId: nil,
                        email: appleIDCredential.email,
                        name: fullNameString
                    )
                    await MainActor.run {
                        isUpgrading = false
                        // Handle completion based on context
                        if isStandaloneView {
                            // Standalone mode - trigger app state update to show MainTabView
                            appState.objectWillChange.send()
                        } else {
                            // Onboarding mode - complete onboarding
                            _ = coordinator.advance(.complete)
                        }
                    }
                } catch {
                    await MainActor.run {
                        isUpgrading = false
                        upgradeError = "Upgrade failed: \(error.localizedDescription)"
                    }
                }
            }
            
        case .failure(let error):
            upgradeError = "Apple Sign-In failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Google Upgrade
    
    private func handleGoogleUpgrade() {
        isUpgrading = true
        upgradeError = nil
        
        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            upgradeError = "Unable to present Google Sign-In"
            isUpgrading = false
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.isUpgrading = false
                    self.upgradeError = "Google Sign-In failed: \(error.localizedDescription)"
                }
                return
            }
            
            guard let result = signInResult else {
                DispatchQueue.main.async {
                    self.isUpgrading = false
                    self.upgradeError = "Google Sign-In failed: No result"
                }
                return
            }
            
            let user = result.user
            
            Task {
                do {
                    try await appState.authManager.upgradeTemporaryAccount(
                        appleId: nil,
                        googleId: user.userID,
                        email: user.profile?.email,
                        name: user.profile?.name
                    )
                    await MainActor.run {
                        self.isUpgrading = false
                        // Handle completion based on context
                        if isStandaloneView {
                            // Standalone mode - trigger app state update to show MainTabView
                            appState.objectWillChange.send()
                        } else {
                            // Onboarding mode - complete onboarding
                            _ = coordinator.advance(.complete)
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.isUpgrading = false
                        self.upgradeError = "Upgrade failed: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

struct CreateAccountStepView_Previews: PreviewProvider {
    static var previews: some View {
        CreateAccountStepView(coordinator: OnboardingCoordinator())
            .environmentObject(AppState())
    }
}

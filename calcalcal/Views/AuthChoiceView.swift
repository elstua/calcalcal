import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

/// Welcome screen that allows users to either:
/// 1. Continue without authentication (temporary account)
/// 2. Sign in with Apple or Google (permanent account)
struct AuthChoiceView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: DSSpacing.md) {
                Text("Calycal")
                    .font(.dsDisplay)
                    .foregroundColor(DSColors.textPrimary)
                
                Text("intelligent calorie tracker\nfor those who love good food")
                    .font(.dsBody)
                    .foregroundColor(DSColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 60)
            
            Spacer()
            
            // Main action buttons
            VStack(spacing: DSSpacing.md) {
                // Primary CTA - Continue without account (temporary)
                Button(action: {
                    appState.authManager.createTemporaryAccount()
                }) {
                    Text("Learn more")
                        .font(.dsHeadline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(DSColors.primary)
                        .foregroundColor(DSColors.textInverted)
                        .cornerRadius(DSCornerRadius.md)
                }
                .disabled(appState.isLoading)
                
                // Sign in link
                
                    Text("Already have an account? Sign in")
                        .font(.dsSubheadline)
                        .foregroundColor(DSColors.textSecondary)
                
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.md)
                
                // OAuth buttons - side by side
                HStack(spacing: DSSpacing.smd) {
                    // Apple Sign-In
                    SignInWithAppleButton(
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            switch result {
                            case .success(let authorization):
                                if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                    appState.authManager.processAppleSignIn(credential: appleIDCredential)
                                }
                            case .failure(let error):
                                appState.authManager.error = error.localizedDescription
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    
                    // Google Sign-In
                    GoogleSignInButton(
                        viewModel: GoogleSignInButtonViewModel(
                            scheme: .dark,
                            style: .icon,
                            state: .normal
                        )
                    ) {
                        appState.authManager.signInWithGoogle()
                    }
                    .frame(width: 50, height: 64)
                }
            }
            .padding(.horizontal, DSSpacing.lg)
            
            
            // Loading indicator
            if appState.isLoading {
                ProgressView()
                    .padding()
            }
            
            // Error message
            if let error = appState.error {
                Text(error)
                    .foregroundColor(DSColors.error)
                    .font(.dsCaption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, DSSpacing.sm)
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
                    debugResetAllData()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Reset All")
                    }
                    .font(.dsCaption)
                    .padding(.horizontal, DSSpacing.sm)
                    .padding(.vertical, DSSpacing.xs)
                    .background(DSColors.error.opacity(0.8))
                    .foregroundColor(DSColors.textInverted)
                    .cornerRadius(6)
                }
                .padding(.trailing, DSSpacing.md)
                .padding(.bottom, DSSpacing.md)
            }
        }
    }
    
    private func debugResetAllData() {
        print("🔧 DEBUG: Resetting all app data including backend...")
        
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
                
                // Clear all user defaults
                UserDefaults.standard.removeObject(forKey: "current_user_id")
                UserDefaults.standard.removeObject(forKey: "onboarding_completed")
                UserDefaults.standard.removeObject(forKey: "temporary_device_id")
                UserDefaults.standard.removeObject(forKey: "onboarding_collected_data")
                UserDefaults.standard.removeObject(forKey: "onboarding_analytics")
                UserDefaults.standard.removeObject(forKey: "onboarding_current_step")
                
                // Clean up backend if we have user info
                if let userId = currentUserId, let deviceId = deviceId {
                    await debugCleanupBackend(userId: userId, deviceId: deviceId)
                }
                
                await MainActor.run {
                    // Force immediate state reset
                    appState.authManager.isAuthenticated = false
                    appState.authManager.currentUser = nil
                    appState.authManager.isLoading = false
                    appState.authManager.error = nil
                    
                    // Clear APIClient session
                    APIClient.shared.clearSession()
                    
                    print("✅ DEBUG: All data reset complete - showing AuthChoiceView")
                    
                    // Force immediate UI update
                    appState.objectWillChange.send()
                }
            } catch {
                print("❌ DEBUG: Failed to reset data: \(error)")
                await MainActor.run {
                    appState.authManager.error = "Debug reset failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Clean up backend data for temporary accounts
    private func debugCleanupBackend(userId: String, deviceId: String) async {
        print("🔧 DEBUG: Cleaning up backend data for user: \(userId), device: \(deviceId)")
        
        do {
            // Try to get session tokens for cleanup (might fail if already cleared)
            guard let session = try? KeychainManager.shared.loadTokens() else {
                print("🔧 DEBUG: No session tokens available, attempting device-based cleanup")
                await debugCleanupByDeviceId(deviceId: deviceId)
                return
            }
            
            // Delete user account (this will cascade delete diary entries, etc.)
            let deleteUrl = URL(string: "\(Configuration.apiURL)/api/debug/delete-user")!
            var deleteRequest = URLRequest(url: deleteUrl)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            
            let (_, deleteResponse) = try await URLSession.shared.data(for: deleteRequest)
            if let httpResponse = deleteResponse as? HTTPURLResponse {
                print("🔧 DEBUG: Delete user response: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("🔧 DEBUG: Backend cleanup failed: \(error)")
        }
    }
    
    /// Fallback cleanup by device ID (if no auth tokens available)
    private func debugCleanupByDeviceId(deviceId: String) async {
        print("🔧 DEBUG: Attempting device-based cleanup for: \(deviceId)")
        
        do {
            let cleanupUrl = URL(string: "\(Configuration.apiURL)/api/debug/cleanup-temporary-by-device")!
            var cleanupRequest = URLRequest(url: cleanupUrl)
            cleanupRequest.httpMethod = "POST"
            cleanupRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body = ["deviceId": deviceId]
            cleanupRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (_, response) = try await URLSession.shared.data(for: cleanupRequest)
            if let httpResponse = response as? HTTPURLResponse {
                print("🔧 DEBUG: Device cleanup response: \(httpResponse.statusCode)")
            }
            
        } catch {
            print("🔧 DEBUG: Device-based cleanup failed: \(error)")
        }
    }
    #endif
}

struct AuthChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        AuthChoiceView()
            .environmentObject(AppState())
    }
}

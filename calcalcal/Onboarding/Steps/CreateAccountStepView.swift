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
                
                // Skip option
                Button(action: {
                    // Skip account creation, complete onboarding
                    _ = coordinator.advance(.complete)
                }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .disabled(isUpgrading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            
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
    }
    
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
                        // Complete onboarding after successful upgrade
                        _ = coordinator.advance(.complete)
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
                        // Complete onboarding after successful upgrade
                        _ = coordinator.advance(.complete)
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

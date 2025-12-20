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
            VStack(spacing: 16) {
                Text("Calycal")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("intelligent calorie tracker\nfor those who love good food")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.bottom, 60)
            
            Spacer()
            
            // Main action buttons
            VStack(spacing: 16) {
                // Primary CTA - Continue without account (temporary)
                Button(action: {
                    appState.authManager.createTemporaryAccount()
                }) {
                    Text("Learn more")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.primary)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                }
                .disabled(appState.isLoading)
                
                // Sign in link
                
                    Text("Already have an account? Sign in")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                
                .padding(.top, 8)
                .padding(.bottom, 16)
                
                // OAuth buttons - side by side
                HStack(spacing: 12) {
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
            .padding(.horizontal, 24)
            
            
            // Loading indicator
            if appState.isLoading {
                ProgressView()
                    .padding()
            }
            
            // Error message
            if let error = appState.error {
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
}

struct AuthChoiceView_Previews: PreviewProvider {
    static var previews: some View {
        AuthChoiceView()
            .environmentObject(AppState())
    }
}

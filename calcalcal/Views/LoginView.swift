import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // App Logo and Title
            VStack(spacing: DSSpacing.mlg) {
                
                Text("Calcalcal")
                    .font(.dsDisplay)
                
                Text("Track your nutrition with AI")
                    .font(.dsSubheadline)
                    .foregroundColor(DSColors.textSecondary)
            }
            
            Spacer()
            
            // Sign-In Buttons
            VStack(spacing: DSSpacing.md) {
                // Sign In with Apple Button
                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                // Process the Apple sign-in credentials directly
                                appState.authManager.processAppleSignIn(credential: appleIDCredential)
                            }
                        case .failure(let error):
                            appState.authManager.error = error.localizedDescription
                        }
                    }
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                
                // Sign In with Google Button
                GoogleSignInButton(
                    viewModel: GoogleSignInButtonViewModel(
                        scheme: .dark,
                        style: .wide,
                        state: .normal
                    )
                ) {
                    appState.authManager.signInWithGoogle()
                }
                .frame(height: 50)
            }
            .padding(.horizontal, DSSpacing.xxl)

            Button("Clear All Auth Data") {
                appState.authManager.clearAllAuthenticationData()
            }
            .font(.dsCaption)
            .foregroundColor(DSColors.textSecondary)
            
            if appState.isLoading {
                ProgressView()
                    .padding()
            }
            
            if let error = appState.error {
                Text(error)
                    .foregroundColor(DSColors.error)
                    .font(.dsCaption)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 

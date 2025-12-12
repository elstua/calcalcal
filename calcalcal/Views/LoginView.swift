import SwiftUI
import AuthenticationServices
import GoogleSignIn
import GoogleSignInSwift

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            // App Logo and Title
            VStack(spacing: 20) {
                
                Text("Calcalcal")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your nutrition with AI")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Sign-In Buttons
            VStack(spacing: 16) {
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
            .padding(.horizontal, 40)

            Button("Clear All Auth Data") {
                appState.authManager.clearAllAuthenticationData()
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
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

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
} 

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                // User is logged in
                if appState.isTemporaryUser {
                    // Temporary users always see account creation screen
                    CreateAccountStepView(coordinator: OnboardingCoordinator())
                        .environmentObject(appState)
                } else if appState.hasCompletedOnboarding {
                    // Permanent users with completed onboarding - show main app
                    MainTabView()
                        .environmentObject(appState)
                } else {
                    // Permanent users who need onboarding
                    OnboardingContainerView()
                        .environmentObject(appState)
                }
            } else {
                // Not logged in, show auth choice (welcome screen)
                AuthChoiceView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            // Check for existing session on app launch
            appState.authManager.checkExistingSession()
        }
        .onChange(of: appState.authManager.isAuthenticated) { isAuthenticated in
            // When authentication state changes to false, clear any lingering session data
            if !isAuthenticated {
                print("[ContentView] User logged out, clearing session data")
                APIClient.shared.clearSession()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



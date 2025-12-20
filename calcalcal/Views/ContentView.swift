import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if appState.isAuthenticated {
                // User is logged in - check if they need onboarding
                if appState.hasCompletedOnboarding {
                    // Onboarding done, show main app
                    MainTabView()
                        .environmentObject(appState)
                } else {
                    // Show onboarding flow
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}



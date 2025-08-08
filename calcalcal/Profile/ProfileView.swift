import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // User Info
                VStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text(appState.currentUser?.name ?? "User")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(appState.currentUser?.email ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Settings Button
                Button("Settings") {
                    showingSettings = true
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // Sign Out Button
                Button("Sign Out") {
                    appState.authManager.signOut()
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationTitle("Profile")
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}

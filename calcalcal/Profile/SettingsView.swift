import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var isResettingOnboarding = false
    @State private var resetMessage: String?
    @State private var showingDeleteAccountConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Text("Settings functionality coming soon...")
                        .foregroundColor(.secondary)
                }
                
                // Delete Account Section (only for permanent accounts)
                if !appState.isTemporaryUser {
                    Section(header: Text("Account Management")) {
                        Button("Delete Account") {
                            showingDeleteAccountConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
                
                #if DEBUG
                Section(header: Text("Debug")) {
                    Button(action: resetOnboarding) {
                        HStack {
                            if isResettingOnboarding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            Text("Reset Onboarding")
                        }
                    }
                    .disabled(isResettingOnboarding)
                    
                    if let message = resetMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDeleteAccountConfirmation) {
                DeleteAccountConfirmationView(
                    onDelete: {
                        Task {
                            await appState.deleteAccount()
                        }
                    }
                )
            }
        }
    }
    
    private func resetOnboarding() {
        isResettingOnboarding = true
        resetMessage = nil
        
        Task {
            await appState.resetOnboarding()
            
            await MainActor.run {
                isResettingOnboarding = false
                resetMessage = "Onboarding reset successfully. Restart the app to see onboarding again."
                
                // Clear message after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    resetMessage = nil
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
} 
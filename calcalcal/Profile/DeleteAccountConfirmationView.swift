import SwiftUI

struct DeleteAccountConfirmationView: View {
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("⚠️ Delete Account?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Text("This will permanently delete:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("• All diary entries")
                    Text("• Food preferences")
                    Text("• Health data")
                    Text("• Account settings")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                Text("This action cannot be undone.")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button("Delete My Account", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    DeleteAccountConfirmationView(onDelete: {
        print("Delete account confirmed")
    })
}
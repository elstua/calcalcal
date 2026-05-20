import SwiftUI

struct DeleteAccountConfirmationView: View {
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DSSpacing.mlg) {
                Text("⚠️ Delete Account?")
                    .font(.dsTitle1)
                    .fontWeight(.bold)
                    .foregroundColor(DSColors.error)
                
                Text("This will permanently delete:")
                    .font(.dsHeadline)
                
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("• All diary entries")
                    Text("• Food preferences")
                    Text("• Health data")
                    Text("• Account settings")
                }
                .font(.dsSubheadline)
                .foregroundColor(DSColors.textSecondary)
                
                Text("This action cannot be undone.")
                    .font(.dsCaption)
                    .foregroundColor(DSColors.error)
                
                Spacer()
                
                VStack(spacing: DSSpacing.smd) {
                    Button("Delete My Account", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DSColors.error)
                    
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
        dlog("Delete account confirmed")
    })
}
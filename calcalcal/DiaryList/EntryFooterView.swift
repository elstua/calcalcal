import SwiftUI
import UIKit

struct EntryFooterView: View {
    let calorieSummary: String
    let onAddImage: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onAddImage) {
                Image(systemName: "plus.circle")
                    .font(.title2)
            }
            .accessibilityLabel("Add Image")
            Spacer()
            Text(calorieSummary)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct EntryFooterView_Previews: PreviewProvider {
    static var previews: some View {
        EntryFooterView(calorieSummary: "320 kcal", onAddImage: {})
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 
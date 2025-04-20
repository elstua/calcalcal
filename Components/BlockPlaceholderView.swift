import SwiftUI

struct BlockPlaceholderView: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray)
            .aspectRatio(1.0, contentMode: .fit) // Ensure it's a square
            // The actual size will be controlled by the NSTextAttachment's bounds
    }
}

#Preview {
    BlockPlaceholderView()
        .frame(width: 100, height: 100) // Example size for preview
} 
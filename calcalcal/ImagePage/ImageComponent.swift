import SwiftUI

struct ImageComponent: View {
    let image: Image?
    let isLarge: Bool
    let onDelete: (() -> Void)?
    
    var body: some View {
        ZStack {
            // Polaroid background (white rectangle with border radius)
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 4)
            
            VStack {
                // Image or placeholder
                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: isLarge ? 300 : 100, height: isLarge ? 300 : 100)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: isLarge ? 300 : 100, height: isLarge ? 300 : 100)
                }
                
                // Optional controls for large mode
                if isLarge, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Text("Delete")
                            .foregroundColor(.red)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
        }
        .frame(width: isLarge ? 332 : 132, height: isLarge ? 332 : 132)
    }
}

struct ImageComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Small preview
            ImageComponent(image: Image("sample_image"), isLarge: false, onDelete: nil)
                .previewDisplayName("Small")
            
            // Large preview
            ImageComponent(image: Image("sample_image"), isLarge: true, onDelete: {})
                .previewDisplayName("Large")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 
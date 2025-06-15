import SwiftUI

struct ImageComponent: View {
    let image: Image?
    let isLarge: Bool
    let onDelete: (() -> Void)?
    let onLongPress: (() -> Void)? // Callback for long press
    
    var body: some View {
        ZStack {
            // Polaroid background (white rectangle with border radius)
            RoundedRectangle(cornerRadius: isLarge ? 16 : 8)
                .fill(Color.white)
                .shadow(radius: 1)
                .frame(width: isLarge ? 350 : 110, height: isLarge ? 420 : 130)
            
            VStack(spacing: 0) {
                // Image or placeholder
                if let image = image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: isLarge ? 320 : 86, height: isLarge ? 320 : 86)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Placeholder (grey square)
                    RoundedRectangle(cornerRadius: isLarge ? 10 : 8)
                        .fill(Color.gray.opacity(1))
                        .frame(width: isLarge ? 320 : 86, height: isLarge ? 320 : 86)
                        .offset(x: 0, y: isLarge ? 0 : -8)
                }
                
                if isLarge {
                    Spacer() // This pushes the button to the bottom
                
                // Optional controls for large mode
                    if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Text("Delete")
                            .foregroundColor(.red)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(16)
            .onLongPressGesture {
                onLongPress?() // Call the long press callback
            }
        }
        .frame(width: isLarge ? 350 : 100, height: isLarge ? 420 : 120)
    }
}

struct ImageComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Small preview
            ImageComponent(image: nil, isLarge: false, onDelete: nil, onLongPress: {})
                .previewDisplayName("Small")
            
            // Large preview
            ImageComponent(image: nil, isLarge: true, onDelete: {}, onLongPress: {})
                .previewDisplayName("Large")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 

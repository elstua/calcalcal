import SwiftUI
import UIKit
import Photos

struct ImageComponent: View {
    let asset: PHAsset?
    let uiImage: UIImage?
    let isLarge: Bool
    let onDelete: (() -> Void)?
    let onLongPress: ((UIImage) -> Void)? // Callback for long press with loaded image
    
    @State private var loadedImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            // Polaroid background (white rectangle with border radius)
            RoundedRectangle(cornerRadius: isLarge ? 16 : 8)
                .fill(Color.white)
                .shadow(radius: 1)
                .frame(width: isLarge ? 350 : 60, height: isLarge ? 420 : 80)
            
            VStack(spacing: 0) {
                // Image or placeholder
                // Use loadedImage if available, otherwise fall back to passed uiImage
                if let displayImage = loadedImage ?? uiImage {
                    Image(uiImage: displayImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: isLarge ? 320 : 40, height: isLarge ? 320 : 40)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Placeholder (grey square) while loading
                    RoundedRectangle(cornerRadius: isLarge ? 10 : 8)
                        .fill(Color.gray.opacity(1))
                        .frame(width: isLarge ? 320 : 40, height: isLarge ? 320 : 40)
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
                // Pass the loaded image to the callback
                if let image = loadedImage ?? uiImage {
                    onLongPress?(image)
                }
            }
        }
        .frame(width: isLarge ? 350 : 100, height: isLarge ? 420 : 120)
        .onAppear {
            loadImageFromAsset()
        }
    }
    
    private func loadImageFromAsset() {
        // Only load if we have an asset and haven't loaded yet
        guard let asset = asset, loadedImage == nil else { return }
        
        let imageManager = PHCachingImageManager()
        let targetSize = CGSize(width: 300, height: 300)
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic // Fast thumbnails first, then high quality
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.loadedImage = image
            }
        }
    }
}

struct ImageComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Small preview
            ImageComponent(asset: nil, uiImage: nil as UIImage?, isLarge: false, onDelete: nil, onLongPress: nil)
                .previewDisplayName("Small")
            
            // Large preview
            ImageComponent(asset: nil, uiImage: nil as UIImage?, isLarge: true, onDelete: {}, onLongPress: nil)
                .previewDisplayName("Large")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 

import SwiftUI

/// Shows captured photo in polaroid frame with Retake/Use Photo buttons
struct PhotoPreviewView: View {
    
    /// The captured photo to display
    let image: UIImage
    
    /// Called when user taps Retake - returns to camera
    var onRetake: () -> Void
    
    /// Called when user taps Use Photo - confirms selection
    var onUsePhoto: () -> Void
    
    // MARK: - Layout Constants
    
    private let frameWidth: CGFloat = 320
    private let frameHeight: CGFloat = 400
    private let imageWidth: CGFloat = 290
    private let imageHeight: CGFloat = 290
    private let cornerRadius: CGFloat = 16
    private let imageCornerRadius: CGFloat = 12
    private let buttonHeight: CGFloat = 44
    private let buttonSpacing: CGFloat = 12
    
    var body: some View {
        ZStack {
            // Polaroid frame background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(width: frameWidth, height: frameHeight)
            
            VStack(spacing: 16) {
                // Captured image
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: imageCornerRadius))
                
                // Action buttons
                HStack(spacing: buttonSpacing) {
                    // Retake button
                    Button(action: onRetake) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Retake")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(10)
                    }
                    
                    // Use Photo button
                    Button(action: onUsePhoto) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Use Photo")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(width: frameWidth, height: frameHeight)
    }
}

// MARK: - Preview

#if DEBUG
struct PhotoPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.3)
                .ignoresSafeArea()
            
            // Create a sample image for preview
            PhotoPreviewView(
                image: createSampleImage(),
                onRetake: { print("Retake tapped") },
                onUsePhoto: { print("Use Photo tapped") }
            )
        }
    }
    
    static func createSampleImage() -> UIImage {
        let size = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        
        // Draw a gradient as placeholder
        let context = UIGraphicsGetCurrentContext()!
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}
#endif

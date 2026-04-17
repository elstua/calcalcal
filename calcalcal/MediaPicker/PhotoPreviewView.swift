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
    private let cornerRadius: CGFloat = DSCornerRadius.lg
    private let imageCornerRadius: CGFloat = DSCornerRadius.md
    private let buttonHeight: CGFloat = DSSpacing.minTouchTarget
    private let buttonSpacing: CGFloat = DSSpacing.smd
    
    var body: some View {
        ZStack {
            // Polaroid frame background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DSColors.surface)
                .shadow(color: DSColors.shadowHeavy, radius: 8, x: 0, y: 4)
                .frame(width: frameWidth, height: frameHeight)
            
            VStack(spacing: DSSpacing.md) {
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
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(Font.dsCustom(weight: .semiBold, size: 14))
                            Text("Retake")
                                .font(Font.dsCustom(weight: .medium, size: 16))
                        }
                        .foregroundColor(DSColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(DSColors.surfaceSecondary)
                        .cornerRadius(DSCornerRadius.sm)
                    }
                    
                    // Use Photo button
                    Button(action: onUsePhoto) {
                        HStack(spacing: DSSpacing.xs) {
                            Image(systemName: "checkmark")
                                .font(Font.dsCustom(weight: .semiBold, size: 14))
                            Text("Use Photo")
                                .font(Font.dsCustom(weight: .medium, size: 16))
                        }
                        .foregroundColor(DSColors.textInverted)
                        .frame(maxWidth: .infinity)
                        .frame(height: buttonHeight)
                        .background(DSColors.primary)
                        .cornerRadius(DSCornerRadius.sm)
                    }
                }
                .padding(.horizontal, DSSpacing.md)
                .padding(.bottom, DSSpacing.sm)
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
            DSColors.disabled
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

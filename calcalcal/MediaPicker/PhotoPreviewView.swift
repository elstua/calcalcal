import SwiftUI

/// Shows captured photo in the polaroid card with Retake / Use Photo buttons.
///
/// The card frame, shadow, and responsive sizing are owned by `PolaroidFrame`.
/// This view only supplies the two state-specific pieces: the captured image
/// and the action row below it.
struct PhotoPreviewView: View {

    /// The captured photo to display
    let image: UIImage

    /// Called when user taps Retake - returns to camera
    var onRetake: () -> Void

    /// Called when user taps Use Photo - confirms selection
    var onUsePhoto: () -> Void

    private let buttonSpacing: CGFloat = DSSpacing.md

    var body: some View {
        PolaroidFrame(
            photo: { _ in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            },
            actions: { frameWidth in
                actionRow(frameWidth: frameWidth)
                    // Match the snap button's vertical padding so the capture
                    // and review states sit at the same height below the photo.
                    .padding(.vertical, DSSpacing.sm)
            }
        )
    }

    // MARK: - Action row

    /// Retake / Use Photo buttons. Height comes from `PolaroidMetrics` so it
    /// matches the snap button's height exactly (≈65pt at current polaroid
    /// sizes), making the two states feel like siblings.
    private func actionRow(frameWidth: CGFloat) -> some View {
        let buttonHeight = PolaroidMetrics.actionButtonHeight(frameWidth: frameWidth)

        return HStack(spacing: buttonSpacing) {
            // Retake button
            Button(action: onRetake) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(Font.dsCustom(weight: .semiBold, size: 14))
                    Text("Retake")
                        .font(Font.dsCustom(weight: .medium, size: 17))
                }
                .foregroundColor(DSColors.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .cornerRadius(DSCornerRadius.sm)
            }

            // Use Photo button
            Button(action: onUsePhoto) {
                HStack(spacing: DSSpacing.xs) {
                    Image(systemName: "checkmark")
                        .font(Font.dsCustom(weight: .semiBold, size: 14))
                    Text("Use")
                        .font(Font.dsCustom(weight: .medium, size: 17))
                }
                .foregroundColor(DSColors.textInverted)
                .frame(maxWidth: .infinity)
                .frame(height: buttonHeight)
                .background(DSColors.primary)
                .cornerRadius(DSCornerRadius.full)
            }
        }
        .padding(.horizontal, DSSpacing.md)
    }
}

// MARK: - Preview

#if DEBUG
struct PhotoPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            DSColors.disabled
                .ignoresSafeArea()

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

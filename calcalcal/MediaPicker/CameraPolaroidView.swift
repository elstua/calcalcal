import SwiftUI
import AVFoundation

/// Polaroid-style camera view with live preview and snap button.
///
/// Visuals (card frame, shadow, photo slot, responsive sizing) live in
/// `PolaroidFrame`. This view only owns the *capture-state* pieces:
/// the live feed, permission / loading fallbacks, the snap button, and
/// the flash toggle.
struct CameraPolaroidView: View {

    @ObservedObject var cameraManager: CameraManager

    /// Called when user taps the snap button
    var onCapture: () -> Void

    /// Called when flash toggle is tapped
    var onFlashToggle: () -> Void

    // MARK: - Snap Button Layout
    //
    // Dimensions come from `PolaroidMetrics` so the snap button and the
    // Retake/Use row in the review state share vertical weight. Only the
    // snap-specific bits (inner pill, pill corner radius) live here.

    /// Inner shape is ~83% of the outer (58/70 from the original design).
    private let snapInnerRatio: CGFloat = 58.0 / 70.0

    private struct SnapLayout {
        let outerWidth: CGFloat
        let outerHeight: CGFloat
        let innerWidth: CGFloat
        let innerHeight: CGFloat
        /// Pill-shaped corners — fully rounded on the short edge.
        var outerCornerRadius: CGFloat { outerHeight / 2 }
    }

    // MARK: - Body

    var body: some View {
        PolaroidFrame(
            photo: { _ in photoContent },
            actions: { frameWidth in snapButton(frameWidth: frameWidth).padding(.vertical, DSSpacing.sm) }
        )
    }

    // MARK: - Photo slot

    /// Everything that sits inside the polaroid's square photo area while
    /// capturing: a stable dark placeholder, the live camera feed (or
    /// permission / loading fallbacks), and the flash toggle overlay.
    private var photoContent: some View {
        ZStack {
            // Stable dark placeholder that matches the preview frame.
            // It's always in the layout so the Polaroid's "photo" area looks
            // intact the moment the picker starts sliding up. The real camera
            // preview fades in on top of it once the animation settles.
            Rectangle()
                .fill(DSColors.surfaceSecondary)

            if cameraManager.permissionStatus == .authorized {
                // Live camera preview. It slides up together with the Polaroid
                // frame; while the capture session is still warming up (no video
                // frames yet), the placeholder behind it shows through because
                // CameraFeedUIView has a transparent background.
                CameraFeedRepresentable(session: cameraManager.session)
            } else if cameraManager.permissionStatus == .denied
                || cameraManager.permissionStatus == .restricted {
                permissionDeniedView
            } else {
                loadingView
            }

            // Flash toggle button (top right of preview)
            if cameraManager.permissionStatus == .authorized && cameraManager.isFlashAvailable {
                VStack {
                    HStack {
                        Spacer()
                        flashToggleButton
                            .padding(DSSpacing.sm)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Snap button

    private func snapButton(frameWidth: CGFloat) -> some View {
        let snap = computeSnapLayout(frameWidth: frameWidth)

        // Icon size: ~45% of the button's height keeps comfortable padding
        // around it regardless of the button's final size.
        let iconSize = snap.outerHeight * 0.45

        return Button(action: onCapture) {
            ZStack {
                // Outer ring (stroke only — shows through to what's behind)
                RoundedRectangle(cornerRadius: snap.outerCornerRadius, style: .continuous)
                    .strokeBorder(DSColors.disabled, lineWidth: 1)
                    .frame(width: snap.outerWidth, height: snap.outerHeight)

                // Inner filled shape
                RoundedRectangle(cornerRadius: snap.outerCornerRadius, style: .continuous)
                    .fill(DSColors.primary)
                    .frame(width: snap.outerWidth, height: snap.outerHeight)
                    .shadow(color: DSColors.shadowMedium, radius: 2, x: 0, y: 1)

                // Custom plus icon (vector PDF asset, tinted dark navy)
                Image("Plus icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(DSColors.textInverted)
            }
        }
        .buttonStyle(SnapButtonStyle())
        .disabled(cameraManager.permissionStatus != .authorized)
        .opacity(cameraManager.permissionStatus == .authorized ? 1.0 : 0.5)
    }

    private func computeSnapLayout(frameWidth: CGFloat) -> SnapLayout {
        let outerWidth = PolaroidMetrics.snapButtonWidth(frameWidth: frameWidth)
        let outerHeight = PolaroidMetrics.actionButtonHeight(frameWidth: frameWidth)
        return SnapLayout(
            outerWidth: outerWidth,
            outerHeight: outerHeight,
            innerWidth: outerWidth * snapInnerRatio,
            innerHeight: outerHeight * snapInnerRatio
        )
    }

    // MARK: - Flash toggle

    private var flashToggleButton: some View {
        Button(action: onFlashToggle) {
            ZStack {
                Circle()
                    .fill(DSColors.overlayMedium)
                    .frame(width: 36, height: 36)

                Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                    .font(Font.dsCustom(weight: .semiBold, size: 16))
                    .foregroundColor(cameraManager.flashMode == .on ? .yellow : DSColors.textInverted)
            }
        }
    }

    // MARK: - Permission / loading fallbacks

    private var permissionDeniedView: some View {
        VStack(spacing: DSSpacing.smd) {
            Image(systemName: "camera.fill")
                .font(Font.dsCustom(weight: .regular, size: 40))
                .foregroundColor(DSColors.disabled)

            Text("Camera Access Required")
                .font(.dsHeadline)
                .foregroundColor(DSColors.textPrimary)

            Text("Enable camera in Settings to take photos")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.dsSubheadline)
                    .fontWeight(.medium)
                    .foregroundColor(DSColors.textInverted)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.sm)
                    .background(DSColors.primary)
                    .cornerRadius(DSCornerRadius.sm)
            }
        }
        .padding(DSSpacing.md)
    }

    private var loadingView: some View {
        VStack(spacing: DSSpacing.smd) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Starting camera...")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Snap Button Style

/// Custom button style for the snap button with scale animation
struct SnapButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyle.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Preview

#if DEBUG
struct CameraPolaroidView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            DSColors.disabled
                .ignoresSafeArea()

            CameraPolaroidView(
                cameraManager: CameraManager(),
                onCapture: { dlog("Capture tapped") },
                onFlashToggle: { dlog("Flash toggled") }
            )
        }
    }
}
#endif

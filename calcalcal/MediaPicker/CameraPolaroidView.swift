import SwiftUI
import AVFoundation

/// Polaroid-style camera view with live preview and snap button
struct CameraPolaroidView: View {
    
    @ObservedObject var cameraManager: CameraManager
    
    /// Called when user taps the snap button
    var onCapture: () -> Void
    
    /// Called when flash toggle is tapped
    var onFlashToggle: () -> Void

    // MARK: - Layout Constraints
    //
    // The polaroid adapts to whatever width/height it's given, but stays within
    // a sensible range so it still *feels* like a polaroid across device sizes.
    //
    // Ratios are preserved from the original designer-picked values:
    //   - Frame:   320 × 400        → 4:5 portrait card
    //   - Preview: 290 × 290 square → border = (320-290)/2 = 15pt on each side
    //   - Snap:    70pt outer, 58pt inner
    
    /// Smallest frame width we'll ever render (keeps controls usable on iPhone SE).
    private let minFrameWidth: CGFloat = 280
    /// Largest frame width (stops the polaroid from ballooning on large devices).
    private let maxFrameWidth: CGFloat = 400
    /// Frame height / frame width. 5/4 = classic polaroid "tall card" shape.
    private let frameHeightRatio: CGFloat = 5.0 / 4.0
    /// Preview width / frame width. Preserves the designer's 15pt side border.
    private let previewRatio: CGFloat = 290.0 / 320.0
    /// Snap button width ~ 31% of frame width.
    private let snapButtonRatio: CGFloat = 60.0 / 320.0
    /// Snap button stays a comfortable tap target regardless of frame size.
    private let minSnapButtonWidth: CGFloat = 130
    private let maxSnapButtonWidth: CGFloat = 160
    /// Snap button height relative to width. < 1 = flatter rectangle.
    /// 2/3 → width is 1.5× the height.
    private let snapHeightToWidthRatio: CGFloat = 2.0 / 4.0
    /// Inner shape is ~83% of the outer (58/70 from the original design).
    private let snapInnerRatio: CGFloat = 58.0 / 70.0
    /// Safe margins so the polaroid never kisses the screen edges.
    private let horizontalMargin: CGFloat = DSSpacing.md
    private let verticalMargin: CGFloat = DSSpacing.md
    
    /// Computed sizes for the current available space.
    private struct Layout {
        let frameWidth: CGFloat
        let frameHeight: CGFloat
        let previewSize: CGFloat
        let snapOuterWidth: CGFloat
        let snapOuterHeight: CGFloat
        let snapInnerWidth: CGFloat
        let snapInnerHeight: CGFloat
        let cornerRadius: CGFloat = DSCornerRadius.lg
        let previewCornerRadius: CGFloat = DSCornerRadius.sm
        /// Pill-shaped corners — fully rounded on the short edge.
        var snapOuterCornerRadius: CGFloat { snapOuterHeight / 2 }
        var snapInnerCornerRadius: CGFloat { snapInnerHeight / 2 }
    }
    
    var body: some View {
        GeometryReader { geo in
            let layout = computeLayout(for: geo.size)
            
            ZStack {
                // Polaroid frame background
                RoundedRectangle(cornerRadius: layout.cornerRadius)
                    .fill(DSColors.surface)
                    .shadow(color: DSColors.shadowHeavy, radius: 20, x: 0, y: 16)
                    .frame(width: layout.frameWidth, height: layout.frameHeight)
                
                VStack(spacing: DSSpacing.md) {
                    // Camera preview area
                    ZStack {
                        // Stable dark placeholder that matches the preview frame.
                        // It's always in the layout so the Polaroid's "photo" area looks
                        // intact the moment the picker starts sliding up. The real camera
                        // preview fades in on top of it once the animation settles.
                        RoundedRectangle(cornerRadius: layout.previewCornerRadius)
                            .fill(DSColors.surfaceSecondary)
                            .frame(width: layout.previewSize, height: layout.previewSize)
                        
                        if cameraManager.permissionStatus == .authorized {
                            // Live camera preview. It slides up together with the Polaroid
                            // frame; while the capture session is still warming up (no video
                            // frames yet), the placeholder behind it shows through because
                            // CameraPreviewUIView has a transparent background.
                            CameraPreviewView(session: cameraManager.session)
                                .frame(width: layout.previewSize, height: layout.previewSize)
                                .clipShape(RoundedRectangle(cornerRadius: layout.previewCornerRadius))
                        } else if cameraManager.permissionStatus == .denied || cameraManager.permissionStatus == .restricted {
                            permissionDeniedView(layout: layout)
                        } else {
                            loadingView(layout: layout)
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
                            .frame(width: layout.previewSize, height: layout.previewSize)
                        }
                    }
                    .frame(width: layout.previewSize, height: layout.previewSize)
                    
                    // Snap button
                    snapButton(layout: layout)
                        .padding(.vertical, DSSpacing.sm)
                }
            }
            .frame(width: layout.frameWidth, height: layout.frameHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity) // center inside GeometryReader
        }
    }
    
    // MARK: - Layout computation
    
    /// Picks the largest polaroid size that (a) fits the offered space minus margins,
    /// (b) preserves the 4:5 frame ratio, and (c) respects min/max caps.
    private func computeLayout(for size: CGSize) -> Layout {
        let widthBudget = max(0, size.width - horizontalMargin * 2)
        let heightBudget = max(0, size.height - verticalMargin * 2)
        
        // Start by fitting the width, then cap at max.
        var frameWidth = min(widthBudget, maxFrameWidth)
        var frameHeight = frameWidth * frameHeightRatio
        
        // If that would overflow vertically, scale down to fit the height instead.
        if frameHeight > heightBudget && heightBudget > 0 {
            frameHeight = heightBudget
            frameWidth = frameHeight / frameHeightRatio
        }
        
        // Enforce a floor. In very tight layouts this may slightly overflow —
        // that's a deliberate trade to keep tap targets usable.
        frameWidth = max(frameWidth, minFrameWidth)
        frameHeight = frameWidth * frameHeightRatio
        
        let previewSize = frameWidth * previewRatio
        let snapOuterWidth = min(max(frameWidth * snapButtonRatio, minSnapButtonWidth), maxSnapButtonWidth)
        let snapOuterHeight = snapOuterWidth * snapHeightToWidthRatio
        let snapInnerWidth = snapOuterWidth * snapInnerRatio
        let snapInnerHeight = snapOuterHeight * snapInnerRatio
        
        return Layout(
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            previewSize: previewSize,
            snapOuterWidth: snapOuterWidth,
            snapOuterHeight: snapOuterHeight,
            snapInnerWidth: snapInnerWidth,
            snapInnerHeight: snapInnerHeight
        )
    }
    
    // MARK: - Subviews
    
    private func snapButton(layout: Layout) -> some View {
        Button(action: {
            onCapture()
        }) {
            ZStack {
                // Outer ring (stroke only — shows through to what's behind)
                RoundedRectangle(cornerRadius: layout.snapOuterCornerRadius, style: .continuous)
                    .strokeBorder(DSColors.disabled, lineWidth: 1)
                    .frame(width: layout.snapOuterWidth, height: layout.snapOuterHeight)
                
                // Inner filled shape
                RoundedRectangle(cornerRadius: layout.snapOuterCornerRadius, style: .continuous)
                    .fill(DSColors.accentOrange)
                    .frame(width: layout.snapOuterWidth, height: layout.snapOuterHeight)
                    .shadow(color: DSColors.shadowMedium, radius: 2, x: 0, y: 1)
            }
        }
        .buttonStyle(SnapButtonStyle())
        .disabled(cameraManager.permissionStatus != .authorized)
        .opacity(cameraManager.permissionStatus == .authorized ? 1.0 : 0.5)
    }
    
    private var flashToggleButton: some View {
        Button(action: {
            onFlashToggle()
        }) {
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
    
    private func permissionDeniedView(layout: Layout) -> some View {
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
        .frame(width: layout.previewSize, height: layout.previewSize)
        .background(
            RoundedRectangle(cornerRadius: layout.previewCornerRadius)
                .fill(DSColors.surfaceSecondary)
        )
    }
    
    private func loadingView(layout: Layout) -> some View {
        VStack(spacing: DSSpacing.smd) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Starting camera...")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(width: layout.previewSize, height: layout.previewSize)
        .background(
            RoundedRectangle(cornerRadius: layout.previewCornerRadius)
                .fill(DSColors.surfaceSecondary)
        )
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
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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
                onCapture: { print("Capture tapped") },
                onFlashToggle: { print("Flash toggled") }
            )
        }
    }
}
#endif

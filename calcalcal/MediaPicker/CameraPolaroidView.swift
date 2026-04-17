import SwiftUI
import AVFoundation

/// Polaroid-style camera view with live preview and snap button
struct CameraPolaroidView: View {
    
    @ObservedObject var cameraManager: CameraManager
    
    /// Called when user taps the snap button
    var onCapture: () -> Void
    
    /// Called when flash toggle is tapped
    var onFlashToggle: () -> Void
    
    // MARK: - Layout Constants
    
    private let frameWidth: CGFloat = 320
    private let frameHeight: CGFloat = 400
    private let previewWidth: CGFloat = 290
    private let previewHeight: CGFloat = 290
    private let cornerRadius: CGFloat = DSCornerRadius.lg
    private let previewCornerRadius: CGFloat = DSCornerRadius.md
    private let snapButtonSize: CGFloat = 70
    private let snapButtonInnerSize: CGFloat = 58
    
    var body: some View {
        ZStack {
            // Polaroid frame background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(DSColors.surface)
                .shadow(color: DSColors.shadowHeavy, radius: 8, x: 0, y: 4)
                .frame(width: frameWidth, height: frameHeight)
            
            VStack(spacing: DSSpacing.md) {
                // Camera preview area
                ZStack {
                    if cameraManager.permissionStatus == .authorized {
                        // Live camera preview
                        CameraPreviewView(session: cameraManager.session)
                            .frame(width: previewWidth, height: previewHeight)
                            .clipShape(RoundedRectangle(cornerRadius: previewCornerRadius))
                    } else if cameraManager.permissionStatus == .denied || cameraManager.permissionStatus == .restricted {
                        // Permission denied state
                        permissionDeniedView
                    } else {
                        // Loading or not determined state
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
                        .frame(width: previewWidth, height: previewHeight)
                    }
                }
                .frame(width: previewWidth, height: previewHeight)
                
                // Snap button
                snapButton
                    .padding(.bottom, DSSpacing.sm)
            }
        }
        .frame(width: frameWidth, height: frameHeight)
    }
    
    // MARK: - Subviews
    
    private var snapButton: some View {
        Button(action: {
            onCapture()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(DSColors.disabled, lineWidth: 4)
                    .frame(width: snapButtonSize, height: snapButtonSize)
                
                // Inner filled circle
                Circle()
                    .fill(DSColors.surface)
                    .frame(width: snapButtonInnerSize, height: snapButtonInnerSize)
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
        .frame(width: previewWidth, height: previewHeight)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius)
                .fill(DSColors.surfaceSecondary)
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: DSSpacing.smd) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Starting camera...")
                .font(.dsCaption)
                .foregroundColor(DSColors.textSecondary)
        }
        .frame(width: previewWidth, height: previewHeight)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius)
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

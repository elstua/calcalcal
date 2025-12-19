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
    private let cornerRadius: CGFloat = 16
    private let previewCornerRadius: CGFloat = 12
    private let snapButtonSize: CGFloat = 70
    private let snapButtonInnerSize: CGFloat = 58
    
    var body: some View {
        ZStack {
            // Polaroid frame background
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                .frame(width: frameWidth, height: frameHeight)
            
            VStack(spacing: 16) {
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
                                    .padding(8)
                            }
                            Spacer()
                        }
                        .frame(width: previewWidth, height: previewHeight)
                    }
                }
                .frame(width: previewWidth, height: previewHeight)
                
                // Snap button
                snapButton
                    .padding(.bottom, 8)
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
                    .strokeBorder(Color.gray.opacity(0.3), lineWidth: 4)
                    .frame(width: snapButtonSize, height: snapButtonSize)
                
                // Inner filled circle
                Circle()
                    .fill(Color.white)
                    .frame(width: snapButtonInnerSize, height: snapButtonInnerSize)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
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
                    .fill(Color.black.opacity(0.5))
                    .frame(width: 36, height: 36)
                
                Image(systemName: cameraManager.flashMode == .on ? "bolt.fill" : "bolt.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(cameraManager.flashMode == .on ? .yellow : .white)
            }
        }
    }
    
    private var permissionDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Enable camera in Settings to take photos")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .frame(width: previewWidth, height: previewHeight)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Starting camera...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: previewWidth, height: previewHeight)
        .background(
            RoundedRectangle(cornerRadius: previewCornerRadius)
                .fill(Color.gray.opacity(0.1))
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
            Color.gray.opacity(0.3)
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

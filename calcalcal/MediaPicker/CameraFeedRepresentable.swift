import SwiftUI
import AVFoundation

/// Low-level UIKit bridge that lets SwiftUI display an `AVCaptureSession`'s
/// live video feed. This is infrastructure — the polaroid UI (frame, snap
/// button, flash toggle, fallbacks) lives in `PolaroidFrame` and
/// `CameraPolaroidView`. Consume this view inside those, not directly.
struct CameraFeedRepresentable: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraFeedUIView {
        let view = CameraFeedUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraFeedUIView, context: Context) {
        // Session updates are handled by CameraManager
    }
}

/// UIView subclass that hosts the `AVCaptureVideoPreviewLayer`.
class CameraFeedUIView: UIView {

    var session: AVCaptureSession? {
        didSet {
            previewLayer.session = session
        }
    }

    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        previewLayer.videoGravity = .resizeAspectFill
        // Keep the view transparent so the placeholder sitting behind this view
        // in the SwiftUI ZStack shows through while the capture session warms up.
        // Once the first video frame arrives, AVCaptureVideoPreviewLayer paints
        // over it as normal.
        backgroundColor = .clear
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Ensure preview layer fills the view
        previewLayer.frame = bounds

        // Handle orientation - lock to portrait for consistency
        if let connection = previewLayer.connection {
            // Use the correct rotation angle API for iOS 17+
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90 // Portrait orientation
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct CameraFeedRepresentable_Previews: PreviewProvider {
    static var previews: some View {
        CameraFeedRepresentable(session: AVCaptureSession())
            .frame(width: 300, height: 400)
            .background(Color.black)
    }
}
#endif

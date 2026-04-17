import SwiftUI
import AVFoundation
import Photos

/// Main container for the unified camera and gallery picker.
///
/// Architecture: Camera fills the screen. A custom draggable panel sits at the bottom
/// with three snap points — peek (transparent strip over camera), medium, and full.
/// Dragging the panel transitions from transparent to solid background.
struct UnifiedMediaPickerView: View {

    var onImageSelected: (UIImage, CGRect?) -> Void
    var onDismiss: () -> Void
    var geometryNamespace: Namespace.ID? = nil

    // MARK: - State

    @StateObject private var cameraManager = CameraManager()
    @State private var pickerState: MediaPickerState = .camera

    /// 0 = collapsed peek, 0.5 = medium, 1.0 = fully expanded
    @State private var galleryExpansion: CGFloat = 0

    /// Swipe-down-to-dismiss offset (camera mode only)
    @State private var dismissDragOffset: CGFloat = 0

    /// Selected image state (for preview)
    @State private var selectedImage: UIImage? = nil

    // MARK: - Constants

    private let dismissThreshold: CGFloat = 120

    /// Height of the collapsed peek row
    static let peekDetentHeight: CGFloat = 110

    /// Snap points for the gallery panel
    private let snapPoints: [CGFloat] = [0, 0.5, 1.0]

    // MARK: - Body

    var body: some View {
        ZStack {
            DSColors.overlayHeavy
                .ignoresSafeArea()

            switch pickerState {
            case .camera, .galleryExpanded:
                cameraView
                    .opacity(Double(1.0 - min(1.0, dismissDragOffset / dismissThreshold) * 0.5))

            case .photoPreview(let image):
                photoPreviewStateView(image: image)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }

            // Custom gallery panel
            if pickerState != .photoPreview(UIImage()) {
                GeometryReader { geo in
                    let screenHeight = geo.size.height + geo.safeAreaInsets.bottom
                    GalleryPanelContent(
                        expansion: $galleryExpansion,
                        peekHeight: Self.peekDetentHeight,
                        screenHeight: screenHeight,
                        snapPoints: snapPoints,
                        onImageSelected: { image, assetId, sourceFrame in selectImage(image, assetId: assetId, sourceFrame: sourceFrame) },
                        onDismiss: onDismiss,
                        onBackToCamera: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                                galleryExpansion = 0
                            }
                        },
                        geometryNamespace: geometryNamespace
                    )
                }
                .ignoresSafeArea(.all, edges: .bottom)
            }

        }
        .onAppear { setupCamera() }
        .onDisappear { cameraManager.stopSession() }
        .onChange(of: galleryExpansion) { newValue in
            if newValue < 0.1 {
                cameraManager.resumeSession()
            } else {
                cameraManager.pauseSession()
            }
        }
    }

    // MARK: - Camera view

    private var cameraView: some View {
        VStack {
            Spacer()

            CameraPolaroidView(
                cameraManager: cameraManager,
                onCapture: capturePhoto,
                onFlashToggle: { cameraManager.toggleFlash() }
            )
            .offset(y: dismissDragOffset)

            Spacer()
                .frame(height: Self.peekDetentHeight + DSSpacing.mlg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(cameraDismissGesture)
    }

    // MARK: - Photo preview

    private func photoPreviewStateView(image: UIImage) -> some View {
        VStack {
            Spacer()
            PhotoPreviewView(
                image: image,
                onRetake: retakePhoto,
                onUsePhoto: { usePhoto(image) }
            )
            Spacer()
        }
    }

    // MARK: - Gestures

    private var cameraDismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if value.translation.height > 0 {
                    dismissDragOffset = value.translation.height
                }
            }
            .onEnded { value in
                if value.translation.height > dismissThreshold
                    || value.predictedEndTranslation.height > dismissThreshold * 1.5 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissDragOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func setupCamera() {
        if cameraManager.permissionStatus == .notDetermined {
            cameraManager.requestPermission { granted in
                if granted { cameraManager.configureAndStart() }
            }
        } else if cameraManager.permissionStatus == .authorized {
            cameraManager.configureAndStart()
        }
    }

    private func capturePhoto() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        cameraManager.capturePhoto { image in
            if let image = image {
                withAnimation(.easeInOut(duration: 0.25)) {
                    pickerState = .photoPreview(image)
                }
            }
        }
    }

    private func retakePhoto() {
        withAnimation(.easeInOut(duration: 0.25)) {
            pickerState = .camera
            galleryExpansion = 0
        }
    }

    private func usePhoto(_ image: UIImage) {
        onImageSelected(image, nil)
    }

    private func selectImage(_ image: UIImage, assetId: String, sourceFrame: CGRect) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onImageSelected(image, sourceFrame)
    }
}

// MARK: - Custom Gallery Panel

private struct GalleryPanelContent: View {
    @Binding var expansion: CGFloat
    let peekHeight: CGFloat
    let screenHeight: CGFloat
    let snapPoints: [CGFloat]
    var onImageSelected: (UIImage, String, CGRect) -> Void
    var onDismiss: () -> Void
    var onBackToCamera: () -> Void
    var geometryNamespace: Namespace.ID?

    private var isExpanded: Bool { expansion > 0.1 }

    /// Smooth header height: 0 when collapsed, full size when expanded past threshold
    private var headerProgress: CGFloat {
        min(1.0, max(0, (expansion - 0.05) / 0.25))
    }

    private var currentHeight: CGFloat {
        let expandableRange = screenHeight - peekHeight
        return max(peekHeight, peekHeight + expandableRange * expansion)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.gray.opacity(0.3 + 0.2 * (1 - headerProgress))
                    .blendMode(isExpanded ? .normal : .screen))
                .frame(width: 36, height: 5)
                .padding(.top, DSSpacing.sm)
                .padding(.bottom, DSSpacing.xs)

            // Header — always in layout, height + opacity driven by expansion
            galleryHeader
                .frame(height: DSSpacing.minTouchTarget * headerProgress, alignment: .top)
                .clipped()
                .opacity(Double(headerProgress))

            // Gallery content — scroll disabled when collapsed so drag opens panel
            PickerGalleryView(
                onImageSelected: { _ in },
                onImageSelectedWithId: { image, assetId, sourceFrame in
                    onImageSelected(image, assetId, sourceFrame)
                },
                geometryNamespace: geometryNamespace
            )
            .scrollDisabled(!isExpanded)
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight, alignment: .top)
        .clipped()
        .background(
            DSColors.surface
                .opacity(Double(min(1.0, expansion * 2)))
        )
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.xl, style: .continuous))
        .frame(maxHeight: .infinity, alignment: .bottom)
        .gesture(panelDragGesture)
    }

    private var galleryHeader: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(Font.dsCustom(weight: .semiBold, size: 16))
                    .foregroundColor(DSColors.textPrimary)
                    .frame(width: DSSpacing.xl, height: DSSpacing.xl)
                    .background(DSColors.surfaceSecondary)
                    .clipShape(Circle())
            }
            Spacer()
            Text("Gallery")
                .font(.dsHeadline)
            Spacer()
            Button(action: onBackToCamera) {
                Image(systemName: "camera.fill")
                    .font(Font.dsCustom(weight: .semiBold, size: 16))
                    .foregroundColor(DSColors.textPrimary)
                    .frame(width: DSSpacing.xl, height: DSSpacing.xl)
                    .background(DSColors.surfaceSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.vertical, DSSpacing.sm)
    }

    /// Tracks the expansion value when a drag started (nil = no drag active)
    @State private var dragStartExpansion: CGFloat? = nil

    private var panelDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartExpansion == nil {
                    dragStartExpansion = expansion
                }
                let start = dragStartExpansion ?? expansion
                let expandableRange = screenHeight - peekHeight
                guard expandableRange > 0 else { return }
                let delta = -value.translation.height / expandableRange
                expansion = max(0, min(1, start + delta))
            }
            .onEnded { value in
                let start = dragStartExpansion ?? expansion
                let expandableRange = screenHeight - peekHeight
                dragStartExpansion = nil
                guard expandableRange > 0 else { return }

                let velocityDelta = -value.predictedEndTranslation.height / expandableRange
                let projected = start + velocityDelta

                let target = nearestSnapPoint(to: projected)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    expansion = target
                }
            }
    }

    private func nearestSnapPoint(to value: CGFloat) -> CGFloat {
        let clamped = max(snapPoints.first ?? 0, min(snapPoints.last ?? 1, value))
        return snapPoints.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? 0
    }
}

// MARK: - Media Picker State

enum MediaPickerState: Equatable {
    case camera
    case galleryExpanded
    case photoPreview(UIImage)

    static func == (lhs: MediaPickerState, rhs: MediaPickerState) -> Bool {
        switch (lhs, rhs) {
        case (.camera, .camera): return true
        case (.galleryExpanded, .galleryExpanded): return true
        case (.photoPreview(let a), .photoPreview(let b)): return a === b
        default: return false
        }
    }
}

#if DEBUG
struct UnifiedMediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedMediaPickerView(
            onImageSelected: { _, _ in },
            onDismiss: { }
        )
    }
}
#endif

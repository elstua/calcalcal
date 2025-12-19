import SwiftUI
import AVFoundation

/// Main container for the unified camera and gallery picker
struct UnifiedMediaPickerView: View {
    
    /// Called when user selects/uses a photo
    var onImageSelected: (UIImage) -> Void
    
    /// Called when user dismisses the picker
    var onDismiss: () -> Void
    
    // MARK: - State
    
    @StateObject private var cameraManager = CameraManager()
    
    @State private var pickerState: MediaPickerState = .camera
    
    /// Gallery expansion: 0 = collapsed (showing ~1 row), 1 = fully expanded
    @State private var galleryExpansion: CGFloat = 0
    @State private var dragStartExpansion: CGFloat = 0
    
    /// Dismiss drag offset for camera mode
    @State private var dismissDragOffset: CGFloat = 0
    
    // MARK: - Layout Constants
    
    private let collapsedGalleryHeight: CGFloat = 140
    private let cameraAreaHeight: CGFloat = 460
    private let handleHeight: CGFloat = 32
    private let dismissThreshold: CGFloat = 120
    
    var body: some View {
        GeometryReader { geometry in
            let maxGalleryHeight = geometry.size.height - geometry.safeAreaInsets.top - handleHeight
            let currentGalleryHeight = collapsedGalleryHeight + (maxGalleryHeight - collapsedGalleryHeight) * galleryExpansion
            
            ZStack {
                // Background
                Color.black
                    .ignoresSafeArea()
                
                // Content based on state
                switch pickerState {
                case .camera, .galleryExpanded:
                    cameraAndGalleryView(
                        geometry: geometry,
                        galleryHeight: currentGalleryHeight,
                        maxGalleryHeight: maxGalleryHeight
                    )
                    
                case .photoPreview(let image):
                    photoPreviewStateView(image: image)
                }
            }
        }
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Camera and Gallery View
    
    private func cameraAndGalleryView(geometry: GeometryProxy, galleryHeight: CGFloat, maxGalleryHeight: CGFloat) -> some View {
        let dismissProgress = min(1.0, dismissDragOffset / dismissThreshold)
        
        return ZStack(alignment: .bottom) {
            // Camera area - fades and scales as gallery expands
            VStack {
                Spacer()
                
                CameraPolaroidView(
                    cameraManager: cameraManager,
                    onCapture: capturePhoto,
                    onFlashToggle: { cameraManager.toggleFlash() }
                )
                .scaleEffect(1 - galleryExpansion * 0.3)
                .opacity(1 - galleryExpansion)
                .offset(y: dismissDragOffset)
                
                Spacer()
                    .frame(height: collapsedGalleryHeight + 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(cameraDismissGesture)
            
            // Gallery sheet
            VStack(spacing: 0) {
                // Handle bar
                galleryHandle
                
                // Header (appears as gallery expands)
                if galleryExpansion > 0.3 {
                    galleryHeader
                        .opacity(Double((galleryExpansion - 0.3) / 0.7))
                }
                
                // Gallery content
                PickerGalleryView(
                    onImageSelected: selectImage
                )
            }
            .frame(height: galleryHeight)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
            )
            .offset(y: dismissDragOffset)
            .gesture(galleryDragGesture(maxHeight: maxGalleryHeight))
        }
        .opacity(1 - dismissProgress * 0.5)
    }
    
    // MARK: - Gallery Handle
    
    private var galleryHandle: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            if galleryExpansion < 0.3 {
                Text("Swipe up for gallery")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .opacity(Double(1 - galleryExpansion / 0.3))
            }
        }
        .frame(height: handleHeight)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
    
    // MARK: - Gallery Header
    
    private var galleryHeader: some View {
        HStack {
            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Gallery")
                .font(.headline)
            
            Spacer()
            
            // Camera button
            Button(action: collapseToCamera) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Photo Preview State View
    
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
    
    /// Gesture for dismissing the picker when swiping down on camera
    private var cameraDismissGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only respond to downward drag when gallery is collapsed
                guard galleryExpansion == 0 else { return }
                if value.translation.height > 0 {
                    dismissDragOffset = value.translation.height
                }
            }
            .onEnded { value in
                guard galleryExpansion == 0 else { return }
                if value.translation.height > dismissThreshold || value.predictedEndTranslation.height > dismissThreshold * 1.5 {
                    onDismiss()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        dismissDragOffset = 0
                    }
                }
            }
    }
    
    private func galleryDragGesture(maxHeight: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let dragAmount = -value.translation.height
                
                // If gallery is collapsed and dragging down, trigger dismiss
                if galleryExpansion == 0 && dragAmount < 0 {
                    dismissDragOffset = -dragAmount
                    return
                }
                
                // Otherwise, handle expansion/collapse
                let expansionDelta = dragAmount / (maxHeight - collapsedGalleryHeight)
                let newExpansion = dragStartExpansion + expansionDelta
                galleryExpansion = min(max(newExpansion, 0), 1)
            }
            .onEnded { value in
                let dragAmount = -value.translation.height
                
                // If we were in dismiss mode
                if galleryExpansion == 0 && dismissDragOffset > 0 {
                    if dismissDragOffset > dismissThreshold || -value.predictedEndTranslation.height < -dismissThreshold * 1.5 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dismissDragOffset = 0
                        }
                    }
                    return
                }
                
                let velocity = -value.predictedEndTranslation.height / (maxHeight - collapsedGalleryHeight)
                let projectedExpansion = galleryExpansion + velocity * 0.3
                
                // Snap to collapsed or expanded
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if projectedExpansion > 0.5 {
                        galleryExpansion = 1
                        pickerState = .galleryExpanded
                    } else {
                        galleryExpansion = 0
                        pickerState = .camera
                    }
                }
                dragStartExpansion = galleryExpansion
            }
            .simultaneously(with: 
                DragGesture()
                    .onChanged { _ in }
                    .onEnded { _ in
                        dragStartExpansion = galleryExpansion
                    }
            )
    }
    
    // MARK: - Actions
    
    private func setupCamera() {
        if cameraManager.permissionStatus == .notDetermined {
            cameraManager.requestPermission { granted in
                if granted {
                    cameraManager.configureAndStart()
                }
            }
        } else if cameraManager.permissionStatus == .authorized {
            cameraManager.configureAndStart()
        }
    }
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            if let image = image {
                withAnimation(.easeInOut(duration: 0.2)) {
                    pickerState = .photoPreview(image)
                }
            }
        }
    }
    
    private func retakePhoto() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pickerState = .camera
            galleryExpansion = 0
        }
    }
    
    private func usePhoto(_ image: UIImage) {
        onImageSelected(image)
    }
    
    private func selectImage(_ image: UIImage) {
        onImageSelected(image)
    }
    
    private func collapseToCamera() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            galleryExpansion = 0
            pickerState = .camera
            dragStartExpansion = 0
        }
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
        case (.photoPreview(_), .photoPreview(_)): return true
        default: return false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct UnifiedMediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        UnifiedMediaPickerView(
            onImageSelected: { _ in print("Image selected") },
            onDismiss: { print("Dismissed") }
        )
    }
}
#endif

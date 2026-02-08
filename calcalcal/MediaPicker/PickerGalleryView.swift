import SwiftUI
import UIKit

/// Picker-specific wrapper around the shared GalleryView
struct PickerGalleryView: View {

    /// Called when user taps an image
    var onImageSelected: (UIImage) -> Void

    /// Called with image + asset identifier + source frame for matched geometry
    var onImageSelectedWithId: ((UIImage, String, CGRect) -> Void)? = nil

    /// Namespace for matched geometry (optional)
    var geometryNamespace: Namespace.ID? = nil

    var body: some View {
        GalleryView(
            config: .picker,
            geometryNamespace: geometryNamespace,
            onImageTap: { image, _ in
                onImageSelected(image)
            },
            onImageTapWithId: { image, assetId, sourceFrame in
                onImageSelectedWithId?(image, assetId, sourceFrame)
            }
        )
    }
}

// MARK: - Preview

#if DEBUG
struct PickerGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        PickerGalleryView(onImageSelected: { _ in })
            .background(Color.black)
    }
}
#endif

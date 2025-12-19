import SwiftUI
import UIKit

/// Picker-specific wrapper around the shared GalleryView
struct PickerGalleryView: View {
    
    /// Called when user taps an image
    var onImageSelected: (UIImage) -> Void
    
    var body: some View {
        GalleryView(onImageTap: { image, _ in
            onImageSelected(image)
        })
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

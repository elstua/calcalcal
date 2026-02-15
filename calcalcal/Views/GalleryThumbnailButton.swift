import SwiftUI
import Photos

/// A "+" button with the 3 most recent gallery photos fanned behind it as small thumbnails.
/// Gracefully degrades to just the button when photos are unavailable.
struct GalleryThumbnailButton: View {
    let action: () -> Void

    @State private var thumbnails: [UIImage] = []

    private let thumbnailSize: CGFloat = 28
    private let buttonSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            ZStack {
                // Thumbnail fan behind the button
                ForEach(Array(thumbnails.prefix(3).reversed().enumerated()), id: \.offset) { index, image in
                    let reversedIndex = thumbnails.prefix(3).count - 1 - index
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: thumbnailSize, height: thumbnailSize)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .rotationEffect(.degrees(Double(reversedIndex - 1) * 8))
                        .offset(x: CGFloat(reversedIndex - 1) * 3, y: -4)
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                }

                // Plus button on top
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white, DSColors.primary)
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .onAppear { loadRecentPhotos() }
    }

    private func loadRecentPhotos() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            fetchThumbnails()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    fetchThumbnails()
                }
            }
        default:
            break // No permission — just show the button
        }
    }

    private func fetchThumbnails() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 3
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        guard assets.count > 0 else { return }

        let manager = PHCachingImageManager.default()
        let targetSize = CGSize(width: thumbnailSize * 2, height: thumbnailSize * 2) // 2x for retina
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false

        var loaded: [Int: UIImage] = [:]
        let count = min(3, assets.count)

        for i in 0..<count {
            let asset = assets.object(at: i)
            manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                guard let image = image else { return }
                DispatchQueue.main.async {
                    loaded[i] = image
                    if loaded.count == count {
                        self.thumbnails = (0..<count).compactMap { loaded[$0] }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct GalleryThumbnailButton_Previews: PreviewProvider {
    static var previews: some View {
        GalleryThumbnailButton(action: {})
            .padding()
            .previewLayout(.sizeThatFits)
    }
}
#endif

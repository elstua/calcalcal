import SwiftUI
import UIKit
import Photos

struct ImageComponent: View {
    let asset: PHAsset?
    let uiImage: UIImage?
    let config: GalleryDisplayConfig
    let onDelete: (() -> Void)?
    let onLongPress: ((UIImage) -> Void)?

    /// Large preview mode (used in sheet preview)
    var isLargePreview: Bool = false

    @State private var loadedImage: UIImage? = nil

    private var displayImage: UIImage? { loadedImage ?? uiImage }

    // Sizes derived from config or large-preview mode
    private var imageSize: CGFloat {
        isLargePreview ? 320 : (config.showFrame ? 40 : config.thumbnailHeight)
    }
    /// The white polaroid card dimensions (smaller than outer frame)
    private var cardWidth: CGFloat { isLargePreview ? 350 : 60 }
    private var cardHeight: CGFloat { isLargePreview ? 420 : 80 }
    /// Outer frame including padding around the card
    private var frameWidth: CGFloat { isLargePreview ? 350 : 100 }
    private var frameHeight: CGFloat { isLargePreview ? 420 : 120 }
    private var cornerRadius: CGFloat {
        isLargePreview ? 16 : config.thumbnailCornerRadius
    }

    var body: some View {
        Group {
            if config.showFrame || isLargePreview {
                framedView
            } else {
                edgeToEdgeView
            }
        }
        .onAppear { loadImageFromAsset() }
    }

    // MARK: - Edge-to-edge thumbnail (picker style)

    private var edgeToEdgeView: some View {
        Group {
            if let img = displayImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: config.thumbnailHeight, maxHeight: config.thumbnailHeight)
                    .clipped()
                    .contentShape(Rectangle())
                    .cornerRadius(cornerRadius)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: config.thumbnailHeight, maxHeight: config.thumbnailHeight)
                    .cornerRadius(cornerRadius)
            }
        }
        .onLongPressGesture {
            if let image = displayImage { onLongPress?(image) }
        }
    }

    // MARK: - Polaroid-framed thumbnail (editor style)

    private var framedView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isLargePreview ? 16 : 8)
                .fill(Color.white)
                .shadow(radius: 1)
                .frame(width: cardWidth, height: cardHeight)

            VStack(spacing: 0) {
                if let img = displayImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageSize, height: imageSize)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    RoundedRectangle(cornerRadius: isLargePreview ? 10 : 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: imageSize, height: imageSize)
                }

                if isLargePreview {
                    Spacer()
                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Text("Delete")
                                .foregroundColor(.red)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
            .padding(isLargePreview ? 16 : 8)
            .onLongPressGesture {
                if let image = displayImage { onLongPress?(image) }
            }
        }
        .frame(width: frameWidth, height: frameHeight)
    }

    // MARK: - Loading

    private func loadImageFromAsset() {
        guard let asset = asset, loadedImage == nil else { return }

        let imageManager = PHCachingImageManager.default() as! PHCachingImageManager
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        imageManager.requestImage(
            for: asset,
            targetSize: config.requestSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                self.loadedImage = image
            }
        }
    }
}

// MARK: - Convenience initializers

extension ImageComponent {
    /// Legacy initializer for backward compatibility
    init(asset: PHAsset?, uiImage: UIImage?, isLarge: Bool, onDelete: (() -> Void)?, onLongPress: ((UIImage) -> Void)?) {
        self.asset = asset
        self.uiImage = uiImage
        self.config = .editor
        self.onDelete = onDelete
        self.onLongPress = onLongPress
        self.isLargePreview = isLarge
    }
}

struct ImageComponent_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ImageComponent(asset: nil, uiImage: nil, config: .editor, onDelete: nil, onLongPress: nil)
                .previewDisplayName("Editor")
            ImageComponent(asset: nil, uiImage: nil, config: .picker, onDelete: nil, onLongPress: nil)
                .frame(width: 120, height: 130)
                .previewDisplayName("Picker")
            ImageComponent(asset: nil, uiImage: nil, config: .editor, onDelete: {}, onLongPress: nil, isLargePreview: true)
                .previewDisplayName("Large")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

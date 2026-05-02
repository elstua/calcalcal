import SwiftUI
import UIKit
import Photos

struct ImageComponent: View {
    static let editorCardSize = CGSize(width: 72, height: 86)

    let asset: PHAsset?
    let uiImage: UIImage?
    let config: GalleryDisplayConfig
    let onDelete: (() -> Void)?
    let onLongPress: ((UIImage) -> Void)?

    /// Large preview mode (used in sheet preview)
    var isLargePreview: Bool = false

    @State private var loadedImage: UIImage? = nil

    private var displayImage: UIImage? { loadedImage ?? uiImage }

    private var cornerRadius: CGFloat {
        isLargePreview ? DSCornerRadius.lg : config.thumbnailCornerRadius
    }
    private var usesPolaroidCard: Bool {
        config.showFrame || config.cardAspectRatio != nil || isLargePreview
    }

    var body: some View {
        Group {
            if usesPolaroidCard {
                polaroidView
            } else {
                edgeToEdgeView
            }
        }
        .onAppear { loadImageFromAsset() }
    }

    // MARK: - Edge-to-edge thumbnail fallback

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
                    .fill(DSColors.surfaceSecondary)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: config.thumbnailHeight, maxHeight: config.thumbnailHeight)
                    .cornerRadius(cornerRadius)
            }
        }
        .onLongPressGesture {
            if let image = displayImage { onLongPress?(image) }
        }
    }

    // MARK: - Polaroid thumbnail

    @ViewBuilder
    private var polaroidView: some View {
        if isLargePreview {
            largePolaroidView
        } else if let cardAspectRatio = config.cardAspectRatio {
            responsivePolaroidView
                .aspectRatio(cardAspectRatio, contentMode: .fit)
        } else {
            editorPolaroidView
        }
    }

    private var editorPolaroidView: some View {
        let cardPadding = DSSpacing.sm
        let imageSize = ImageComponent.editorCardSize.width - cardPadding * 2

        return polaroidCard(
            cardWidth: ImageComponent.editorCardSize.width,
            cardHeight: ImageComponent.editorCardSize.height,
            imageSize: imageSize,
            imageTopPadding: cardPadding,
            cardCornerRadius: DSCornerRadius.sm,
            imageCornerRadius: 2,
            shadowColor: DSColors.shadowMedium,
            shadowRadius: 1,
            shadowX: 0,
            shadowY: 0,
            showsDeleteButton: false
        )
        .frame(
            width: ImageComponent.editorCardSize.width,
            height: ImageComponent.editorCardSize.height,
            alignment: .top
        )
    }

    private var largePolaroidView: some View {
        polaroidCard(
            cardWidth: 350,
            cardHeight: 420,
            imageSize: 320,
            imageTopPadding: DSSpacing.md,
            cardCornerRadius: DSCornerRadius.lg,
            imageCornerRadius: DSCornerRadius.sm,
            shadowColor: DSColors.shadowMedium,
            shadowRadius: 1,
            shadowX: 0,
            shadowY: 0,
            showsDeleteButton: true
        )
        .frame(width: 350, height: 420)
    }

    private var responsivePolaroidView: some View {
        GeometryReader { geo in
            let cardWidth = geo.size.width
            let cardHeight = geo.size.height
            let cardPadding = min(max(cardWidth * 0.1, DSSpacing.xs), DSSpacing.sm)
            let imageSize = max(0, cardWidth - cardPadding * 2)
            let cardCornerRadius = cornerRadius + cardPadding

            polaroidCard(
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                imageSize: imageSize,
                imageTopPadding: cardPadding,
                cardCornerRadius: cardCornerRadius,
                imageCornerRadius: cornerRadius,
                shadowColor: DSColors.shadowMedium,
                shadowRadius: 4,
                shadowX: 0,
                shadowY: 2,
                showsDeleteButton: false
            )
            .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        }
    }

    private func polaroidCard(
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        imageSize: CGFloat,
        imageTopPadding: CGFloat,
        cardCornerRadius: CGFloat,
        imageCornerRadius: CGFloat,
        shadowColor: Color,
        shadowRadius: CGFloat,
        shadowX: CGFloat,
        shadowY: CGFloat,
        showsDeleteButton: Bool
    ) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .fill(DSColors.surface)
                .shadow(color: shadowColor, radius: shadowRadius, x: shadowX, y: shadowY)
                .frame(width: cardWidth, height: cardHeight)

            VStack(spacing: 0) {
                polaroidImageContent(size: imageSize, cornerRadius: imageCornerRadius)
                    .padding(.top, imageTopPadding)

                Spacer(minLength: 0)

                if showsDeleteButton, let onDelete = onDelete {
                    Button(action: onDelete) {
                        Text("Delete")
                            .foregroundColor(DSColors.error)
                    }
                    .padding(.bottom, DSSpacing.md)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .top)
        .onLongPressGesture {
            if let image = displayImage { onLongPress?(image) }
        }
    }

    @ViewBuilder
    private func polaroidImageContent(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if let img = displayImage {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DSColors.disabled)
                .frame(width: size, height: size)
        }
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
        VStack(spacing: DSSpacing.mlg) {
            ImageComponent(asset: nil, uiImage: nil, config: .editor, onDelete: nil, onLongPress: nil)
                .previewDisplayName("Editor")
            ImageComponent(asset: nil, uiImage: nil, config: .picker, onDelete: nil, onLongPress: nil)
                .frame(width: 120, height: 160)
                .previewDisplayName("Picker")
            ImageComponent(asset: nil, uiImage: nil, config: .editor, onDelete: {}, onLongPress: nil, isLargePreview: true)
                .previewDisplayName("Large")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

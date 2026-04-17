import SwiftUI

/// Configuration for gallery grid layout and thumbnail style
struct GalleryDisplayConfig {
    let columns: Int
    let spacing: CGFloat
    let thumbnailHeight: CGFloat
    let thumbnailCornerRadius: CGFloat
    /// Whether to show polaroid-style frame around thumbnails
    let showFrame: Bool
    /// Target size for PHImageManager requests
    let requestSize: CGSize

    /// Compact polaroid cards used inside the text editor
    static let editor = GalleryDisplayConfig(
        columns: 3,
        spacing: DSSpacing.lg,
        thumbnailHeight: 130,
        thumbnailCornerRadius: DSCornerRadius.sm,
        showFrame: true,
        requestSize: CGSize(width: 300, height: 300)
    )

    /// Larger edge-to-edge thumbnails for the media picker gallery
    static let picker = GalleryDisplayConfig(
        columns: 3,
        spacing: DSSpacing.xxs,
        thumbnailHeight: 130, // will be overridden by aspect ratio
        thumbnailCornerRadius: DSCornerRadius.xs,
        showFrame: false,
        requestSize: CGSize(width: 400, height: 400)
    )

    var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns)
    }
}

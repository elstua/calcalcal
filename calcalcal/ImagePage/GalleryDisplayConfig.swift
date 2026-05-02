import SwiftUI

/// Configuration for gallery grid layout and thumbnail style
struct GalleryDisplayConfig {
    let columns: Int
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat
    let contentPadding: CGFloat
    let thumbnailHeight: CGFloat
    let thumbnailCornerRadius: CGFloat
    /// Whether to use the compact fixed frame used inside the editor
    let showFrame: Bool
    /// Optional card ratio for picker-style thumbnails. Width / height.
    let cardAspectRatio: CGFloat?
    /// Target size for PHImageManager requests
    let requestSize: CGSize

    /// Compact polaroid cards used inside the text editor
    static let editor = GalleryDisplayConfig(
        columns: 3,
        columnSpacing: DSSpacing.md,
        rowSpacing: DSSpacing.md,
        contentPadding: DSSpacing.md,
        thumbnailHeight: 130,
        thumbnailCornerRadius: DSCornerRadius.sm,
        showFrame: true,
        cardAspectRatio: nil,
        requestSize: CGSize(width: 300, height: 300)
    )

    /// Slightly taller cards for the media picker gallery
    static let picker = GalleryDisplayConfig(
        columns: 3,
        columnSpacing: DSSpacing.sm,
        rowSpacing: DSSpacing.sm,
        contentPadding: DSSpacing.md,
        thumbnailHeight: 130, // overridden by cardAspectRatio
        thumbnailCornerRadius: DSCornerRadius.xs,
        showFrame: false,
        cardAspectRatio: 0.9,
        requestSize: CGSize(width: 400, height: 400)
    )

    var gridItems: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: columnSpacing), count: columns)
    }
}

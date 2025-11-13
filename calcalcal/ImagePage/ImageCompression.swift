import UIKit

struct ImageCompression {
    /// Downscale the image to fit within maxDimension on the longest side and JPEG-encode it.
    /// - Parameters:
    ///   - image: Source UIImage (any orientation).
    ///   - maxDimension: Maximum size for the longest side (default 720).
    ///   - quality: JPEG compression quality (0.0 - 1.0, default 0.7).
    /// - Returns: Tuple of (jpeg data for upload, resized UIImage for local rendering).
    static func compressForUpload(_ image: UIImage, maxDimension: CGFloat = 720, quality: CGFloat = 0.7) -> (data: Data, resizedImage: UIImage) {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else {
            let fallback = image
            let jpeg = fallback.jpegData(compressionQuality: quality) ?? Data()
            return (jpeg, fallback)
        }
        
        let longest = max(originalSize.width, originalSize.height)
        let scaleFactor = min(1.0, maxDimension / longest)
        let targetSize = CGSize(
            width: max(1, floor(originalSize.width * scaleFactor)),
            height: max(1, floor(originalSize.height * scaleFactor))
        )
        
        // Normalize orientation and render to targetSize
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.scale = 1.0
        rendererFormat.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: rendererFormat)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        let jpegData = resized.jpegData(compressionQuality: quality) ?? Data()
        return (jpegData, resized)
    }
}



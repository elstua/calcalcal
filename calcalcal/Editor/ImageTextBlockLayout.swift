import UIKit

class ImageTextBlockLayout: BlockLayoutProviding {
    func exclusionPaths(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> [UIBezierPath] {
        let totalWidth = view.textContainer.size.width
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        let boundingRect = view.boundingRect(for: paragraphRange)
        let blockHeight = max(100, boundingRect.height)
        let imageFrame = CGRect(
            x: 0,
            y: boundingRect.origin.y,
            width: imageWidth,
            height: blockHeight
        )
        let calorieExclusionRect = CGRect(
            x: imageWidth + (remainingWidth - calorieAreaWidth),
            y: boundingRect.origin.y,
            width: calorieAreaWidth,
            height: blockHeight
        )
        return [UIBezierPath(rect: imageFrame), UIBezierPath(rect: calorieExclusionRect)]
    }
    
    func calorieLabelFrame(for paragraphRange: NSRange, in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata, blockFrame: CGRect) -> CGRect? {
        let totalWidth = view.bounds.width - view.textContainerInset.left - view.textContainerInset.right
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        let calorieLabelX = view.bounds.width - view.textContainerInset.right - calorieAreaWidth - blockFrame.origin.x

        if let lastLineRect = view.lastLineRect(for: paragraphRange) {
            let calorieLabelY = lastLineRect.origin.y - blockFrame.origin.y
            let calorieLabelHeight = lastLineRect.height
            return CGRect(x: calorieLabelX, y: calorieLabelY, width: calorieAreaWidth, height: calorieLabelHeight)
        } else {
            return CGRect(x: calorieLabelX, y: 0, width: calorieAreaWidth, height: 24)
        }
    }
    
    func textAreaWidth(in view: UnifiedTextView, metadata: UnifiedTextContentStorage.BlockMetadata) -> CGFloat {
        let totalWidth = view.textContainer.size.width
        let imageWidth = totalWidth * 0.30
        let remainingWidth = totalWidth - imageWidth
        let calorieAreaWidth = remainingWidth * 0.30
        return remainingWidth - calorieAreaWidth - view.textContainer.lineFragmentPadding * 2
    }
}

extension ImageTextBlockLayout {
    /// Creates an attributed string and metadata for an image block
    static func attributedStringForImageBlock(imageData: Data, imageRef: UUID, font: UIFont?, textColor: UIColor?, defaultBlockSpacing: CGFloat, calorieData: String?) -> (NSAttributedString, UnifiedTextContentStorage.BlockMetadata) {
        if let image = UIImage(data: imageData) {
            let attachment = NSTextAttachment()
            attachment.image = image
            let maxWidth: CGFloat = 200
            let aspectRatio = image.size.width > 0 ? image.size.height / image.size.width : 1
            let imageHeight = maxWidth * aspectRatio
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: imageHeight)
            let attributedImage = NSAttributedString(attachment: attachment)
            let attributedText = NSMutableAttributedString(attributedString: attributedImage)
            attributedText.append(NSAttributedString(string: "\n"))
            let metadata = UnifiedTextContentStorage.BlockMetadata(
                blockType: .imageText,
                blockSpacing: defaultBlockSpacing * 2,
                imageReference: imageRef,
                calorieData: calorieData
            )
            return (attributedText, metadata)
        } else {
            let blockText = "[Image]\n"
            let attributedText = NSMutableAttributedString(string: blockText)
            attributedText.addAttribute(.font, value: font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
            attributedText.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 0
            attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
            let metadata = UnifiedTextContentStorage.BlockMetadata(
                blockType: .imageText,
                blockSpacing: defaultBlockSpacing * 2,
                imageReference: imageRef,
                calorieData: calorieData
            )
            return (attributedText, metadata)
        }
    }

    /// Creates an attributed string and metadata for an imageText block (text only, image handled by layout)
    static func attributedStringForImageTextBlock(text: String, imageRef: UUID, font: UIFont?, textColor: UIColor?, defaultBlockSpacing: CGFloat, calorieData: String?) -> (NSAttributedString, UnifiedTextContentStorage.BlockMetadata) {
        let textString = text + "\n"
        let attributedText = NSMutableAttributedString(string: textString)
        attributedText.addAttribute(.font, value: font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: textString.count))
        attributedText.addAttribute(.foregroundColor, value: textColor ?? UIColor.label, range: NSRange(location: 0, length: textString.count))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = 0
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: textString.count))
        let metadata = UnifiedTextContentStorage.BlockMetadata(
            blockType: .imageText,
            blockSpacing: defaultBlockSpacing * 2,
            imageReference: imageRef,
            calorieData: calorieData
        )
        return (attributedText, metadata)
    }

    /// Helper to create a new imageText block
    static func createImageTextBlock(image: UIImage, text: String = "Enter description...", calorieData: String? = nil) -> Block? {
        guard let imageData = image.pngData() else { return nil }
        return Block(type: .imageText(imageData, UUID(), text), calorieData: calorieData)
    }
} 
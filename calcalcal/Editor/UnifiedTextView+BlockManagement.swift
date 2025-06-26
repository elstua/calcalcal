import UIKit

// MARK: - Block Management Extension

// MARK: - Block Model Integration

extension UnifiedTextView {
    /// The array of blocks representing the editor's content
    var blocks: [Block] {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.blocks) as? [Block] {
                return value
            }
            let initial: [Block] = []
            objc_setAssociatedObject(self, &AssociatedKeys.blocks, initial, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return initial
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.blocks, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Render the blocks array into the text storage and metadata
    func renderBlocks(restoreCaretTo caret: Int? = nil) {
        // Save current caret position if not provided
        let caretToRestore = caret ?? self.selectedRange.location
        // Clear the text storage
        textStorage.setAttributedString(NSAttributedString(string: ""))
        
        // Track the current insertion point
        var currentLocation = 0
        
        for block in blocks {
            switch block.type {
            case .text(let text):
                let blockText = text + "\n"
                let attributedText = NSMutableAttributedString(string: blockText)
                attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                textStorage.append(attributedText)
                // Assign metadata
                let blockRange = NSRange(location: currentLocation, length: blockText.count)
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .text,
                    blockSpacing: defaultBlockSpacing,
                    imageReference: nil,
                    calorieData: block.calorieData
                )
                unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                currentLocation += blockText.count
            case .image(let imageData, let imageRef):
                // Decode UIImage from Data
                if let image = UIImage(data: imageData) {
                    let attachment = NSTextAttachment()
                    attachment.image = image
                    // Set a default size for the image (customize as needed)
                    let maxWidth: CGFloat = 200
                    let aspectRatio = image.size.width > 0 ? image.size.height / image.size.width : 1
                    let imageHeight = maxWidth * aspectRatio
                    attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: imageHeight)
                    let attributedImage = NSAttributedString(attachment: attachment)
                    let attributedText = NSMutableAttributedString(attributedString: attributedImage)
                    // Add a newline after the image
                    attributedText.append(NSAttributedString(string: "\n"))
                    textStorage.append(attributedText)
                    // Assign metadata
                    let blockRange = NSRange(location: currentLocation, length: attributedText.length)
                    let metadata = UnifiedTextContentStorage.BlockMetadata(
                        blockType: .imageText,
                        blockSpacing: defaultBlockSpacing * 2,
                        imageReference: imageRef,
                        calorieData: block.calorieData
                    )
                    unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                    currentLocation += attributedText.length
                } else {
                    // Fallback: show placeholder text if image can't be decoded
                    let blockText = "[Image]\n"
                    let attributedText = NSMutableAttributedString(string: blockText)
                    attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                    attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                    let paragraphStyle = NSMutableParagraphStyle()
                    paragraphStyle.paragraphSpacing = 0
                    attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                    textStorage.append(attributedText)
                    // Assign metadata
                    let blockRange = NSRange(location: currentLocation, length: blockText.count)
                    let metadata = UnifiedTextContentStorage.BlockMetadata(
                        blockType: .imageText,
                        blockSpacing: defaultBlockSpacing * 2,
                        imageReference: imageRef,
                        calorieData: block.calorieData
                    )
                    unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                    currentLocation += blockText.count
                }
            case .imageText(let imageData, let imageRef, let text):
                // Do NOT inject image as NSTextAttachment. Only inject the text (placeholder or actual) for the right side.
                let textString = text + "\n"
                let attributedText = NSMutableAttributedString(string: textString)
                attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: textString.count))
                attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: textString.count))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: textString.count))
                textStorage.append(attributedText)
                // Assign metadata
                let blockRange = NSRange(location: currentLocation, length: attributedText.length)
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .imageText,
                    blockSpacing: defaultBlockSpacing * 2,
                    imageReference: imageRef,
                    calorieData: block.calorieData
                )
                unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                currentLocation += attributedText.length
            case .spacer:
                let blockText = "\n"
                let attributedText = NSMutableAttributedString(string: blockText)
                attributedText.addAttribute(.font, value: self.font ?? UIFont.systemFont(ofSize: 16), range: NSRange(location: 0, length: blockText.count))
                attributedText.addAttribute(.foregroundColor, value: self.textColor ?? UIColor.label, range: NSRange(location: 0, length: blockText.count))
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.paragraphSpacing = 0
                attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: blockText.count))
                textStorage.append(attributedText)
                // Assign metadata
                let blockRange = NSRange(location: currentLocation, length: blockText.count)
                let metadata = UnifiedTextContentStorage.BlockMetadata(
                    blockType: .spacer,
                    blockSpacing: defaultSpacerHeight,
                    imageReference: nil,
                    calorieData: nil
                )
                unifiedContentStorage.setBlockMetadata(metadata, for: blockRange)
                currentLocation += blockText.count
            }
        }
        // After rendering, force layout and display update
        setNeedsLayout()
        setNeedsDisplay()
        // Restore caret position if possible
        let newCaret = min(caretToRestore, textStorage.length)
        self.selectedRange = NSRange(location: newCaret, length: 0)
    }

    /// Add a new text block to the model and re-render
    func addTextBlockModel(_ text: String, calorieData: String? = nil) {
        var currentBlocks = self.blocks
        let block = Block(type: .text(text), calorieData: calorieData)
        currentBlocks.append(block)
        self.blocks = currentBlocks
        renderBlocks()
    }

    /// Add a new image block to the model and re-render
    func addImageBlockModel(_ image: UIImage, text: String = "Enter description...", calorieData: String? = nil) {
        guard let imageData = image.pngData() else { return }
        var currentBlocks = self.blocks
        let block = Block(type: .imageText(imageData, UUID(), text), calorieData: calorieData)
        currentBlocks.append(block)
        self.blocks = currentBlocks
        renderBlocks()
    }

    /// Add a new spacer block to the model and re-render
    func addSpacerBlockModel() {
        var currentBlocks = self.blocks
        let block = Block(type: .spacer, calorieData: nil)
        currentBlocks.append(block)
        self.blocks = currentBlocks
        renderBlocks()
    }
}

private struct AssociatedKeys {
    static var blocks = "UnifiedTextView_blocks"
} 

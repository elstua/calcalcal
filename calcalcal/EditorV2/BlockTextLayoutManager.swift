import UIKit

final class BlockTextLayoutController: NSObject, NSTextLayoutManagerDelegate {
    private let blockDocumentController: BlockDocumentController
    
    init(documentController: BlockDocumentController) {
        self.blockDocumentController = documentController
    }
    
    func attach(to textLayoutManager: NSTextLayoutManager) {
        textLayoutManager.delegate = self
        // We no longer use renderingAttributesValidator for paragraph spacing
        // because that causes caret/selection mismatch. Spacing is now baked
        // into the storage via typingAttributes so layout and selection agree.
        textLayoutManager.renderingAttributesValidator = nil
    }
    
    // MARK: - NSTextLayoutManagerDelegate
    
    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        let fragment: ParagraphBlockLayoutFragment
        
        if let blockRange = textElement.elementRange,
           let block = blockDocumentController.block(for: blockRange) {
            // We found the block metadata - create appropriate fragment type
            if block.kind.isImage {
                fragment = ImageBlockLayoutFragment(textElement: textElement, range: nil)
            } else {
                fragment = ParagraphBlockLayoutFragment(textElement: textElement, range: nil)
            }
            fragment.blockMetadata = block
        } else {
            // Fallback: create fragment with default paragraph style
            fragment = ParagraphBlockLayoutFragment(textElement: textElement, range: nil)
            // Set default metadata so background is still drawn
            fragment.blockMetadata = BlockMetadata(
                kind: .paragraph,
                style: .paragraphDefault,
                range: NSRange(location: 0, length: 0)
            )
        }
        
        return fragment
    }
    
    private func paragraphStyle(for block: BlockMetadata) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.paragraphSpacingBefore = block.style.spacingBefore
        style.paragraphSpacing = block.style.spacingAfter
        style.lineHeightMultiple = 1.14
        return style
    }
}


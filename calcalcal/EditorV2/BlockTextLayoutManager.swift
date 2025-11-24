#if canImport(UIKit)
import UIKit

@available(iOS 16.0, *)
final class BlockTextLayoutController: NSObject, NSTextLayoutManagerDelegate {
    private weak var blockContentStorage: BlockTextContentStorage?
    
    init(contentStorage: BlockTextContentStorage) {
        self.blockContentStorage = contentStorage
    }
    
    func attach(to textLayoutManager: NSTextLayoutManager) {
        textLayoutManager.delegate = self
        blockContentStorage?.addTextLayoutManager(textLayoutManager)
        textLayoutManager.renderingAttributesValidator = { [weak self] manager, fragment in
            guard
                let self,
                let block = self.blockContentStorage?.block(for: fragment.rangeInElement)
            else { return }
            
            let attributedRange = fragment.rangeInElement
            let style = self.paragraphStyle(for: block)
            manager.setRenderingAttributes([.paragraphStyle: style], for: attributedRange)
        }
    }
    
    // MARK: - NSTextLayoutManagerDelegate
    
    func textLayoutManager(_ textLayoutManager: NSTextLayoutManager, textLayoutFragmentFor location: NSTextLocation, in textElement: NSTextElement) -> NSTextLayoutFragment {
        let fragment = ParagraphBlockLayoutFragment(textElement: textElement, range: nil)
        if let blockRange = textElement.elementRange,
           let block = blockContentStorage?.block(for: blockRange) {
            fragment.blockMetadata = block
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
#endif


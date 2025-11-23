import UIKit

@available(iOS 16.0, *)
final class BlockTextContentStorage: NSTextContentStorage, NSTextStorageDelegate {
    private let backingStore = NSTextStorage()
    private var needsAttributeUpdate = false
    
    private(set) var document = BlockDocument()
    
    override init() {
        super.init()
        backingStore.delegate = self
        textStorage = backingStore
        applyInitialText("")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyInitialText(_ text: String) {
        let attributed = NSAttributedString(string: text, attributes: defaultTypingAttributes())
        backingStore.setAttributedString(attributed)
        rebuildBlocks()
    }
    
    func updateTextIfNeeded(_ text: String) {
        guard backingStore.string != text else { return }
        let attributed = NSAttributedString(string: text, attributes: defaultTypingAttributes())
        backingStore.setAttributedString(attributed)
        rebuildBlocks()
    }
    
    func block(containing range: NSRange) -> BlockMetadata? {
        document.blocks.first { NSIntersectionRange($0.range, range).length > 0 }
    }
    
    func block(for textRange: NSTextRange) -> BlockMetadata? {
        guard let nsRange = nsRange(for: textRange) else { return nil }
        return block(containing: nsRange)
    }
    
    func nsRange(for textRange: NSTextRange) -> NSRange? {
        let documentLocation = documentRange.location
        let totalLength = backingStore.length
        
        let startOffset = max(0, offset(from: documentLocation, to: textRange.location))
        let endOffset = max(0, offset(from: documentLocation, to: textRange.endLocation))
        
        let clampedStart = min(startOffset, totalLength)
        let clampedEnd = min(max(endOffset, clampedStart), totalLength)
        let length = clampedEnd - clampedStart
        
        guard clampedStart <= totalLength, length >= 0 else {
            return nil
        }
        
        return NSRange(location: clampedStart, length: length)
    }
    
    private func rebuildBlocks() {
        document.rebuild(from: backingStore)
        for layoutManager in textLayoutManagers {
            if let docRange = layoutManager.textContentManager?.documentRange {
                layoutManager.invalidateRenderingAttributes(for: docRange)
            }
        }
        scheduleAttributeApplication()
    }
    
    private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
    }
    
    // MARK: - NSTextStorageDelegate
    
    func textStorage(_ textStorage: NSTextStorage, didProcessEditing editedMask: NSTextStorage.EditActions, range editedRange: NSRange, changeInLength delta: Int) {
        rebuildBlocks()
    }

    // MARK: - Attribute Management
    
    private func scheduleAttributeApplication() {
        guard !needsAttributeUpdate else { return }
        needsAttributeUpdate = true
        DispatchQueue.main.async { [weak self] in
            self?.applyBlockAttributesIfNeeded()
        }
    }
    
    private func applyBlockAttributesIfNeeded() {
        guard needsAttributeUpdate else { return }
        needsAttributeUpdate = false
        applyBlockAttributes()
    }
    
    private func applyBlockAttributes() {
        let storageLength = backingStore.length
        guard storageLength > 0 else { return }
        
        backingStore.beginEditing()
        let fullRange = NSRange(location: 0, length: storageLength)
        backingStore.removeAttribute(BlockAttributeKeys.blockIdentifier, range: fullRange)
        backingStore.removeAttribute(.paragraphStyle, range: fullRange)
        backingStore.removeAttribute(.foregroundColor, range: fullRange)
        
        for block in document.blocks {
            let clampedRange = clampedRange(for: block.range, upperBound: storageLength)
            guard clampedRange.length > 0 else { continue }
            
            backingStore.addAttribute(BlockAttributeKeys.blockIdentifier, value: block.id.rawValue, range: clampedRange)
            let paragraphStyle = paragraphStyle(for: block)
            backingStore.addAttribute(.paragraphStyle, value: paragraphStyle, range: clampedRange)
            
             if block.kind == .image {
                backingStore.addAttribute(.foregroundColor, value: UIColor.clear, range: clampedRange)
            }
        }
        backingStore.endEditing()
    }
    
    private func clampedRange(for range: NSRange, upperBound: Int) -> NSRange {
        let location = max(0, min(range.location, upperBound))
        let upper = max(location, min(range.location + range.length, upperBound))
        return NSRange(location: location, length: upper - location)
    }
    
    private func paragraphStyle(for block: BlockMetadata) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.paragraphSpacingBefore = block.style.spacingBefore
        style.paragraphSpacing = block.style.spacingAfter
        if block.kind == .image {
            let minHeight = max(block.style.minimumContentHeight + block.style.contentInsets.top + block.style.contentInsets.bottom, 1)
            style.minimumLineHeight = minHeight
            style.maximumLineHeight = minHeight
            style.alignment = .center
        } else {
            style.lineHeightMultiple = 1.14
        }
        return style
    }
}


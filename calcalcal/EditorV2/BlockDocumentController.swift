import UIKit

/// Central controller that keeps a `BlockDocument` in sync with the underlying
/// `NSTextStorage` provided by TextKit 2. This is intentionally *not* a
/// subclass of `NSTextContentStorage` to avoid interfering with TextKit's
/// internal invariants.
final class BlockDocumentController: NSObject, NSTextStorageDelegate {
    private weak var textStorage: NSTextStorage?
    private weak var contentManager: NSTextContentManager?
    
    private(set) var document = BlockDocument()
    
    /// Called after the document is rebuilt so the text view can update overlays.
    var onDocumentChange: (() -> Void)?
    
    init(textStorage: NSTextStorage, contentManager: NSTextContentManager) {
        self.textStorage = textStorage
        self.contentManager = contentManager
        super.init()
        textStorage.delegate = self
        rebuildBlocks()
    }
    
    // MARK: - Public queries
    
    func block(containing range: NSRange) -> BlockMetadata? {
        document.blocks.first { NSIntersectionRange($0.range, range).length > 0 }
    }
    
    func block(for textRange: NSTextRange) -> BlockMetadata? {
        guard let nsRange = nsRange(for: textRange) else { return nil }
        return block(containing: nsRange)
    }
    
    /// Allows callers to force a document rebuild after external text mutations.
    func forceRebuild() {
        rebuildBlocks()
    }
    
    // MARK: - NSTextStorageDelegate
    
    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorage.EditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        rebuildBlocks()
    }
    
    // MARK: - Private
    
    private func rebuildBlocks() {
        guard let storage = textStorage else { return }
        document.rebuild(from: storage)
        onDocumentChange?()
    }
    
    private func nsRange(for textRange: NSTextRange) -> NSRange? {
        guard
            let manager = contentManager,
            let storage = textStorage
        else {
            return nil
        }
        
        let documentRange = manager.documentRange
        let totalLength = storage.length
        
        let startOffset = max(0, manager.offset(from: documentRange.location, to: textRange.location))
        let endOffset = max(0, manager.offset(from: documentRange.location, to: textRange.endLocation))
        
        let clampedStart = min(startOffset, totalLength)
        let clampedEnd = min(max(endOffset, clampedStart), totalLength)
        let length = clampedEnd - clampedStart
        
        guard clampedStart <= totalLength, length >= 0 else {
            return nil
        }
        
        return NSRange(location: clampedStart, length: length)
    }
}



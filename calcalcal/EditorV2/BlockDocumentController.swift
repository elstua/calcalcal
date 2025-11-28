import UIKit

/// Central controller that keeps a `BlockDocument` in sync with the underlying
/// `NSTextStorage` provided by TextKit 2. This is intentionally *not* a
/// subclass of `NSTextContentStorage` to avoid interfering with TextKit's
/// internal invariants.
final class BlockDocumentController: NSObject, NSTextStorageDelegate {
    private weak var textStorage: NSTextStorage?
    private weak var contentManager: NSTextContentManager?
    
    private(set) var document = BlockDocument()
    private var calorieLabels: [BlockID: String] = [:]
    private var nutritionData: [BlockID: NutritionData] = [:]
    
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
    
    /// Returns the block that contains the given range.
    ///
    /// For zero-length ranges (cursor positions), we treat the `location` as a point:
    /// - First we look for a block whose range directly contains the caret index.
    /// - If none is found and the caret is at the end of the document, we snap to
    ///   the last block whose range contains `location - 1`. This ensures that a
    ///   caret positioned *after* the final character still maps to the last block,
    ///   while caret positions at the start of a paragraph correctly resolve to the
    ///   new paragraph (since that index is inside its enclosingRange).
    func block(containing range: NSRange) -> BlockMetadata? {
        // Zero-length range: treat as a caret position instead of an extent.
        if range.length == 0 {
            let location = range.location
            
            // Prefer the block that actually contains this index.
            if let directHit = document.blocks.first(where: { NSLocationInRange(location, $0.range) }) {
                return directHit
            }
            
            // If caret is at the very end (past the last character), fall back to
            // the block that contains location - 1 so we still resolve to the
            // last block in the document.
            if location > 0,
               let trailingHit = document.blocks.first(where: { NSLocationInRange(location - 1, $0.range) }) {
                return trailingHit
            }
            
            return nil
        }
        
        // Non-empty range: standard intersection test.
        return document.blocks.first { NSIntersectionRange($0.range, range).length > 0 }
    }
    
    func block(for textRange: NSTextRange) -> BlockMetadata? {
        guard let nsRange = nsRange(for: textRange) else { return nil }
        return block(containing: nsRange)
    }
    
    func setCalorieLabel(_ label: String?, for blockID: BlockID) {
        if let label, !label.isEmpty {
            calorieLabels[blockID] = label
        } else {
            calorieLabels.removeValue(forKey: blockID)
        }
        applyMetadataAndNotify()
    }
    
    func setCalorieLabels(_ labels: [BlockID: String]) {
        calorieLabels = labels
        applyMetadataAndNotify()
    }
    
    func setNutritionData(_ nutrition: [BlockID: NutritionData]) {
        nutritionData = nutrition
        applyMetadataAndNotify()
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
        document.applyMetadata(calorieLabels: calorieLabels, nutrition: nutritionData)
        onDocumentChange?()
    }
    
    private func applyMetadataAndNotify() {
        document.applyMetadata(calorieLabels: calorieLabels, nutrition: nutritionData)
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



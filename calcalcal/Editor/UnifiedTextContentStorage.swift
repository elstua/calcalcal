import UIKit

/// Custom text content storage that maintains block metadata
class UnifiedTextContentStorage: NSObject {
    
    // MARK: - Block Metadata
    
    struct BlockMetadata {
        enum BlockType {
            case text
            case imageText
        }
        
        let blockType: BlockType
        var blockSpacing: CGFloat
        var imageReference: UUID?
        var calorieData: String?
    }
    
    /// Maps paragraph ranges to their metadata
    private var blockMetadata: [NSRange: BlockMetadata] = [:]
    
    /// Reference to the text storage
    weak var textStorage: NSTextStorage?
    
    // MARK: - Custom Attributes
    
    static let blockTypeAttributeName = NSAttributedString.Key("UnifiedEditor.blockType")
    static let blockSpacingAttributeName = NSAttributedString.Key("UnifiedEditor.blockSpacing")
    static let imageReferenceAttributeName = NSAttributedString.Key("UnifiedEditor.imageReference")
    static let calorieDataAttributeName = NSAttributedString.Key("UnifiedEditor.calorieData")
    
    // MARK: - Block Management
    
    func setBlockMetadata(_ metadata: BlockMetadata, for range: NSRange) {
        blockMetadata[range] = metadata
        
        // Apply attributes to the text storage
        textStorage?.addAttributes([
            Self.blockTypeAttributeName: metadata.blockType,
            Self.blockSpacingAttributeName: metadata.blockSpacing,
            Self.imageReferenceAttributeName: metadata.imageReference as Any,
            Self.calorieDataAttributeName: metadata.calorieData as Any
        ], range: range)
    }
    
    func blockMetadata(at location: Int) -> BlockMetadata? {
        for (range, metadata) in blockMetadata {
            if NSLocationInRange(location, range) {
                return metadata
            }
        }
        return nil
    }
    
    func blockMetadata(for range: NSRange) -> BlockMetadata? {
        return blockMetadata[range]
    }
    
    // MARK: - Paragraph Management
    
    func enumerateParagraphs(in range: NSRange? = nil, using block: (NSRange, BlockMetadata?) -> Void) {
        guard let textStorage = textStorage else { return }
        
        let searchRange = range ?? NSRange(location: 0, length: textStorage.length)
        var paragraphStart = searchRange.location
        
        while paragraphStart < NSMaxRange(searchRange) {
            var paragraphEnd = 0
            var contentsEnd = 0
            
            // Convert to String range for paragraph detection
            let string = textStorage.string as NSString
            string.getParagraphStart(nil, 
                                   end: &paragraphEnd, 
                                   contentsEnd: &contentsEnd, 
                                   for: NSRange(location: paragraphStart, length: 0))
            
            let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)
            
            // Find metadata for this paragraph range
            var foundMetadata: BlockMetadata?
            for (storedRange, metadata) in blockMetadata {
                // Check if the stored range matches or overlaps with the paragraph range
                if storedRange.location == paragraphRange.location ||
                   NSLocationInRange(paragraphRange.location, storedRange) ||
                   NSLocationInRange(storedRange.location, paragraphRange) {
                    foundMetadata = metadata
                    break
                }
            }
            
            block(paragraphRange, foundMetadata)
            
            paragraphStart = paragraphEnd
        }
    }
    
    // MARK: - Update Handling
    
    func updateBlockRanges(afterEditingIn editedRange: NSRange, changeInLength delta: Int) {
        var updatedMetadata: [NSRange: BlockMetadata] = [:]
        
        for (range, metadata) in blockMetadata {
            if range.location >= NSMaxRange(editedRange) {
                // Ranges after the edit need to be shifted
                let newRange = NSRange(location: range.location + delta, length: range.length)
                updatedMetadata[newRange] = metadata
            } else if NSMaxRange(range) <= editedRange.location {
                // Ranges before the edit remain unchanged
                updatedMetadata[range] = metadata
            } else {
                // Ranges that intersect with the edit need recalculation
                // This will be handled by re-parsing paragraphs
            }
        }
        
        blockMetadata = updatedMetadata
    }
} 
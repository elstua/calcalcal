import UIKit

/// Custom text content storage that maintains block metadata
class UnifiedTextContentStorage: NSObject {
    
    // MARK: - Block Metadata
    
    struct BlockMetadata {
        enum BlockType: Int {
            case text = 0
            case imageText = 1
            case spacer = 2
        }
        
        let blockType: BlockType
        var blockSpacing: CGFloat
        var imageReference: UUID?
        var calorieData: String?
        var nutritionJSON: Data?
    }
    
    /// Reference to the text storage
    weak var textStorage: NSTextStorage?
    
    // MARK: - Custom Attributes
    
    static let blockTypeAttributeName = NSAttributedString.Key("UnifiedEditor.blockType")
    static let blockSpacingAttributeName = NSAttributedString.Key("UnifiedEditor.blockSpacing")
    static let imageReferenceAttributeName = NSAttributedString.Key("UnifiedEditor.imageReference")
    static let calorieDataAttributeName = NSAttributedString.Key("UnifiedEditor.calorieData")
    static let nutritionJSONAttributeName = NSAttributedString.Key("UnifiedEditor.nutritionJSON")
    
    // MARK: - Block Management
    
    func setBlockMetadata(_ metadata: BlockMetadata, for range: NSRange) {
        guard let textStorage = textStorage else { return }
        
        // Get existing attributes at the start of the range to preserve them
        var existingAttributes: [NSAttributedString.Key: Any] = [:]
        if range.location < textStorage.length {
            existingAttributes = textStorage.attributes(at: range.location, effectiveRange: nil)
        }
        
        // Add our block metadata to existing attributes
        existingAttributes[Self.blockTypeAttributeName] = metadata.blockType.rawValue
        existingAttributes[Self.blockSpacingAttributeName] = metadata.blockSpacing
        existingAttributes[Self.imageReferenceAttributeName] = metadata.imageReference as Any
        existingAttributes[Self.calorieDataAttributeName] = metadata.calorieData as Any
        existingAttributes[Self.nutritionJSONAttributeName] = metadata.nutritionJSON as Any
        
        // Apply all attributes together to preserve formatting
        textStorage.addAttributes(existingAttributes, range: range)
    }
    
    func blockMetadata(at location: Int) -> BlockMetadata? {
        guard let textStorage = textStorage,
              location < textStorage.length else { return nil }
        
        let attributes = textStorage.attributes(at: location, effectiveRange: nil)
        return metadata(from: attributes)
    }
    
    func blockMetadata(for range: NSRange) -> BlockMetadata? {
        guard let textStorage = textStorage,
              range.location < textStorage.length else { return nil }
        
        let attributes = textStorage.attributes(at: range.location, effectiveRange: nil)
        return metadata(from: attributes)
    }
    
    private func metadata(from attributes: [NSAttributedString.Key: Any]) -> BlockMetadata? {
        guard let blockTypeRaw = attributes[Self.blockTypeAttributeName] as? Int,
              let blockType = BlockMetadata.BlockType(rawValue: blockTypeRaw) else {
            return nil
        }
        
        let blockSpacing = attributes[Self.blockSpacingAttributeName] as? CGFloat ?? 16.0
        let imageReference = attributes[Self.imageReferenceAttributeName] as? UUID
        let calorieData = attributes[Self.calorieDataAttributeName] as? String
        let nutritionJSON = attributes[Self.nutritionJSONAttributeName] as? Data
        
        return BlockMetadata(
            blockType: blockType,
            blockSpacing: blockSpacing,
            imageReference: imageReference,
            calorieData: calorieData,
            nutritionJSON: nutritionJSON
        )
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
            
            // Get metadata from attributes at the paragraph start
            let metadata = blockMetadata(at: paragraphStart)
            
            block(paragraphRange, metadata)
            
            paragraphStart = paragraphEnd
        }
    }
    
    // MARK: - Clear Metadata
    
    func clearMetadata(in range: NSRange) {
        textStorage?.removeAttribute(Self.blockTypeAttributeName, range: range)
        textStorage?.removeAttribute(Self.blockSpacingAttributeName, range: range)
        textStorage?.removeAttribute(Self.imageReferenceAttributeName, range: range)
        textStorage?.removeAttribute(Self.calorieDataAttributeName, range: range)
        textStorage?.removeAttribute(Self.nutritionJSONAttributeName, range: range)
    }
} 
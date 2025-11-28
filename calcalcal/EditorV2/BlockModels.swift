import Foundation
import UIKit

public struct BlockID: Hashable, Codable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

public enum BlockKind: Equatable, Codable {
    case paragraph
    case image
    
    var isImage: Bool {
        self == .image
    }
    
    var defaultStyle: BlockStyle {
        switch self {
        case .paragraph:
            return .paragraphDefault
        case .image:
            return .imageDefault
        }
    }
}

public struct BlockStyle: Equatable {
    public var contentInsets: NSDirectionalEdgeInsets
    public var cornerRadius: CGFloat
    public var backgroundColor: UIColor
    public var spacingBefore: CGFloat
    public var spacingAfter: CGFloat
    
    public init(contentInsets: NSDirectionalEdgeInsets,
                cornerRadius: CGFloat,
                backgroundColor: UIColor,
                spacingBefore: CGFloat,
                spacingAfter: CGFloat) {
        self.contentInsets = contentInsets
        self.cornerRadius = cornerRadius
        self.backgroundColor = backgroundColor
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
    }
}

struct BlockMetadata: Equatable {
    var id: BlockID
    var kind: BlockKind
    var style: BlockStyle
    var calorieLabel: String?
    var nutrition: NutritionData?
    var range: NSRange
    /// For image blocks, the actual image to display as an overlay.
    var image: UIImage?
    
    init(id: BlockID = BlockID(),
         kind: BlockKind,
         style: BlockStyle? = nil,
         calorieLabel: String? = nil,
         nutrition: NutritionData? = nil,
         range: NSRange,
         image: UIImage? = nil) {
        self.id = id
        self.kind = kind
        self.style = style ?? kind.defaultStyle
        self.calorieLabel = calorieLabel
        self.nutrition = nutrition
        self.range = range
        self.image = image
    }
}

struct BlockDocument: Equatable {
    private(set) var blocks: [BlockMetadata]
    
    init(blocks: [BlockMetadata] = []) {
        self.blocks = blocks
    }
    
    mutating func rebuild(from textStorage: NSTextStorage) {
        blocks = BlockDocument.makeBlocks(from: textStorage)
    }
    
    private static func makeBlocks(from textStorage: NSTextStorage) -> [BlockMetadata] {
        let string = textStorage.string as NSString
        var result: [BlockMetadata] = []
        var paragraphIndex = 0
        
        string.enumerateSubstrings(in: NSRange(location: 0, length: string.length), options: [.byParagraphs, .substringNotRequired]) { _, substringRange, enclosingRange, _ in
            // Detect whether this paragraph string contains the special
            // marker character (U+FFFC) used for image blocks.
            let paragraphString = string.substring(with: substringRange)
            let markerChar = Character(UnicodeScalar(NSTextAttachment.character)!)
            let isImageBlock = paragraphString.contains(markerChar)
            let kind: BlockKind = isImageBlock ? .image : .paragraph
            
            // Use the default style for this block kind (includes correct spacing)
            let baseStyle = kind.defaultStyle
            let style = BlockStyle(
                contentInsets: baseStyle.contentInsets,
                cornerRadius: baseStyle.cornerRadius,
                backgroundColor: baseStyle.backgroundColor,
                spacingBefore: paragraphIndex == 0 ? 0 : baseStyle.spacingBefore,
                spacingAfter: baseStyle.spacingAfter  // Use default: 10 for paragraph, 88 for image
            )
            
            let blockID = blockID(for: enclosingRange,
                                  isImageBlock: isImageBlock,
                                  textStorage: textStorage)
            
            let block = BlockMetadata(id: blockID, kind: kind, style: style, range: enclosingRange)
            result.append(block)
            paragraphIndex += 1
        }
        
        if result.isEmpty {
            let block = BlockMetadata(kind: .paragraph, style: .paragraphDefault, range: NSRange(location: 0, length: textStorage.length))
            result.append(block)
        }
        
        return result
    }
    
    mutating func applyMetadata(calorieLabels: [BlockID: String], nutrition: [BlockID: NutritionData]) {
        guard !blocks.isEmpty else { return }
        blocks = blocks.map { block in
            var updated = block
            updated.calorieLabel = calorieLabels[block.id]
            updated.nutrition = nutrition[block.id]
            return updated
        }
    }
    
    private static func blockID(for range: NSRange,
                                isImageBlock: Bool,
                                textStorage: NSTextStorage) -> BlockID {
        if let attributedID = textStorage.blockID(at: range.location) {
            return attributedID
        }
        
        if isImageBlock, range.location < textStorage.length,
           let uuid = textStorage.attribute(BlockAttributeKeys.imageBlockID,
                                            at: range.location,
                                            effectiveRange: nil) as? UUID {
            return BlockID(rawValue: uuid)
        }
        
        return BlockID()
    }
}

// MARK: - Style presets

public extension BlockStyle {
    static let paragraphDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12),
        cornerRadius: 12,
        // Visible teal background for paragraph blocks
        backgroundColor: UIColor.systemTeal.withAlphaComponent(0.15),
        spacingBefore: 10,
        spacingAfter: 10  // Normal spacing between paragraphs
    )
    
    /// Default style for image blocks.
    /// Note: `spacingAfter` is dynamically calculated in BlockEditorTextView based on rendered line count:
    /// - 1–2 visual lines -> spacingAfter = 88 (next block stays below the image)
    /// - 3+ visual lines   -> spacingAfter = 10 (text already pushes content down)
    static let imageDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 12),
        cornerRadius: 14,
        // Distinct orange background for image blocks
        backgroundColor: UIColor.systemOrange.withAlphaComponent(0.2),
        spacingBefore: 10,
        spacingAfter: 88  // Initial value - actual spacing calculated dynamically
    )
}


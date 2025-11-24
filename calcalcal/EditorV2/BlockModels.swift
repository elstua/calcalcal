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

public struct BlockMetadata: Equatable {
    public var id: BlockID
    public var kind: BlockKind
    public var style: BlockStyle
    public var calorieLabel: String?
    public var range: NSRange
    /// For image blocks, the actual image to display as an overlay.
    public var image: UIImage?
    
    public init(id: BlockID = BlockID(),
                kind: BlockKind,
                style: BlockStyle? = nil,
                calorieLabel: String? = nil,
                range: NSRange,
                image: UIImage? = nil) {
        self.id = id
        self.kind = kind
        self.style = style ?? kind.defaultStyle
        self.calorieLabel = calorieLabel
        self.range = range
        self.image = image
    }
}

public struct BlockDocument: Equatable {
    public private(set) var blocks: [BlockMetadata]
    
    public init(blocks: [BlockMetadata] = []) {
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
            let spacingBefore: CGFloat = paragraphIndex == 0 ? 0 : 32
            let spacingAfter: CGFloat = 12
            let baseStyle: BlockStyle = kind.defaultStyle
            let style = BlockStyle(
                contentInsets: baseStyle.contentInsets,
                cornerRadius: baseStyle.cornerRadius,
                backgroundColor: baseStyle.backgroundColor,
                spacingBefore: spacingBefore,
                spacingAfter: spacingAfter
            )
            
            // For image blocks, try to extract the BlockID from the marker's attribute.
            var blockID = BlockID()
            if isImageBlock, enclosingRange.location < textStorage.length {
                if let uuid = textStorage.attribute(BlockAttributeKeys.imageBlockID, at: enclosingRange.location, effectiveRange: nil) as? UUID {
                    blockID = BlockID(rawValue: uuid)
                }
            }
            
            let block = BlockMetadata(id: blockID, kind: kind, style: style, range: enclosingRange)
            result.append(block)
            paragraphIndex += 1
        }
        
        if result.isEmpty {
            let style = BlockStyle(
                contentInsets: NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
                cornerRadius: 12,
                backgroundColor: UIColor.secondarySystemBackground,
                spacingBefore: 0,
                spacingAfter: 12
            )
            let block = BlockMetadata(kind: .paragraph, style: style, range: NSRange(location: 0, length: textStorage.length))
            result.append(block)
        }
        
        return result
    }
}

// MARK: - Style presets

public extension BlockStyle {
    static let paragraphDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        cornerRadius: 14,
        // Slightly stronger color so block backgrounds are clearly visible.
        backgroundColor: UIColor.systemTeal.withAlphaComponent(0.25),
        spacingBefore: 16,
        spacingAfter: 16
    )
    
    static let imageDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
        cornerRadius: 18,
        // Stronger contrast for image blocks.
        backgroundColor: UIColor.systemOrange.withAlphaComponent(0.28),
        spacingBefore: 24,
        spacingAfter: 24
    )
}


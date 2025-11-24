import Foundation
import UIKit

@available(iOS 16.0, *)
public struct BlockID: Hashable, Codable {
    public let rawValue: UUID
    public init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

@available(iOS 16.0, *)
public enum BlockKind: Equatable, Codable {
    case paragraph
    case image
    
    var defaultStyle: BlockStyle {
        switch self {
        case .paragraph:
            return .paragraphDefault
        case .image:
            return .imageDefault
        }
    }
}

@available(iOS 16.0, *)
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

@available(iOS 16.0, *)
public struct BlockMetadata: Equatable {
    public var id: BlockID
    public var kind: BlockKind
    public var style: BlockStyle
    public var calorieLabel: String?
    public var range: NSRange
    
    public init(id: BlockID = BlockID(),
                kind: BlockKind,
                style: BlockStyle? = nil,
                calorieLabel: String? = nil,
                range: NSRange) {
        self.id = id
        self.kind = kind
        self.style = style ?? kind.defaultStyle
        self.calorieLabel = calorieLabel
        self.range = range
    }
}

@available(iOS 16.0, *)
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
            let trimmed = string.substring(with: substringRange).trimmingCharacters(in: .whitespacesAndNewlines)
            let kind: BlockKind = trimmed.isEmpty ? .paragraph : .paragraph
            let spacingBefore: CGFloat = paragraphIndex == 0 ? 0 : 16
            let spacingAfter: CGFloat = 12
            let style = BlockStyle(
                contentInsets: NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16),
                cornerRadius: 12,
                backgroundColor: UIColor.secondarySystemBackground,
                spacingBefore: spacingBefore,
                spacingAfter: spacingAfter
            )
            let block = BlockMetadata(kind: kind, style: style, range: enclosingRange)
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

@available(iOS 16.0, *)
public extension BlockStyle {
    static let paragraphDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        cornerRadius: 14,
        backgroundColor: UIColor.secondarySystemBackground,
        spacingBefore: 12,
        spacingAfter: 12
    )
    
    static let imageDefault = BlockStyle(
        contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0),
        cornerRadius: 18,
        backgroundColor: UIColor.tertiarySystemBackground,
        spacingBefore: 20,
        spacingAfter: 20
    )
}


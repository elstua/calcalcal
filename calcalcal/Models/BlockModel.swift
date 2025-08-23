// This file will be moved to calcalcal/Models/BlockModel.swift for shared access.
//
// BlockModel.swift
//

import Foundation

/// Enum representing all possible block types in the unified editor
enum BlockType: Equatable {
    case text(String)
    case image(Data, UUID) // Store image as Data for model, UIImage for UI
    case imageText(Data, UUID, String) // Combined image and text block
    case spacer
    // Extend with more types as needed (e.g., checklist, table)
}

/// Struct representing a block in the editor
struct Block: Equatable {
    var type: BlockType
    var calorieData: String?
    // Add more metadata as needed
} 

// MARK: - Text-only serialization utilities
extension Array where Element == Block {
    /// Serialize blocks to a single plain text `content` string by joining text-bearing blocks
    /// with double newline. Image and spacer blocks are ignored for v1 text persistence.
    func toContentString() -> String {
        let paragraphs: [String] = self.compactMap { block in
            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            case .imageText(_, _, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            case .image:
                return nil
            case .spacer:
                return nil
            }
        }
        return paragraphs.joined(separator: "\n\n")
    }

    /// Build AI analyze payload blocks: text-bearing blocks only with id, position, type, content
    func toAnalyzeBlocks() -> [[String: Any]] {
        var position = 0
        var result: [[String: Any]] = []
        for block in self {
            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    position += 1
                    result.append([
                        "id": UUID().uuidString,
                        "position": position,
                        "type": "text",
                        "content": trimmed
                    ])
                }
            case .imageText(_, _, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    position += 1
                    result.append([
                        "id": UUID().uuidString,
                        "position": position,
                        "type": "text",
                        "content": trimmed
                    ])
                }
            case .image, .spacer:
                continue
            }
        }
        return result
    }
}

extension String {
    /// Deserialize a `content` string into text-only blocks by splitting on double newline.
    /// Image/spacer information is not reconstructible in v1 and is omitted.
    func toTextBlocks() -> [Block] {
        let parts = self.components(separatedBy: "\n\n")
        return parts.map { Block(type: .text($0), calorieData: nil) }
    }
}
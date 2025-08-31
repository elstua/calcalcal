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
struct Block: Equatable, Identifiable {
    var id: UUID = UUID()
    var type: BlockType
    var calorieData: String?
    var nutrition: NutritionData?
    // Stable identifier used for change tracking within editor sessions
    var stableId: UUID? = nil
    // Add more metadata as needed
}

// Equality ignores identity to prevent unnecessary rebuilds when ids differ but content is the same
extension Block {
    static func == (lhs: Block, rhs: Block) -> Bool {
        // Include stableId to avoid treating blocks from different entries as equal when content matches
        return lhs.type == rhs.type && lhs.calorieData == rhs.calorieData && lhs.nutrition == rhs.nutrition && lhs.stableId == rhs.stableId
    }
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
                        "id": block.id.uuidString,
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
                        "id": block.id.uuidString,
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

    /// Ensure every block has a stable identifier and return updated copy
    func withStableIdsAndChangeTracking() -> [Block] {
        return self.map { block in
            var updated = block
            if updated.stableId == nil { updated.stableId = UUID() }
            return updated
        }
    }
}

extension String {
    /// Deserialize a `content` string into text-only blocks by splitting on double newline.
    /// Image/spacer information is not reconstructible in v1 and is omitted.
    func toTextBlocks() -> [Block] {
        let parts = self.components(separatedBy: "\n\n")
        return parts.map { Block(type: .text($0), calorieData: nil, nutrition: nil) }
    }
}

// MARK: - Change tracking helpers
extension Block {
    /// Returns a copy of the block with initialized stable id for change tracking
    func withUpdatedChangeTracking() -> Block {
        var updated = self
        if updated.stableId == nil { updated.stableId = UUID() }
        return updated
    }
}

// MARK: - Nutrition data container
struct NutritionData: Codable, Equatable {
    var calories: Int?
    var protein: Double?
    var fat: Double?
    var carbs: Double?
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var confidence: Double?
}
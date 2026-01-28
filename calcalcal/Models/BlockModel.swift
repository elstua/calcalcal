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
    // Remote image association (persisted via content markers)
    var imageUrl: String? = nil
    // Optional backend object key if available
    var imageObjectKey: String? = nil
    // Stable identifier used for change tracking within editor sessions
    var stableId: UUID? = nil
    // Add more metadata as needed
}

// Equality ignores identity to prevent unnecessary rebuilds when ids differ but content is the same
extension Block {
    static func == (lhs: Block, rhs: Block) -> Bool {
        // Include stableId to avoid treating blocks from different entries as equal when content matches
        return lhs.type == rhs.type
        && lhs.calorieData == rhs.calorieData
        && lhs.nutrition == rhs.nutrition
        && lhs.imageUrl == rhs.imageUrl
        && lhs.imageObjectKey == rhs.imageObjectKey
        && lhs.stableId == rhs.stableId
    }
}

// MARK: - Text-only serialization utilities
extension Array where Element == Block {
    /// Serialize blocks to a single plain text `content` string by joining text-bearing blocks
    /// with double newline.
    ///
    /// For imageText blocks, we prepend a hidden marker line that preserves the image URL and reference:
    /// [[IMG id=<uuid> url=<url>]]
    /// <user text...>
    func toContentString() -> String {
        let paragraphs: [String] = self.compactMap { block in
            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            case .imageText(_, let ref, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if let url = block.imageUrl, !url.isEmpty {
                    // Escape closing marker in URL minimally by replacing "]]" if present
                    let safeUrl = url.replacingOccurrences(of: "]]", with: "%5D%5D")
                    return """
                    [[IMG id=\(ref.uuidString) url=\(safeUrl)]]
                    \(trimmed)
                    """
                } else {
                    // If we have no URL but text exists, persist text; if both empty, drop
                    return trimmed.isEmpty ? nil : trimmed
                }
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
            var dict: [String: Any] = [:]

            switch block.type {
            case .text(let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                position += 1
                dict = [
                    "id": block.id.uuidString,
                    "position": position,
                    "type": "text",
                    "content": trimmed
                ]
            case .imageText(_, _, let text):
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                position += 1
                dict = [
                    "id": block.id.uuidString,
                    "position": position,
                    "type": "text",
                    "content": trimmed
                ]
            case .image, .spacer:
                continue
            }

            // IMPORTANT: Include the userModified flag so the backend can skip re-analysis
            if block.nutrition?.userModified == true {
                dict["userModified"] = true
            }
            
            // Include metadata to preserve client-side state
            if let imageUrl = block.imageUrl {
                dict["imageUrl"] = imageUrl
            }
            if let imageObjectKey = block.imageObjectKey {
                dict["imageObjectKey"] = imageObjectKey
            }
            if let stableId = block.stableId {
                dict["stableId"] = stableId.uuidString
            }

            result.append(dict)
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
    /// Deserialize a `content` string into blocks by splitting on double newline.
    /// Supports image markers in the form:
    /// [[IMG id=<uuid> url=<url>]]
    /// <text...>
    func toTextBlocks() -> [Block] {
        let parts = self.components(separatedBy: "\n\n")
        return parts.map { paragraph -> Block in
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("[[IMG ") {
                // Attempt to parse marker line
                if let endIdx = trimmed.firstIndex(of: "]"),
                   let endEndIdx = trimmed.index(endIdx, offsetBy: 1, limitedBy: trimmed.endIndex),
                   endEndIdx < trimmed.endIndex,
                   trimmed[endIdx...].hasPrefix("]]") || true {
                    // Extract header between [[IMG and ]]
                    if let rangeStart = trimmed.range(of: "[[IMG "),
                       let rangeEnd = trimmed.range(of: "]]") {
                        let header = String(trimmed[rangeStart.upperBound..<rangeEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let rest = String(trimmed[rangeEnd.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        var ref: UUID? = nil
                        var url: String? = nil
                        // Very simple parser: split by spaces, expect key=value pairs
                        header.split(separator: " ").forEach { pair in
                            let comps = pair.split(separator: "=", maxSplits: 1).map(String.init)
                            if comps.count == 2 {
                                let key = comps[0]
                                var value = comps[1]
                                if key == "id" {
                                    ref = UUID(uuidString: value)
                                } else if key == "url" {
                                    value = value.replacingOccurrences(of: "%5D%5D", with: "]]")
                                    url = value
                                }
                            }
                        }
                        if let ref, !rest.isEmpty {
                            var block = Block(type: .imageText(Data(), ref, rest), calorieData: nil, nutrition: nil)
                            block.imageUrl = url
                            return block
                        }
                    }
                }
            }
            return Block(type: .text(paragraph), calorieData: nil, nutrition: nil)
        }
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

// MARK: - Calorie helpers
extension Collection where Element == Block {
    /// Returns the sum of all calories derived from local block metadata.
    /// Falls back to `calorieData` strings when nutrition payload is not available.
    func resolvedCalorieTotal() -> Int? {
        var total = 0
        var hasValue = false
        for block in self {
            guard let value = block.resolvedCalorieValue() else { continue }
            total += Swift.max(0, value)
            hasValue = true
        }
        return hasValue ? total : nil
    }

    /// Returns the sum of all macros derived from local block metadata.
    func resolvedNutritionTotal() -> NutritionData {
        var total = NutritionData(calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0, sugar: 0, sodium: 0, weight: 0, metric_description: nil, confidence: nil, userModified: false)
        
        for block in self {
            if let nutrition = block.nutrition {
                total.calories = (total.calories ?? 0) + (nutrition.calories ?? 0)
                total.protein = (total.protein ?? 0) + (nutrition.protein ?? 0)
                total.fat = (total.fat ?? 0) + (nutrition.fat ?? 0)
                total.carbs = (total.carbs ?? 0) + (nutrition.carbs ?? 0)
                total.fiber = (total.fiber ?? 0) + (nutrition.fiber ?? 0)
                total.sugar = (total.sugar ?? 0) + (nutrition.sugar ?? 0)
                total.sodium = (total.sodium ?? 0) + (nutrition.sodium ?? 0)
            } else if let cal = block.resolvedCalorieValue() {
                // Fallback for calories if nutrition is missing but calorieData exists
                 total.calories = (total.calories ?? 0) + cal
            }
        }
        return total
    }
}

fileprivate extension Block {
    func resolvedCalorieValue() -> Int? {
        if let calories = nutrition?.calories {
            return calories
        }
        guard let label = calorieData?.firstIntegerValue else { return nil }
        return label
    }
}

fileprivate extension String {
    var firstIntegerValue: Int? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = Int(trimmed) {
            return exact
        }
        if let range = range(of: #"-?\d+"#, options: .regularExpression) {
            return Int(self[range])
        }
        return nil
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
    var weight: Double?
    var metric_description: String?
    var confidence: Double?
    var userModified: Bool?
}

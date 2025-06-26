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
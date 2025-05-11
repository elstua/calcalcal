import Foundation

enum BlockType: String, Codable { // Codable might be useful if we persist this
    case textBlock        // Standard text paragraph
    case imagePlaceholder // Placeholder for an image attachment
    case calorieMarker    // Placeholder for calorie calculation/display
    // Add more specific block types as needed, e.g., heading, listitem
} 
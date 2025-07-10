import Foundation
// NOTE: BlockModel.swift must be in the same target for Block to be visible here.
// If not, move BlockModel.swift to Models/ or ensure it is in the same target.

struct DiaryEntry: Identifiable {
    let id: UUID
    let date: Date
    var blocks: [Block] // If error: ensure BlockModel.swift is in the same target
    var totalCalories: Int?
    var lastModified: Date
    var aiGeneratedSummary: String?
} 
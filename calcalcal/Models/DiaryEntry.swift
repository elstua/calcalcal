import Foundation
// NOTE: BlockModel.swift must be in the same target for Block to be visible here.
// If not, move BlockModel.swift to Models/ or ensure it is in the same target.

struct DiaryEntry: Identifiable {
    var id: UUID
    let date: Date
    var blocks: [Block] // If error: ensure BlockModel.swift is in the same target
    var totalCalories: Int?
    var lastModified: Date
    var aiGeneratedSummary: String?

    /// Stable view identifier that doesn't change during entry ID canonicalization
    /// Used to prevent view recreation flicker when local UUID is replaced with server UUID
    var stableViewId: String {
        "\(date.timeIntervalSince1970)"
    }
}

extension DiaryEntry: Equatable {
    static func == (lhs: DiaryEntry, rhs: DiaryEntry) -> Bool {
        lhs.id == rhs.id &&
        lhs.date == rhs.date &&
        lhs.blocks == rhs.blocks &&
        lhs.totalCalories == rhs.totalCalories &&
        lhs.lastModified == rhs.lastModified &&
        lhs.aiGeneratedSummary == rhs.aiGeneratedSummary
    }
}
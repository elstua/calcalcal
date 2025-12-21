import Foundation

struct StreaksData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysWithEntries: Int
    let lastEntryDate: String?
    let streakStartDate: String?
    
    enum CodingKeys: String, CodingKey {
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case totalDaysWithEntries = "total_days_with_entries"
        case lastEntryDate = "last_entry_date"
        case streakStartDate = "streak_start_date"
    }
}

import Foundation

struct StreaksData: Codable {
    let currentStreak: Int
    let longestStreak: Int
    let totalDaysWithEntries: Int
    let lastEntryDate: String?
    let streakStartDate: String?
    

}

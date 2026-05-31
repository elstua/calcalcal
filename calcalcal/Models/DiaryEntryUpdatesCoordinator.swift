import Combine
import Foundation

struct EntryCalorieUpdate {
    let entryId: UUID
    let totalCalories: Int?
}

struct StreaksUpdate {
    let streaks: StreaksData
}

/// Coordinates cross-view notifications about diary entry state changes.
/// Mirrors the pattern of EntryIdentityCoordinator: typed Combine publishers
/// in place of stringly-typed NotificationCenter glue.
final class DiaryEntryUpdatesCoordinator {
    static let shared = DiaryEntryUpdatesCoordinator()
    let calorieUpdates = PassthroughSubject<EntryCalorieUpdate, Never>()
    let streakUpdates = PassthroughSubject<StreaksUpdate, Never>()
    private init() {}
}

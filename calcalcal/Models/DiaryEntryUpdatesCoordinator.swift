import Combine
import Foundation

struct EntryCalorieUpdate {
    let entryId: UUID
    let totalCalories: Int?
}

/// Coordinates cross-view notifications about diary entry state changes.
/// Mirrors the pattern of EntryIdentityCoordinator: typed Combine publishers
/// in place of stringly-typed NotificationCenter glue.
final class DiaryEntryUpdatesCoordinator {
    static let shared = DiaryEntryUpdatesCoordinator()
    let calorieUpdates = PassthroughSubject<EntryCalorieUpdate, Never>()
    private init() {}
}

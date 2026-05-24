import Foundation

/// Centralized notification names used throughout the app
extension Notification.Name {
    // MARK: - Editor Notifications

    // MARK: - App-level Events
    
    /// Posted when streaks data is updated from the backend
    /// userInfo: ["streaks": StreaksResponse]
    static let streaksDataUpdated = Notification.Name("streaksDataUpdated")
    
    /// Posted when an entry's calories/nutrition data is updated from the backend
    /// Used to refresh UI components like DayStripView
    /// userInfo: ["entryId": UUID, "totalCalories": Int?]
    static let diaryEntryCaloriesUpdated = Notification.Name("diaryEntryCaloriesUpdated")
}

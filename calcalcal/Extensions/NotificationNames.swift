import Foundation

/// Centralized notification names used throughout the app
extension Notification.Name {
    // MARK: - Editor Notifications
    
    /// Posted when AI analysis results arrive with per-block nutrition metadata
    /// userInfo: ["entryId": String, "analyzedBlocks": [[String: Any]]]
    static let editorApplyPerBlockMetadata = Notification.Name("editorApplyPerBlockMetadata")

    // MARK: - App-level Events
    
    /// Posted when streaks data is updated from the backend
    /// userInfo: ["streaks": StreaksResponse]
    static let streaksDataUpdated = Notification.Name("streaksDataUpdated")
    
    /// Posted when an entry's calories/nutrition data is updated from the backend
    /// Used to refresh UI components like DayStripView
    /// userInfo: ["entryId": UUID, "totalCalories": Int?]
    static let diaryEntryCaloriesUpdated = Notification.Name("diaryEntryCaloriesUpdated")
}

import Foundation

/// Centralized notification names used throughout the app
extension Notification.Name {
    // MARK: - Editor Notifications
    
    /// Posted when AI analysis results arrive with per-block nutrition metadata
    /// userInfo: ["entryId": String, "analyzedBlocks": [[String: Any]]]
    static let editorApplyPerBlockMetadata = Notification.Name("editorApplyPerBlockMetadata")

    /// Posted when a fly-to animation completes and the real image overlay should be revealed
    /// userInfo: ["blockID": UUID]
    static let editorRevealImageOverlay = Notification.Name("editorRevealImageOverlay")
    
    // MARK: - App-level Events
    
    /// Posted when a diary entry's local ID is resolved to a canonical server ID
    /// userInfo: ["localId": UUID, "serverId": UUID]
    static let diaryEntryCanonicalIdResolved = Notification.Name("diaryEntryCanonicalIdResolved")
    
    /// Posted when streaks data is updated from the backend
    /// userInfo: ["streaks": StreaksResponse]
    static let streaksDataUpdated = Notification.Name("streaksDataUpdated")
    
    /// Posted when an entry's calories/nutrition data is updated from the backend
    /// Used to refresh UI components like DayStripView
    /// userInfo: ["entryId": UUID, "totalCalories": Int?]
    static let diaryEntryCaloriesUpdated = Notification.Name("diaryEntryCaloriesUpdated")
}

import Foundation

/// Centralized notification names used throughout the app
extension Notification.Name {
    // MARK: - Editor Notifications

    // MARK: - App-level Events
    
    /// Posted when streaks data is updated from the backend
    /// userInfo: ["streaks": StreaksResponse]
    static let streaksDataUpdated = Notification.Name("streaksDataUpdated")
}

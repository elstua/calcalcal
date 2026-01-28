import Foundation

/// Centralized logger for tracking data flow and debugging data loss issues
/// This makes it easy to enable/disable logging and see the complete data journey
final class DataFlowLogger {
    static let shared = DataFlowLogger()
    
    // MARK: - Configuration
    
    /// Set to false in production to disable all data flow logging
    var isEnabled: Bool = true
    
    private init() {}
    
    // Helper to print with timestamp
    private func log(_ message: String) {
        guard isEnabled else { return }
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        print("[\(timestamp)] \(message)")
    }
    
    // MARK: - Cache Operations
    
    func cacheSaveStarted(entryId: UUID, blockCount: Int, contentPreview: String) {
        log("💾 CACHE SAVE START - id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount), content='\(contentPreview)'")
    }
    
    func cacheSaveCompleted(entryId: UUID) {
        log("✅ CACHE SAVE DONE - id=\(entryId.uuidString.prefix(8))")
    }
    
    func cacheSaveFailed(entryId: UUID, error: String) {
        log("❌ CACHE SAVE FAILED - id=\(entryId.uuidString.prefix(8)), error=\(error)")
    }
    
    func cacheLoadStarted(entryId: UUID) {
        log("📖 CACHE LOAD - id=\(entryId.uuidString.prefix(8))")
    }
    
    func cacheLoadSuccess(entryId: UUID, blockCount: Int, contentPreview: String) {
        log("✅ CACHE LOAD SUCCESS - id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount), content='\(contentPreview)'")
    }
    
    func cacheLoadMissing(entryId: UUID) {
        log("⚠️ CACHE MISS - id=\(entryId.uuidString.prefix(8))")
    }
    
    func cacheLoadFailed(entryId: UUID, reason: String) {
        log("❌ CACHE LOAD FAILED - id=\(entryId.uuidString.prefix(8)), reason=\(reason)")
    }
    
    // MARK: - Editor Lifecycle
    
    func editorDisappearing(entryId: UUID, blockCount: Int, contentPreview: String) {
        log("🔴 EDITOR CLOSE START - id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount), content='\(contentPreview)'")
    }
    
    func editorDisappeared(entryId: UUID) {
        log("🔴 EDITOR CLOSE DONE - id=\(entryId.uuidString.prefix(8))")
    }
    
    func editorCacheSyncComplete(entryId: UUID) {
        log("✅ EDITOR SYNC CACHE DONE - id=\(entryId.uuidString.prefix(8))")
    }
    
    // MARK: - View Model Updates
    
    func viewModelUpdating(entryId: UUID, blockCount: Int, isPlaceholder: Bool) {
        log("🟢 VM UPDATE START - id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount), placeholder=\(isPlaceholder)")
    }
    
    func viewModelUpdated(entryId: UUID, isPlaceholder: Bool) {
        log("✅ VM UPDATE DONE - id=\(entryId.uuidString.prefix(8)), placeholder=\(isPlaceholder)")
    }
    
    // MARK: - Backend Operations
    
    func backendRefreshStarted(dateFrom: String, dateTo: String) {
        log("🔄 BACKEND REFRESH START - from=\(dateFrom), to=\(dateTo)")
    }
    
    func backendRefreshCompleted(entryCount: Int) {
        log("🔄 BACKEND REFRESH DONE - entries=\(entryCount)")
    }
    
    func backendRefreshFailed(error: String) {
        log("❌ BACKEND REFRESH FAILED - error=\(error)")
    }
    
    func backendRefreshSkipped(reason: String) {
        log("⏭️ BACKEND REFRESH SKIPPED - reason=\(reason)")
    }
    
    // MARK: - Data Mapping
    
    func entryMappingUsingCache(entryId: UUID, blockCount: Int) {
        log("✅ ENTRY MAPPING: Using CACHE - id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount)")
    }
    
    func entryMappingUsingBackendContent(entryId: UUID, contentPreview: String) {
        log("⚠️ ENTRY MAPPING: Using BACKEND CONTENT - id=\(entryId.uuidString.prefix(8)), content='\(contentPreview)'")
    }
    
    func entryApplied(dayKey: String, entryId: UUID, blockCount: Int) {
        log("📝 APPLY ENTRY - day=\(dayKey), id=\(entryId.uuidString.prefix(8)), blocks=\(blockCount)")
    }
    
    func entryOverwritten(dayKey: String, oldBlockCount: Int, newBlockCount: Int, oldContent: String, newContent: String) {
        log("⚠️ ENTRY OVERWRITE - day=\(dayKey), old blocks=\(oldBlockCount), new blocks=\(newBlockCount)")
        log("   Old: '\(oldContent)'")
        log("   New: '\(newContent)'")
    }
    
    // MARK: - Race Condition Prevention
    
    func editorJustClosedFlagSet() {
        log("🚦 EDITOR JUST CLOSED FLAG SET - blocking refreshes")
    }
    
    func editorJustClosedFlagCleared() {
        log("🚦 EDITOR JUST CLOSED FLAG CLEARED - refreshes allowed")
    }
    
    // MARK: - Helper
    
    /// Convenience method to get content preview (first 50 chars)
    static func preview(from blocks: [Block]) -> String {
        return String(blocks.toContentString().prefix(50))
    }
}

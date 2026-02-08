import Foundation
import os.log

/// Service responsible for autosaving diary entries with AI analysis and polling for results
@MainActor
class EditorAutosaveService: ObservableObject {
    private let logger = Logger(subsystem: "com.calcalcal.app", category: "EditorAutosave")
    
    // MARK: - Published State
    
    /// Live total calories updated from backend during polling
    @Published var liveTotalCalories: Int?
    
    /// Flag to prevent autosaves during editor close
    @Published var isClosing: Bool = false
    
    // MARK: - Private State
    
    private var debounceWorkItem: DispatchWorkItem?
    private var autosaveTask: Task<Void, Error>?
    private var loadTask: Task<Void, Never>?
    private var lastSavedContent: String?
    private var lastSavedAt: Date?
    private var suppressRemoteBlockUpdates: Bool = false
    private var pendingRemoteBlocks: [Block]?
    private var hasRefreshedStreaksOnClose: Bool = false
    
    // MARK: - Entry Reference
    
    /// The entry ID being edited (may be canonicalized during save)
    var entryId: UUID
    private let entryDate: Date
    
    // MARK: - Callbacks
    
    /// Callback to update the entry ID when canonicalized
    var onEntryIdUpdated: ((UUID) -> Void)?
    
    /// Callback to update total calories in the parent view
    var onTotalCaloriesUpdated: ((Int?) -> Void)?
    
    // MARK: - Initialization
    
    init(entryId: UUID, entryDate: Date, initialCalories: Int?) {
        self.entryId = entryId
        self.entryDate = entryDate
        self.liveTotalCalories = initialCalories
    }
    
    // MARK: - Public Methods
    
    /// Load existing blocks from backend and apply metadata
    func loadBlocks() {
        loadTask = Task {
            do {
                logger.debug("Loading blocks for entryId=\(self.entryId.uuidString)")
                let dbBlocks = try await DiaryAPI.getBlocksById(entryId.uuidString)
                logger.debug("getBlocksById returned \(dbBlocks.count) blocks")
                
                // Check if task was cancelled before applying results
                if Task.isCancelled {
                    logger.debug("Load task cancelled, not applying blocks")
                    return
                }
                
                await MainActor.run {
                    // Post per-block metadata for this entry using NSDictionary-friendly payload
                    let payload: [[String: Any]] = dbBlocks.map { block in
                        return [
                            "id": block.id ?? "",
                            "position": block.position ?? 0,
                            "content": block.content ?? "",
                            "calories": ((block.calories ?? 0) > 0 ? block.calories! : NSNull()),
                            "protein": ((block.protein ?? 0) > 0 ? block.protein! : NSNull()),
                            "fat": ((block.fat ?? 0) > 0 ? block.fat! : NSNull()),
                            "carbs": ((block.carbs ?? 0) > 0 ? block.carbs! : NSNull()),
                            "fiber": ((block.fiber ?? 0) > 0 ? block.fiber! : NSNull()),
                            "sugar": ((block.sugar ?? 0) > 0 ? block.sugar! : NSNull()),
                            "sodium": ((block.sodium ?? 0) > 0 ? block.sodium! : NSNull()),
                            "weight": ((block.weight ?? 0) > 0 ? block.weight! : NSNull()),
                            "metric_description": (block.metric_description as Any?) ?? NSNull(),
                            "confidence": (block.confidence as Any?) ?? NSNull()
                        ]
                    }
                    NotificationCenter.default.post(
                        name: .editorApplyPerBlockMetadata,
                        object: nil,
                        userInfo: [
                            "entryId": entryId.uuidString,
                            "analyzedBlocks": payload
                        ]
                    )
                }
            } catch {
                // Best-effort; ignore if blocks not available yet
                logger.debug("Failed to load blocks: \(error.localizedDescription)")
            }
        }
    }
    
    /// Initialize last saved content to avoid initial autosave loop
    func setInitialContent(blocks: [Block]) {
        let initial = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        lastSavedContent = initial
    }
    
    /// Schedule autosave if text content has changed (called from text change events)
    func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        // Don't schedule autosaves if we're closing
        if isClosing { return }
        
        // Only autosave on explicit paragraph commit or when editing a previously saved paragraph.
        // Routine text changes are ignored; notifications will trigger scheduleAutosave(blocks:).
        if suppressRemoteBlockUpdates { return }
        
        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent {
            logger.debug("Autosave skipped (text unchanged)")
            return
        }
        // Do not autosave on every keystroke anymore. Wait for paragraph-level notifications.
    }
    
    /// Schedule autosave with debouncing (called from paragraph commit events)
    func scheduleAutosave(blocks: [Block]) {
        // Don't schedule autosaves if we're closing
        if isClosing {
            logger.debug("Autosave skipped (editor closing)")
            return
        }
        
        debounceWorkItem?.cancel()
        autosaveTask?.cancel() // Cancel any existing autosave to prevent overlap
        logger.debug("Autosave scheduled in 1s…")
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.logger.debug("Autosave firing…")
            self.autosaveTask = Task { await self.save(blocks: blocks) }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    /// Flush any pending save without AI analysis (called on editor close)
    func flushSave(blocks: [Block]) {
        if let work = debounceWorkItem {
            work.cancel()
            debounceWorkItem = nil
        }
        autosaveTask?.cancel() // Cancel any existing autosave before flush
        logger.debug("Flushing autosave on close…")
        // Do immediate save without AI analysis to prevent contamination
        Task { await saveWithoutAIAnalysis(blocks: blocks) }
    }
    
    /// Cancel all pending async tasks
    func cancelAll() {
        loadTask?.cancel()
        loadTask = nil
        autosaveTask?.cancel()
        autosaveTask = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }
    
    /// Mark as closing to prevent new autosaves
    func markAsClosing() {
        isClosing = true
    }
    
    // MARK: - Private Methods
    
    /// Canonicalize entry ID if server returns a different ID
    private func canonicalizeEntryIfNeeded(row: DiaryAPI.Row, blocks: [Block]) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == entryId { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: entryId, serverId: serverUUID, blocks: blocks)
        entryId = serverUUID
        onEntryIdUpdated?(serverUUID)
    }
    
    /// Full save with AI analysis and polling
    private func save(blocks: [Block]) async {
        // Check if task was cancelled before starting save
        if Task.isCancelled {
            logger.debug("Save task cancelled for entryId=\(self.entryId.uuidString)")
            return
        }
        
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasOnlyPlaceholder = blocks.allSatisfy { block in
            switch block.type {
            case .text(let text):
                return text.isPlaceholderText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .imageText(_, _, let text):
                return text.isPlaceholderText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default:
                return true
            }
        }
        if trimmed.isEmpty || hasOnlyPlaceholder {
            logger.debug("Autosave skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entryDate, offsetMinutes: offsetMinutes)
        logger.debug("Autosave: entryId=\(self.entryId.uuidString), computed day=\(day)")
        do {
            // Ensure we have a valid authenticated session for writes (RLS requires it)
            guard let _ = try? KeychainManager.shared.loadTokens() else {
                logger.warning("Missing auth session; autosave deferred until user signs in")
                return
            }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                logger.debug("Upserting content for day \(day)…")
                let blocksPayload = blocks.toAnalyzeBlocks()
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content, blocks: blocksPayload)
                logger.debug("Autosave result - local_id=\(self.entryId.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                // Save blocks cache after successful upsert
                BlocksCache.shared.save(entryId: entryId, blocks: blocks)
                
                // Check if task was cancelled before starting AI analysis
                if Task.isCancelled {
                    logger.debug("Save task cancelled before AI analysis for entryId=\(self.entryId.uuidString)")
                    return
                }
                
                // Run AI analysis + polling in same Task so cancelling autosaveTask cancels everything
                let payload = blocks.toAnalyzeBlocks()
                let isContentEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if isContentEmpty {
                    try await DiaryAPI.clearEntryNutrition(entryId: row.id)
                    await MainActor.run {
                        self.liveTotalCalories = 0
                        onTotalCaloriesUpdated?(0)
                    }
                } else {
                    do {
                        let analyzedBlocks = try await DiaryAPI.getAnalyzedBlocksById(row.id)
                        
                        // Check if any blocks have actual nutrition data (not just empty analysis)
                        let hasActualNutritionData = analyzedBlocks.contains { block in
                            (block.calories ?? 0) > 0 ||
                            (block.protein ?? 0) > 0 ||
                            (block.fat ?? 0) > 0 ||
                            (block.carbs ?? 0) > 0
                        }
                        
                        if !analyzedBlocks.isEmpty && hasActualNutritionData {
                            // Use incremental analysis by comparing content
                            let currentContentBlocks = blocks.toAnalyzeBlocks()
                            let existingContentBlocks = analyzedBlocks.map { analyzedBlock in
                                return [
                                    "id": analyzedBlock.id,
                                    "position": analyzedBlock.position,
                                    "type": "text",
                                    "content": analyzedBlock.content
                                ] as [String: Any]
                            }
                            
                            // Find blocks that need analysis (new or changed content)
                            let blocksNeedingAnalysis = currentContentBlocks.filter { currentBlock in
                                let currentContent = (currentBlock["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                return !existingContentBlocks.contains { existingBlock in
                                    let existingContent = (existingBlock["content"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                                    return currentContent == existingContent
                                }
                            }
                            
                            if !blocksNeedingAnalysis.isEmpty {
                                // Use incremental analysis
                                _ = try await DiaryAPI.analyzeIncremental(
                                    entryId: row.id,
                                    blocksPayload: blocksNeedingAnalysis,
                                    existingBlocks: analyzedBlocks
                                )
                                logger.debug("Incremental analyze triggered for entry \(row.id) with \(blocksNeedingAnalysis.count) blocks")
                            } else {
                                logger.debug("No blocks need analysis for entry \(row.id)")
                            }
                        } else {
                            // No existing analysis or no actual nutrition data, use full analysis
                            _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                            logger.debug("Full analyze triggered for entry \(row.id) with \(payload.count) blocks")
                        }
                    } catch {
                        _ = try? await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                        logger.debug("Fallback full analyze for entry \(row.id)")
                    }
                    
                    // Poll for updated totals and per-block calories (fewer rounds to reduce requests)
                    var hasReceivedNutritionData = false
                    let delays: [Double] = [1.2, 2.5, 4.0, 6.0, 9.0]
                    for delay in delays {
                        if hasReceivedNutritionData {
                            break
                        }
                        
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        
                        // Check if task was cancelled before making database calls
                        if Task.isCancelled {
                            logger.debug("Autosave polling cancelled for entry \(row.id)")
                            return
                        }
                        
                        let refreshed = try? await DiaryAPI.getById(row.id)
                        let dbBlocks = try? await DiaryAPI.getBlocksById(row.id)
                        await MainActor.run {
                            if let refreshed {
                                self.liveTotalCalories = refreshed.total_calories ?? self.liveTotalCalories
                                onTotalCaloriesUpdated?(refreshed.total_calories)
                                
                                // Notify other UI components that calories have been updated
                                NotificationCenter.default.post(
                                    name: .diaryEntryCaloriesUpdated,
                                    object: nil,
                                    userInfo: [
                                        "entryId": entryId,
                                        "totalCalories": refreshed.total_calories as Any
                                    ]
                                )
                            }
                            if let dbBlocks,
                               dbBlocks.contains(where: { ($0.calories ?? 0) > 0 || ($0.protein ?? 0) > 0 || ($0.fat ?? 0) > 0 || ($0.carbs ?? 0) > 0 }) {
                                hasReceivedNutritionData = true
                                let payload: [[String: Any]] = dbBlocks.map { block in
                                    [
                                        "id": block.id ?? "",
                                        "position": block.position ?? 0,
                                        "content": block.content ?? "",
                                        "calories": ((block.calories ?? 0) > 0 ? block.calories! : NSNull()),
                                        "protein": ((block.protein ?? 0) > 0 ? block.protein! : NSNull()),
                                        "fat": ((block.fat ?? 0) > 0 ? block.fat! : NSNull()),
                                        "carbs": ((block.carbs ?? 0) > 0 ? block.carbs! : NSNull()),
                                        "fiber": ((block.fiber ?? 0) > 0 ? block.fiber! : NSNull()),
                                        "sugar": ((block.sugar ?? 0) > 0 ? block.sugar! : NSNull()),
                                        "sodium": ((block.sodium ?? 0) > 0 ? block.sodium! : NSNull()),
                                        "weight": ((block.weight ?? 0) > 0 ? block.weight! : NSNull()),
                                        "metric_description": (block.metric_description as Any?) ?? NSNull(),
                                        "confidence": (block.confidence as Any?) ?? NSNull()
                                    ]
                                }
                                NotificationCenter.default.post(
                                    name: .editorApplyPerBlockMetadata,
                                    object: nil,
                                    userInfo: ["entryId": entryId.uuidString, "analyzedBlocks": payload]
                                )
                            }
                        }
                    }
                }
                await MainActor.run {
                    onTotalCaloriesUpdated?(row.total_calories)
                }
            } else {
                logger.warning("Missing user id; deferring insert until available")
                return
            }
            lastSavedAt = Date()
            lastSavedContent = trimmed
            logger.info("Autosave success")
        } catch {
            logger.error("Autosave error: \(error.localizedDescription)")
        }
    }
    
    /// Save content to database without triggering AI analysis (used during overlay dismissal)
    private func saveWithoutAIAnalysis(blocks: [Block]) async {
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasOnlyPlaceholder = blocks.allSatisfy { block in
            switch block.type {
            case .text(let text):
                return text.isPlaceholderText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .imageText(_, _, let text):
                return text.isPlaceholderText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            default:
                return true
            }
        }
        if trimmed.isEmpty || hasOnlyPlaceholder {
            logger.debug("Flush save skipped (empty/placeholder content)")
            // Still refresh streaks even if content is empty (user might have deleted content)
            await refreshStreaksAfterSave()
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entryDate, offsetMinutes: offsetMinutes)
        
        do {
            guard let _ = try? KeychainManager.shared.loadTokens() else {
                logger.warning("Missing auth session; flush save deferred")
                return
            }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                logger.debug("Flush saving content for day \(day)…")
                let blocksPayload = blocks.toAnalyzeBlocks()
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content, blocks: blocksPayload)
                logger.debug("Flush save result - local_id=\(self.entryId.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                
                lastSavedAt = Date()
                lastSavedContent = trimmed
                logger.info("Flush save success (no AI analysis)")
                // Save blocks cache on flush as well
                BlocksCache.shared.save(entryId: entryId, blocks: blocks)
                
                // CRITICAL: Refresh streaks AFTER save completes successfully
                // This ensures the backend has the latest entry data when calculating streaks
                await refreshStreaksAfterSave()
            } else {
                logger.warning("Missing user id; deferring flush save")
            }
        } catch {
            logger.error("Flush save error: \(error.localizedDescription)")
            // Still try to refresh streaks even on error
            await refreshStreaksAfterSave()
        }
    }
    
    /// Fetch streaks once after save completes (called from saveWithoutAIAnalysis)
    private func refreshStreaksAfterSave() async {
        guard !hasRefreshedStreaksOnClose else { return }
        hasRefreshedStreaksOnClose = true
        
        do {
            let streaks = try await DiaryAPI.getStreaks()
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .streaksDataUpdated,
                    object: nil,
                    userInfo: ["streaks": streaks]
                )
            }
            logger.debug("Streaks refreshed after save")
        } catch {
            logger.debug("Streaks refresh after save failed: \(error.localizedDescription)")
        }
    }
}

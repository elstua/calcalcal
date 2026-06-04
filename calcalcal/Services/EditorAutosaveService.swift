import Foundation
import Combine
import os.log

struct EditorMetadataUpdate {
    let entryId: UUID
    let analyzedBlocks: [[String: Any]]
}

/// Service responsible for autosaving diary entries with AI analysis and polling for results
@MainActor
class EditorAutosaveService: ObservableObject {
    private let logger = Logger(subsystem: "com.calcalcal.app", category: "EditorAutosave")
    
    // MARK: - Published State
    
    /// Live total calories updated from backend during polling
    @Published var liveTotalCalories: Int?
    
    /// Flag to prevent autosaves during editor close
    @Published var isClosing: Bool = false

    /// Last analysis error message to surface in the editor.
    @Published var lastAnalysisError: String? = nil

    let metadataUpdates = PassthroughSubject<EditorMetadataUpdate, Never>()
    
    // MARK: - Private State
    
    private var debounceWorkItem: DispatchWorkItem?
    private var autosaveTask: Task<Void, Error>?
    private var loadTask: Task<Void, Never>?
    private var lastSavedContent: String?
    private var lastSavedAt: Date?
    private var inFlightSaveSignatures = Set<String>()
    private var lastSuccessfulSaveSignature: String?
    private var cachedAnalyzedBlocks: [AnalyzedBlock]?
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
                let analyzedBlocks = dbBlocks.compactMap { $0.toAnalyzedBlock() }
                
                // Check if task was cancelled before applying results
                if Task.isCancelled {
                    logger.debug("Load task cancelled, not applying blocks")
                    return
                }
                
                await MainActor.run {
                    self.cachedAnalyzedBlocks = analyzedBlocks
                    let payload = self.metadataPayload(from: dbBlocks)
                    self.metadataUpdates.send(EditorMetadataUpdate(entryId: entryId, analyzedBlocks: payload))
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
        lastSuccessfulSaveSignature = saveSignature(content: blocks.toContentString(), blocksPayload: blocks.toAnalyzeBlocks())
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
        scheduleAutosave(blocks: blocks)
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

    /// Persist the current editor blocks without starting AI analysis.
    /// Used by the image pipeline so `/analyze-block` has a durable block to update.
    func saveBlocksWithoutAIAnalysis(blocks: [Block]) async {
        await saveWithoutAIAnalysis(blocks: blocks, refreshStreaks: false)
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

    private func saveSignature(content: String, blocksPayload: [[String: Any]]) -> String {
        let blockParts = blocksPayload.map { block in
            block.keys.sorted().map { key in
                "\(key)=\(String(describing: block[key] ?? ""))"
            }.joined(separator: ",")
        }
        return ([content] + blockParts).joined(separator: "\u{1F}")
    }

    private func beginSaveSubmission(signature: String, label: String) -> Bool {
        if inFlightSaveSignatures.contains(signature) {
            logger.debug("\(label) skipped (identical save already in flight)")
            return false
        }
        if lastSuccessfulSaveSignature == signature {
            logger.debug("\(label) skipped (identical content already saved)")
            return false
        }
        inFlightSaveSignatures.insert(signature)
        return true
    }

    private func markSaveSucceeded(signature: String) {
        lastSuccessfulSaveSignature = signature
    }

    private func finishSaveSubmission(signature: String) {
        inFlightSaveSignatures.remove(signature)
    }

    private func postAnalysisState(for blocksPayload: [[String: Any]], isAnalyzing: Bool) {
        guard !blocksPayload.isEmpty else { return }
        let payload = blocksPayload.map { block -> [String: Any] in
            [
                "id": block["id"] as? String ?? "",
                "position": block["position"] as? Int ?? 0,
                "content": block["content"] as? String ?? "",
                "isAnalyzing": isAnalyzing
            ]
        }
        self.metadataUpdates.send(EditorMetadataUpdate(entryId: entryId, analyzedBlocks: payload))
    }

    /// Converts backend DB blocks into the NSDictionary-friendly metadata payload
    /// consumed by the editor. Keep this shape stable: the TextKit bridge expects
    /// missing/zero nutrition values as `NSNull()` rather than absent keys.
    private func metadataPayload(from dbBlocks: [DiaryAPI.DBBlock]) -> [[String: Any]] {
        dbBlocks.map { block in
            [
                "id": block.id ?? "",
                "position": block.position ?? 0,
                "content": block.content ?? "",
                "calories": positiveOrNull(block.calories),
                "protein": positiveOrNull(block.protein),
                "fat": positiveOrNull(block.fat),
                "carbs": positiveOrNull(block.carbs),
                "fiber": positiveOrNull(block.fiber),
                "sugar": positiveOrNull(block.sugar),
                "sodium": positiveOrNull(block.sodium),
                "weight": positiveOrNull(block.weight),
                "metric_description": (block.metric_description as Any?) ?? NSNull(),
                "confidence": (block.confidence as Any?) ?? NSNull()
            ]
        }
    }

    private func positiveOrNull<T: BinaryInteger>(_ value: T?) -> Any {
        guard let value, value > 0 else { return NSNull() }
        return value
    }

    private func positiveOrNull<T: BinaryFloatingPoint>(_ value: T?) -> Any {
        guard let value, value > 0 else { return NSNull() }
        return value
    }

    private func postAnalysisError(_ message: String) {
        self.lastAnalysisError = message
    }

    private func blocksNeedingAnalysis(currentBlocks: [[String: Any]], analyzedBlocks: [AnalyzedBlock]) -> [[String: Any]] {
        let existingByID = Dictionary(uniqueKeysWithValues: analyzedBlocks.map { ($0.id, $0) })

        return currentBlocks.filter { currentBlock in
            let currentID = currentBlock["id"] as? String ?? ""
            let currentContent = normalizedContent(currentBlock["content"] as? String)
            guard !currentContent.isEmpty else { return false }

            if (currentBlock["userModified"] as? Bool) == true {
                return false
            }

            if let existing = existingByID[currentID] {
                let existingContent = normalizedContent(existing.content)
                return existingContent != currentContent || !hasMeaningfulNutrition(existing)
            }

            return !analyzedBlocks.contains { existing in
                normalizedContent(existing.content) == currentContent && hasMeaningfulNutrition(existing)
            }
        }
    }

    private func fallbackBlocksNeedingAnalysis(from blocks: [Block]) -> [[String: Any]] {
        let payload = blocks.toAnalyzeBlocks()
        return payload.filter { currentBlock in
            let currentID = currentBlock["id"] as? String
            guard let uuidString = currentID,
                  let uuid = UUID(uuidString: uuidString),
                  let block = blocks.first(where: { $0.id == uuid }) else {
                return true
            }
            if block.nutrition?.userModified == true {
                return false
            }
            return !blockHasMeaningfulNutrition(block)
        }
    }

    private func normalizedContent(_ content: String?) -> String {
        (content ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: String(placeholderMarker), with: "")
    }

    private func hasMeaningfulNutrition(_ block: AnalyzedBlock) -> Bool {
        (block.calories ?? 0) > 0 ||
        (block.protein ?? 0) > 0 ||
        (block.fat ?? 0) > 0 ||
        (block.carbs ?? 0) > 0
    }

    private func blockHasMeaningfulNutrition(_ block: Block) -> Bool {
        if let nutrition = block.nutrition {
            return (nutrition.calories ?? 0) > 0 ||
            (nutrition.protein ?? 0) > 0 ||
            (nutrition.fat ?? 0) > 0 ||
            (nutrition.carbs ?? 0) > 0
        }
        return block.calorieData?.firstIntegerValueForAnalysis != nil
    }

    private func blockHasMeaningfulNutrition(_ block: DiaryAPI.DBBlock) -> Bool {
        (block.calories ?? 0) > 0 ||
        (block.protein ?? 0) > 0 ||
        (block.fat ?? 0) > 0 ||
        (block.carbs ?? 0) > 0
    }

    private func hasNutritionForPendingBlocks(dbBlocks: [DiaryAPI.DBBlock], pendingBlocks: [[String: Any]]) -> Bool {
        guard !pendingBlocks.isEmpty else { return false }
        return pendingBlocks.allSatisfy { pending in
            let pendingID = pending["id"] as? String
            let pendingContent = normalizedContent(pending["content"] as? String)
            return dbBlocks.contains { dbBlock in
                let idMatches = pendingID != nil && dbBlock.id == pendingID
                let contentMatches = !pendingContent.isEmpty && normalizedContent(dbBlock.content) == pendingContent
                return (idMatches || contentMatches) && blockHasMeaningfulNutrition(dbBlock)
            }
        }
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
        let blocksPayload = blocks.toAnalyzeBlocks()
        let signature = saveSignature(content: content, blocksPayload: blocksPayload)
        guard beginSaveSubmission(signature: signature, label: "Autosave") else {
            return
        }
        defer {
            finishSaveSubmission(signature: signature)
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
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content, blocks: blocksPayload)
                markSaveSucceeded(signature: signature)
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
                let isContentEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if isContentEmpty {
                    try await DiaryAPI.clearEntryNutrition(entryId: row.id)
                    await MainActor.run {
                        self.liveTotalCalories = 0
                        onTotalCaloriesUpdated?(0)
                    }
                } else {
                    var pendingAnalysisPayload: [[String: Any]] = []
                    do {
                        let analyzedBlocks = cachedAnalyzedBlocks ?? row.blocks?.compactMap { $0.toAnalyzedBlock() } ?? []
                        
                        let currentContentBlocks = blocks.toAnalyzeBlocks()
                        let blocksNeedingAnalysis = self.blocksNeedingAnalysis(
                            currentBlocks: currentContentBlocks,
                            analyzedBlocks: analyzedBlocks
                        )

                        if !blocksNeedingAnalysis.isEmpty {
                            pendingAnalysisPayload = blocksNeedingAnalysis
                            if analyzedBlocks.isEmpty {
                                _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: blocksNeedingAnalysis)
                                logger.debug("Analyze triggered for entry \(row.id) with \(blocksNeedingAnalysis.count) pending blocks")
                            } else {
                                _ = try await DiaryAPI.analyzeIncremental(
                                    entryId: row.id,
                                    blocksPayload: blocksNeedingAnalysis,
                                    existingBlocks: analyzedBlocks
                                )
                                logger.debug("Incremental analyze triggered for entry \(row.id) with \(blocksNeedingAnalysis.count) pending blocks")
                            }
                            await MainActor.run {
                                self.postAnalysisState(for: blocksNeedingAnalysis, isAnalyzing: true)
                            }
                        } else {
                            logger.debug("No blocks need analysis for entry \(row.id)")
                        }
                    } catch {
                        pendingAnalysisPayload = fallbackBlocksNeedingAnalysis(from: blocks)
                        if pendingAnalysisPayload.isEmpty {
                            logger.debug("Analysis fallback skipped; no local blocks need analysis for entry \(row.id)")
                            await MainActor.run {
                                self.postAnalysisError("We couldn't check for calorie updates. Existing calories were left unchanged.")
                            }
                        } else {
                            do {
                                _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: pendingAnalysisPayload)
                                await MainActor.run {
                                    self.postAnalysisState(for: pendingAnalysisPayload, isAnalyzing: true)
                                }
                                logger.debug("Fallback analyze for entry \(row.id) with \(pendingAnalysisPayload.count) pending blocks")
                            } catch {
                                await MainActor.run {
                                    self.postAnalysisState(for: pendingAnalysisPayload, isAnalyzing: false)
                                    self.postAnalysisError("We couldn't analyze those calories. Please try again.")
                                }
                                return
                            }
                        }
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
                        let dbBlocks = refreshed?.blocks
                        await MainActor.run {
                            if let refreshed {
                                self.liveTotalCalories = refreshed.total_calories ?? self.liveTotalCalories
                                onTotalCaloriesUpdated?(refreshed.total_calories)
                                
                                DiaryEntryUpdatesCoordinator.shared.calorieUpdates.send(
                                    EntryCalorieUpdate(entryId: entryId, totalCalories: refreshed.total_calories)
                                )
                            }
                            if let refreshed,
                               refreshed.ai_analysis_status == "completed",
                               let dbBlocks,
                               self.hasNutritionForPendingBlocks(dbBlocks: dbBlocks, pendingBlocks: pendingAnalysisPayload) {
                                hasReceivedNutritionData = true
                                self.cachedAnalyzedBlocks = dbBlocks.compactMap { $0.toAnalyzedBlock() }
                                let payload = self.metadataPayload(from: dbBlocks)
                                self.metadataUpdates.send(EditorMetadataUpdate(entryId: entryId, analyzedBlocks: payload))
                            }
                        }
                    }

                    if !pendingAnalysisPayload.isEmpty && !hasReceivedNutritionData {
                        await MainActor.run {
                            self.postAnalysisState(for: pendingAnalysisPayload, isAnalyzing: false)
                            self.postAnalysisError("Calorie analysis is taking longer than expected. Please try again in a moment.")
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
            if !Task.isCancelled {
                postAnalysisError("We couldn't save your entry. Please check your connection and try again.")
            }
        }
    }
    
    /// Save content to database without triggering AI analysis (used during overlay dismissal)
    private func saveWithoutAIAnalysis(blocks: [Block], refreshStreaks: Bool = false) async {
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
            if refreshStreaks {
                await refreshStreaksAfterSave()
            }
            return
        }
        if trimmed == lastSavedContent {
            logger.debug("Flush save skipped (content unchanged)")
            return
        }
        let blocksPayload = blocks.toAnalyzeBlocks()
        let signature = saveSignature(content: content, blocksPayload: blocksPayload)
        guard beginSaveSubmission(signature: signature, label: "Flush save") else {
            return
        }
        defer {
            finishSaveSubmission(signature: signature)
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
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content, blocks: blocksPayload)
                markSaveSucceeded(signature: signature)
                logger.debug("Flush save result - local_id=\(self.entryId.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                
                lastSavedAt = Date()
                lastSavedContent = trimmed
                logger.info("Flush save success (no AI analysis)")
                // Save blocks cache on flush as well
                BlocksCache.shared.save(entryId: entryId, blocks: blocks)
                
                if refreshStreaks {
                    await refreshStreaksAfterSave()
                }
            } else {
                logger.warning("Missing user id; deferring flush save")
            }
        } catch {
            logger.error("Flush save error: \(error.localizedDescription)")
            if refreshStreaks {
                await refreshStreaksAfterSave()
            }
        }
    }
    
    /// Fetch streaks once after save completes (called from saveWithoutAIAnalysis)
    private func refreshStreaksAfterSave() async {
        guard !hasRefreshedStreaksOnClose else { return }
        hasRefreshedStreaksOnClose = true
        
        do {
            let streaks = try await DiaryAPI.getStreaks()
            await MainActor.run {
                DiaryEntryUpdatesCoordinator.shared.streakUpdates.send(
                    StreaksUpdate(streaks: streaks)
                )
            }
            logger.debug("Streaks refreshed after save")
        } catch {
            logger.debug("Streaks refresh after save failed: \(error.localizedDescription)")
        }
    }
}

private extension String {
    var firstIntegerValueForAnalysis: Int? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = Int(trimmed) {
            return exact
        }
        if let range = range(of: #"-?\d+"#, options: .regularExpression) {
            return Int(self[range])
        }
        return nil
    }
}

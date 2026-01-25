import Foundation
import UIKit
import Combine

/// ViewModel for the EditorOverlayView that manages editor state, autosave, and image handling.
/// Separates business logic from the view layer.
@MainActor
final class EditorOverlayViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var canonicalEntryId: UUID
    @Published var blocks: [Block]
    @Published var liveTotalCalories: Int?
    @Published var imageMap: [UUID: UIImage] = [:]
    @Published var isClosing: Bool = false
    
    // MARK: - Internal State
    private var debounceWorkItem: DispatchWorkItem?
    private var lastSavedAt: Date?
    private var lastSavedContent: String?
    private var suppressRemoteBlockUpdates: Bool = false
    private var pendingRemoteBlocks: [Block]?
    private var loadTask: Task<Void, Never>?
    private var autosaveTask: Task<Void, Error>?
    
    // MARK: - Entry Data
    let entry: DiaryEntry
    
    // MARK: - Initialization
    init(entry: DiaryEntry) {
        self.entry = entry
        self.canonicalEntryId = entry.id
        self.blocks = entry.blocks
        self.liveTotalCalories = entry.totalCalories
    }
    
    // MARK: - Setup & Cleanup
    
    func setupOverlay() {
        isClosing = false
        liveTotalCalories = entry.totalCalories
        
        loadTask = Task {
            await loadBlocksFromServer()
        }
        
        Task {
            blocks = blocks.withStableIdsAndChangeTracking()
        }
        
        let initial = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        lastSavedContent = initial
        hydrateImagesForOverlay()
    }
    
    func cleanupOverlay() {
        loadTask?.cancel()
        loadTask = nil
        autosaveTask?.cancel()
        autosaveTask = nil
        
        flushSave()
        
        if let pending = pendingRemoteBlocks {
            blocks = pending
            pendingRemoteBlocks = nil
        }
        suppressRemoteBlockUpdates = false
    }
    
    // MARK: - Block Loading
    
    private func loadBlocksFromServer() async {
        do {
            let dbBlocks = try await DiaryAPI.getBlocksById(canonicalEntryId.uuidString)
            if Task.isCancelled { return }
            
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
                userInfo: [
                    "entryId": canonicalEntryId,
                    "analyzedBlocks": payload
                ]
            )
            hydrateImagesForOverlay()
        } catch {
            // Best-effort
        }
    }
    
    // MARK: - Block Updates
    
    func handleBlocksChange(_ updatedBlocks: [Block]) {
        blocks = updatedBlocks
        BlocksCache.shared.save(entryId: canonicalEntryId, blocks: updatedBlocks)
        scheduleAutosaveIfTextChanged(blocks: updatedBlocks)
    }
    
    func processBlocksUpdate(_ newValue: [Block]) {
        let updatedBlocks = newValue.map { block in
            if block.stableId == nil {
                return block.withUpdatedChangeTracking()
            }
            return block
        }
        if updatedBlocks != newValue {
            blocks = updatedBlocks
        }
        BlocksCache.shared.save(entryId: canonicalEntryId, blocks: updatedBlocks)
        scheduleAutosaveIfTextChanged(blocks: updatedBlocks)
    }
    
    // MARK: - Entry Builder
    
    func overlayEntry() -> DiaryEntry {
        DiaryEntry(
            id: canonicalEntryId,
            date: entry.date,
            blocks: blocks,
            totalCalories: liveTotalCalories ?? entry.totalCalories,
            lastModified: entry.lastModified,
            aiGeneratedSummary: entry.aiGeneratedSummary
        )
    }
    
    // MARK: - Image Handling
    
    /// Handles a picked image, creates a block, uploads it, and triggers analysis.
    /// - Parameters:
    ///   - image: The image picked by the user
    ///   - onComplete: Callback to refocus the editor after processing starts
    func handleImagePicked(_ image: UIImage, onComplete: @escaping () -> Void) {
        let uuid = UUID()
        let compressed = ImageCompression.compressForUpload(image, maxDimension: 720, quality: 0.7)
        imageMap[uuid] = compressed.resizedImage
        ImageCache.shared.storeLocal(compressed.resizedImage, ref: uuid)
        
        guard let resizedPNG = compressed.resizedImage.pngData() else { return }
        
        let newBlock = Block(type: .imageText(resizedPNG, uuid, ""), calorieData: nil)
        blocks.append(newBlock)
        
        let capturedUUID = uuid
        let blockId = newBlock.id
        let entryId = canonicalEntryId
        
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let upload = try await ImageAPI.uploadJPEG(data: compressed.data, filename: "photo.jpg", contentType: "image/jpeg")
                ImageCache.shared.store(compressed.resizedImage, for: upload.publicUrl)
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    if let idx = self.blocks.firstIndex(where: { block in
                        if case let .imageText(_, ref, _) = block.type { return ref == capturedUUID }
                        return false
                    }) {
                        var updated = self.blocks[idx]
                        updated.imageUrl = upload.publicUrl
                        updated.imageObjectKey = upload.objectKey
                        self.blocks[idx] = updated
                        BlocksCache.shared.save(entryId: entryId, blocks: self.blocks)
                    }
                }
                
                var blockText = ""
                await MainActor.run { [weak self] in
                    if let blockForAnalysis = self?.blocks.first(where: { $0.id == blockId }) {
                        if case let .imageText(_, _, text) = blockForAnalysis.type {
                            blockText = text
                        } else if case let .text(text) = blockForAnalysis.type {
                            blockText = text
                        }
                    }
                }
                
                let contentPayload: [String: Any] = ["imageUrl": upload.publicUrl, "text": blockText]
                
                let analysis = try await DiaryAPI.analyzeBlock(
                    entryId: entryId.uuidString,
                    blockId: blockId.uuidString,
                    content: contentPayload
                )
                
                let nutrition = NutritionData(
                    calories: analysis.calories,
                    protein: analysis.protein,
                    fat: analysis.fat,
                    carbs: analysis.carbs,
                    fiber: analysis.fiber,
                    sugar: analysis.sugar,
                    sodium: analysis.sodium,
                    weight: analysis.weight,
                    metric_description: analysis.metric_description,
                    confidence: analysis.confidence
                )
                
                await MainActor.run { [weak self] in
                    guard let self = self else { return }
                    // Update block with analysis results
                    if let idx = self.blocks.firstIndex(where: { $0.id == blockId }) {
                        var updated = self.blocks[idx]
                        if case let .imageText(data, ref, _) = updated.type {
                            updated.type = .imageText(data, ref, analysis.description ?? blockText)
                        }
                        updated.nutrition = nutrition
                        if let cals = analysis.calories, cals > 0 {
                            updated.calorieData = String(cals)
                        }
                        self.blocks[idx] = updated
                        BlocksCache.shared.save(entryId: entryId, blocks: self.blocks)
                    }
                    
                    // Update total calories for the entry
                    if let totals = analysis.totals {
                        self.liveTotalCalories = totals.total_calories
                        NotificationCenter.default.post(
                            name: .diaryEntryTotalsUpdated,
                            object: nil,
                            userInfo: ["entryId": entryId, "totalCalories": totals.total_calories as Any]
                        )
                    }
                    
                    // Update streaks data reactively
                    if let streaks = analysis.streaks {
                        NotificationCenter.default.post(
                            name: .streaksDataUpdated,
                            object: nil,
                            userInfo: ["streaks": streaks]
                        )
                    }
                }
            } catch {
                #if DEBUG
                print("❌ Image pipeline error: \(error)")
                #endif
            }
        }
        
        // Call completion after a small delay to refocus editor
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            onComplete()
        }
    }
    
    func hydrateImagesForOverlay() {
        for block in blocks {
            switch block.type {
            case .imageText(_, let ref, _):
                if imageMap[ref] != nil { continue }
                if let url = block.imageUrl, !url.isEmpty {
                    if let cached = ImageCache.shared.imageIfCached(for: url) {
                        imageMap[ref] = cached
                    } else {
                        Task.detached { @MainActor [weak self] in
                            if let fetched = await ImageCache.shared.fetch(url) {
                                self?.imageMap[ref] = fetched
                            }
                        }
                    }
                } else {
                    if let cached = ImageCache.shared.localImage(ref: ref, legacyEntryId: entry.id) {
                        imageMap[ref] = cached
                    }
                }
            default:
                continue
            }
        }
    }
    
    // MARK: - Autosave
    
    func canonicalizeEntryIfNeeded(row: DiaryAPI.Row) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == canonicalEntryId { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: canonicalEntryId, serverId: serverUUID, blocks: blocks)
        canonicalEntryId = serverUUID
    }
    
    func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        if suppressRemoteBlockUpdates { return }
        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent { return }
    }
    
    func scheduleAutosave() {
        debounceWorkItem?.cancel()
        autosaveTask?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.autosaveTask = Task { await self.save() }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
    
    func flushSave() {
        if let work = debounceWorkItem {
            work.cancel()
            debounceWorkItem = nil
        }
        autosaveTask?.cancel()
        Task { await saveWithoutAIAnalysis() }
    }
    
    func save() async {
        if Task.isCancelled { return }
        
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = ["write what you ate today", "write what you ate this day"]
        if trimmed.isEmpty || placeholders.contains(trimmed) { return }
        
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        
        do {
            guard let _ = try? KeychainManager.shared.loadTokens() else { return }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                canonicalizeEntryIfNeeded(row: row)
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                
                if Task.isCancelled { return }
                
                let payload = blocks.toAnalyzeBlocks()
                let isContentEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                autosaveTask = Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        if isContentEmpty {
                            try await DiaryAPI.clearEntryNutrition(entryId: row.id)
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .diaryEntryTotalsUpdated,
                                    object: nil,
                                    userInfo: ["entryId": self.canonicalEntryId, "totalCalories": 0]
                                )
                                self.liveTotalCalories = 0
                            }
                        } else {
                            _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                            await self.pollForNutritionData(rowId: row.id)
                        }
                    }
                }
                
                NotificationCenter.default.post(
                    name: .diaryEntryTotalsUpdated,
                    object: nil,
                    userInfo: ["entryId": canonicalEntryId, "totalCalories": row.total_calories as Any]
                )
            }
            
            lastSavedAt = Date()
            lastSavedContent = trimmed
            
            // Refresh streaks after save
            Task {
                do {
                    let streaks = try await DiaryAPI.getStreaks()
                    await MainActor.run {
                        NotificationCenter.default.post(
                            name: .streaksDataUpdated,
                            object: nil,
                            userInfo: ["streaks": streaks]
                        )
                    }
                } catch {
                    print("⚠️ Failed to refresh streaks after autosave: \(error)")
                }
            }
            
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            #if DEBUG
            print("❌ Autosave error: \(error)")
            #endif
        }
    }
    
    private func pollForNutritionData(rowId: String) async {
        var hasReceivedNutritionData = false
        let delays: [Double] = [0.8, 1.2, 2.0, 2.8, 4.0, 5.5, 7.5, 10.0]
        
        for delay in delays {
            if hasReceivedNutritionData { break }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            
            let refreshed = try? await DiaryAPI.getById(rowId)
            let dbBlocks = try? await DiaryAPI.getBlocksById(rowId)
            
            if let refreshed {
                NotificationCenter.default.post(
                    name: .diaryEntryTotalsUpdated,
                    object: nil,
                    userInfo: ["entryId": canonicalEntryId, "totalCalories": refreshed.total_calories as Any]
                )
                liveTotalCalories = refreshed.total_calories ?? liveTotalCalories
            }
            
            if let dbBlocks {
                let nowHasNutritionData = dbBlocks.contains { ($0.calories ?? 0) > 0 }
                if nowHasNutritionData {
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
                        userInfo: ["entryId": canonicalEntryId, "analyzedBlocks": payload]
                    )
                    
                    // Sync nutrition data to HealthKit
                    if let refreshed = refreshed {
                        let totalCalories = refreshed.total_calories ?? 0
                        let totalProtein = refreshed.total_protein ?? 0.0
                        let totalCarbs = refreshed.total_carbs ?? 0.0
                        let totalFat = refreshed.total_fat ?? 0.0
                        
                        Task {
                            await syncToHealthKit(
                                calories: totalCalories,
                                protein: totalProtein,
                                carbs: totalCarbs,
                                fat: totalFat,
                                date: entry.date,
                                entryId: rowId
                            )
                        }
                    }
                }
            }
        }
    }
    
    func saveWithoutAIAnalysis() async {
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = ["write what you ate today", "write what you ate this day"]
        if trimmed.isEmpty || placeholders.contains(trimmed) { return }
        
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        
        do {
            guard let _ = try? KeychainManager.shared.loadTokens() else { return }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                canonicalizeEntryIfNeeded(row: row)
                lastSavedAt = Date()
                lastSavedContent = trimmed
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                
                // Refresh streaks after save
                Task {
                    do {
                        let streaks = try await DiaryAPI.getStreaks()
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .streaksDataUpdated,
                                object: nil,
                                userInfo: ["streaks": streaks]
                            )
                        }
                    } catch {
                        print("⚠️ Failed to refresh streaks after flush save: \(error)")
                    }
                }
            }
        } catch {
            #if DEBUG
            print("❌ Flush save error: \(error)")
            #endif
        }
    }
    
    // MARK: - HealthKit Sync
    
    func syncToHealthKit(
        calories: Int,
        protein: Double,
        carbs: Double,
        fat: Double,
        date: Date,
        entryId: String
    ) async {
        let healthKitManager = HealthKitManager.shared
        
        // Only sync if HealthKit is available and sync is enabled
        guard healthKitManager.isAvailable && healthKitManager.isSyncEnabled else {
            print("[HealthKit] Sync skipped - not available or disabled")
            return
        }
        
        // Skip if all values are zero
        guard calories > 0 || protein > 0 || carbs > 0 || fat > 0 else {
            print("[HealthKit] Sync skipped - no nutrition data")
            return
        }
        
        do {
            // First, request write permissions if not already granted
            let hasWritePermission = try await healthKitManager.requestWritePermissions()
            guard hasWritePermission else {
                print("[HealthKit] Write permission denied")
                return
            }
            
            // Delete existing data for this date (from our app) to avoid duplicates
            try await healthKitManager.deleteNutritionData(for: date)
            
            // Write new nutrition data
            try await healthKitManager.writeNutritionData(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                date: date,
                entryId: entryId
            )
            
            print("[HealthKit] Successfully synced: \(calories) kcal, \(protein)g protein, \(carbs)g carbs, \(fat)g fat")
        } catch {
            print("[HealthKit] Sync error: \(error.localizedDescription)")
        }
    }
}

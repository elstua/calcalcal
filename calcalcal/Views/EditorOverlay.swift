import SwiftUI
import UIKit

struct EditorOverlay: View {
    let entry: DiaryEntry
    @Binding var blocks: [Block]
    @Binding var shouldBecomeFirstResponder: Bool
    let namespace: Namespace.ID
    let onClose: () -> Void
    @State private var canonicalEntryId: UUID
    
    @State private var showImagePicker: Bool = false
    @State private var pickedImage: UIImage? = nil
    @GestureState private var dragOffset: CGSize = .zero
    @State private var hasDismissedKeyboardForDrag: Bool = false
    @State private var useMatchedGeometry: Bool = true
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var lastSavedAt: Date? = nil
    @State private var lastSavedContent: String? = nil
    @State private var liveTotalCalories: Int? = nil
    @State private var suppressRemoteBlockUpdates: Bool = false
    @State private var pendingRemoteBlocks: [Block]? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var autosaveTask: Task<Void, Error>? = nil
    @State private var imageMap: [UUID: UIImage] = [:]
    
    init(entry: DiaryEntry,
         blocks: Binding<[Block]>,
         shouldBecomeFirstResponder: Binding<Bool>,
         namespace: Namespace.ID,
         onClose: @escaping () -> Void) {
        self.entry = entry
        self._blocks = blocks
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.namespace = namespace
        self.onClose = onClose
        _canonicalEntryId = State(initialValue: entry.id)
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Dimmed background with interactive opacity
            let progress = min(1.0, max(0.0, 1.0 - (dragOffset.height / 400.0)))
            Color.black.opacity(0.35 * progress)
                .ignoresSafeArea()
                .onTapGesture { dismissWithMatched() }
            
            // Wrapper that responds to keyboard. Keep matched view inside for stable geometry.
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    DiaryEditorCard(
                        entry: overlayEntry(),
                        height: 550,
                        cornerRadius: 24,
                        showShadow: false,
                        useExternalDecoration: true,
                        onAddImage: { showImagePicker = true },
                        imageMap: imageMap,
                        isEditable: true,
                        shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                        forceExpanded: true,
                        onBlocksChange: { updated in
                            blocks = updated
                            BlocksCache.shared.save(entryId: canonicalEntryId, blocks: updated)
                            scheduleAutosaveIfTextChanged(blocks: updated)
                        },
                        overrideTotalCalories: liveTotalCalories,
                        externalBlocks: $blocks
                    )
                    .onChange(of: blocks) { newValue in
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
                }
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(Color(.systemBackground))
                        .modifier(ConditionalMatchedGeometry(enabled: useMatchedGeometry, id: "bg-\(entry.id)", namespace: namespace))
                )
                .modifier(ConditionalMatchedGeometry(enabled: useMatchedGeometry, id: entry.id, namespace: namespace))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .offset(y: max(0, dragOffset.height))
            .overlay(alignment: .topTrailing) {
                // Close button
                Button(action: { dismissWithMatched() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .padding(12)
                }
                .padding(.top, 4)
            }
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation
                        if value.translation.height > 8 && !hasDismissedKeyboardForDrag {
                            // Dismiss keyboard to avoid awkward lift during drag
                            shouldBecomeFirstResponder = false
                            hasDismissedKeyboardForDrag = true
                        }
                    }
                    .onEnded { value in
                        let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                        if shouldDismiss {
                            dismissWithMatched()
                        } else {
                            // Restore focus if we had dismissed it for drag
                            if hasDismissedKeyboardForDrag {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    shouldBecomeFirstResponder = true
                                    hasDismissedKeyboardForDrag = false
                                }
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $pickedImage)
                .onDisappear {
                    guard let image = pickedImage else { return }
                    let uuid = UUID()
                    // Downscale for local display and future upload
                    let compressed = ImageCompression.compressForUpload(image, maxDimension: 720, quality: 0.7)
                    // Use resized image in the UI
                    imageMap[uuid] = compressed.resizedImage
                    // Store in local image cache under deterministic key for fallback before URL is known
                    ImageCache.shared.storeLocal(compressed.resizedImage, ref: uuid)
                    // Store PNG data of resized image in the model for stable internal rendering
                    if let resizedPNG = compressed.resizedImage.pngData() {
                        let newBlock = Block(type: .imageText(resizedPNG, uuid, ""), calorieData: nil)
                        blocks.append(newBlock)
                        
                        // Kick off upload + analyze pipeline
                        let capturedUUID = uuid
                        let blockId = newBlock.id
                        let entryIdString: String? = nil // optional for backend
                        Task.detached(priority: .userInitiated) {
                            do {
                                #if DEBUG
                                print("📸 Pipeline: start (uuid=\(capturedUUID)) - compress ok, uploading…")
                                #endif
                                let upload = try await ImageAPI.uploadJPEG(data: compressed.data, filename: "photo.jpg", contentType: "image/jpeg")
                                
                                #if DEBUG
                                print("📸 Pipeline: uploaded -> \(upload.publicUrl), analyzing…")
                                #endif
                                // Persist into disk cache for future sessions
                                ImageCache.shared.store(compressed.resizedImage, for: upload.publicUrl)
                                // Persist image URL/objectKey into the corresponding block for future reloads
                                await MainActor.run {
                                    if let idx = blocks.firstIndex(where: { block in
                                        if case let .imageText(_, ref, _) = block.type { return ref == capturedUUID }
                                        return false
                                    }) {
                                        var updated = blocks[idx]
                                        updated.imageUrl = upload.publicUrl
                                        updated.imageObjectKey = upload.objectKey
                                        blocks[idx] = updated
                                        // Persist blocks cache immediately
                                        BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                                    }
                                }
                                let analysis = try await ImageAPI.analyzeImage(imageUrl: upload.publicUrl, entryId: entryIdString, blockId: blockId.uuidString)
                                
                                #if DEBUG
                                print("📸 Pipeline: analyze result calories=\(String(describing: analysis.calories)) desc='\(analysis.description)'")
                                #endif
                                
                                // Build nutrition model
                                let nutrition = NutritionData(
                                    calories: analysis.calories,
                                    protein: analysis.macros?.protein,
                                    fat: analysis.macros?.fat,
                                    carbs: analysis.macros?.carbs,
                                    fiber: analysis.macros?.fiber,
                                    sugar: analysis.macros?.sugar,
                                    sodium: analysis.macros?.sodium,
                                    confidence: analysis.confidence
                                )
                                
                                // Apply to the inserted block (by imageRef match)
                                await MainActor.run {
                                    if let idx = blocks.firstIndex(where: { block in
                                        if case let .imageText(_, ref, _) = block.type {
                                            return ref == capturedUUID
                                        }
                                        return false
                                    }) {
                                        var updated = blocks[idx]
                                        // Update text with description
                                        if case let .imageText(data, ref, _) = updated.type {
                                            updated.type = .imageText(data, ref, analysis.description)
                                        }
                                        // Ensure image URL stays attached
                                        updated.imageUrl = updated.imageUrl ?? upload.publicUrl
                                        // Update nutrition & calorieData for UI (local-only, totals come from backend)
                                        updated.nutrition = nutrition
                                        if let cals = analysis.calories, cals > 0 {
                                            updated.calorieData = String(cals)
                                        }
                                        blocks[idx] = updated
                                        BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                                        #if DEBUG
                                        print("📸 Pipeline: block \(idx) updated with analysis")
                                        #endif
                                    } else {
                                        #if DEBUG
                                        print("⚠️ Pipeline: could not find block by imageRef=\(capturedUUID)")
                                        #endif
                                    }
                                }
                            } catch {
                                #if DEBUG
                                print("❌ Pipeline error: \(error)")
                                #endif
                            }
                        }
                    }
                    // Ensure keyboard focuses after insert
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        shouldBecomeFirstResponder = true
                    }
                    pickedImage = nil
                }
        }
        .onAppear {
            // Allow matched geometry during the opening transition, then detach
            useMatchedGeometry = true
            liveTotalCalories = entry.totalCalories
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                useMatchedGeometry = false
            }
            // Fetch existing per-block calories for this entry (if already analyzed)
            loadTask = Task {
                do {
                    print("🐛 DEBUG: Loading blocks for entry.id=\(canonicalEntryId.uuidString)")
                    let dbBlocks = try await DiaryAPI.getBlocksById(canonicalEntryId.uuidString)
                    print("🐛 DEBUG: getBlocksById returned \(dbBlocks.count) blocks: \(dbBlocks.map { $0.content ?? "nil" })")
                    
                    // Check if task was cancelled before applying results
                    if Task.isCancelled {
                        print("🐛 DEBUG: Load task cancelled, not applying blocks")
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
                        // Hydrate any images from cache/network
                        hydrateImagesForOverlay()
                    }
                } catch {
                    // Best-effort; ignore if blocks not available yet
                }
            }
            // Initialize blocks with stable IDs and change tracking
            Task {
                await MainActor.run {
                    blocks = blocks.withStableIdsAndChangeTracking()
                }
            }

            // Initialize lastSavedContent to current textual content to avoid initial autosave loop
            let initial = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
            lastSavedContent = initial
            // Initial hydration pass
            hydrateImagesForOverlay()
        }
        .onDisappear {
            // Cancel any pending async tasks to prevent contamination with new overlays
            loadTask?.cancel()
            loadTask = nil
            autosaveTask?.cancel()
            print("🐛 DEBUG: EditorOverlay dismissed, calling cancel() on autosaveTask for entry.id=\(canonicalEntryId.uuidString)")
            autosaveTask = nil
            print("🐛 DEBUG: EditorOverlay dismissed, cancelled load and autosave tasks for entry.id=\(canonicalEntryId.uuidString)")
            
            flushSave()
            // Apply any queued remote updates only after editor closes
            if let pending = pendingRemoteBlocks {
                blocks = pending
                pendingRemoteBlocks = nil
            }
            suppressRemoteBlockUpdates = false
        }
        // Listen for paragraph-level commit/edit notifications to control autosave
        .onReceive(NotificationCenter.default.publisher(for: .editorParagraphCommitted)) { _ in
            print("📝 Paragraph committed -> schedule autosave")
            scheduleAutosave(blocks: blocks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorSavedParagraphEdited)) { _ in
            print("✏️ Saved paragraph edited -> schedule autosave")
            scheduleAutosave(blocks: blocks)
        }
    }
}

// MARK: - UIKit image picker wrapper
struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.presentationMode.wrappedValue.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

extension Notification.Name {
    static let editorOverlayDidCommit = Notification.Name("editorOverlayDidCommit")
    static let editorParagraphCommitted = Notification.Name("editorParagraphCommitted")
    static let editorSavedParagraphEdited = Notification.Name("editorSavedParagraphEdited")
    static let editorApplyPerBlockMetadata = Notification.Name("editorApplyPerBlockMetadata")
    static let diaryEntryCanonicalIdResolved = Notification.Name("diaryEntryCanonicalIdResolved")
}

// MARK: - Utilities
struct ConditionalMatchedGeometry<ID: Hashable>: ViewModifier {
    let enabled: Bool
    let id: ID
    let namespace: Namespace.ID
    func body(content: Content) -> some View {
        if enabled {
            content.matchedGeometryEffect(id: id, in: namespace, isSource: false)
        } else {
            content
        }
    }
}

// MARK: - Private helpers
extension EditorOverlay {
    private func dismissWithMatched() {
        // Re-enable matched geometry just before closing to allow a smooth return animation
        useMatchedGeometry = true
        onClose()
    }

    /// Precompute the `DiaryEntry` passed into BigEntryBlock to reduce type-checking complexity.
    private func overlayEntry() -> DiaryEntry {
        DiaryEntry(
            id: canonicalEntryId,
            date: entry.date,
            blocks: blocks,
            totalCalories: liveTotalCalories ?? entry.totalCalories,
            lastModified: entry.lastModified,
            aiGeneratedSummary: entry.aiGeneratedSummary
        )
    }

}

// MARK: - Image hydration
extension EditorOverlay {
    private func hydrateImagesForOverlay() {
        for block in blocks {
            switch block.type {
            case .imageText(_, let ref, _):
                if imageMap[ref] != nil { continue }
                if let url = block.imageUrl, !url.isEmpty {
                    if let cached = ImageCache.shared.imageIfCached(for: url) {
                        imageMap[ref] = cached
                    } else {
                        Task.detached { @MainActor in
                            if let fetched = await ImageCache.shared.fetch(url) {
                                imageMap[ref] = fetched
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
}

// MARK: - Autosave helpers
extension EditorOverlay {
    @MainActor
    private func canonicalizeEntryIfNeeded(row: DiaryAPI.Row, blocks: [Block]) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == canonicalEntryId { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: canonicalEntryId, serverId: serverUUID, blocks: blocks)
        canonicalEntryId = serverUUID
    }
    
    private func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        // Only autosave on explicit paragraph commit or when editing a previously saved paragraph.
        // Routine text changes are ignored; notifications will trigger scheduleAutosave(blocks:).
        if suppressRemoteBlockUpdates { return }

        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent {
            print("⏭️ Autosave skipped (text unchanged)")
            return
        }
        // Do not autosave on every keystroke anymore. Wait for paragraph-level notifications.
    }

    private func scheduleAutosave(blocks: [Block]) {
        debounceWorkItem?.cancel()
        autosaveTask?.cancel() // Cancel any existing autosave to prevent overlap
        print("🕐 Autosave scheduled in 1s…")
        let workItem = DispatchWorkItem {
            print("💾 Autosave firing…")
            autosaveTask = Task { await save(blocks: blocks) }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func flushSave() {
        if let work = debounceWorkItem {
            work.cancel()
            debounceWorkItem = nil
        }
        autosaveTask?.cancel() // Cancel any existing autosave before flush
        print("🔚 Flushing autosave on close…")
        // Do immediate save without AI analysis to prevent contamination
        Task { await saveWithoutAIAnalysis(blocks: blocks) }
    }

    private func save(blocks: [Block]) async {
        // Check if task was cancelled before starting save
        if Task.isCancelled {
            print("🐛 DEBUG: Save task cancelled for entry.id=\(canonicalEntryId.uuidString)")
            return
        }
        
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = [
            "write what you ate today",
            "write what you ate this day"
        ]
        if trimmed.isEmpty || placeholders.contains(trimmed) {
            print("⏭️ Autosave skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        print("🐛 DEBUG: entry.id=\(canonicalEntryId.uuidString), entry.date=\(entry.date), computed day=\(day)")
        do {
            // Ensure we have a valid authenticated session for writes (RLS requires it)
            guard let _ = try? KeychainManager.shared.loadTokens() else {
                print("⚠️ Missing auth session; autosave deferred until user signs in")
                return
            }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                print("⬆️ Upserting content for day \(day)… (overlay)")
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                print("🐛 DEBUG: Autosave result - local_id=\(canonicalEntryId.uuidString), db_id=\(row.id), db_date=\(row.date)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                // Save blocks cache after successful upsert
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                
                // Check if task was cancelled before starting AI analysis
                if Task.isCancelled {
                    print("🐛 DEBUG: Save task cancelled before AI analysis for entry.id=\(canonicalEntryId.uuidString)")
                    return
                }
                
                // Trigger AI analysis after successful upsert (incremental when possible)
                let payload = blocks.toAnalyzeBlocks()
                let isContentEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                autosaveTask = Task {
                    do {
                        if isContentEmpty {
                            // Content is empty - clear all nutrition data and totals
                            try await DiaryAPI.clearEntryNutrition(entryId: row.id)

                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .diaryEntryTotalsUpdated,
                                    object: nil,
                                    userInfo: [
                                        "entryId": canonicalEntryId,
                                        "totalCalories": 0
                                    ]
                                )
                                self.liveTotalCalories = 0
                            }
                        } else {
                            // Content exists - run normal analysis
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
                                        print("🤖 Incremental analyze triggered for entry \(row.id) with \(blocksNeedingAnalysis.count) blocks")
                                    } else {
                                        print("⏭️ No blocks need analysis for entry \(row.id)")
                                    }
                                } else {
                                    // No existing analysis or no actual nutrition data, use full analysis
                                    _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                                    print("🤖 Full analyze triggered for entry \(row.id) with \(payload.count) blocks")
                                }
                            } catch {
                                // Fallback to full analysis if incremental fails
                                print("⚠️ Incremental analysis failed, falling back to full analysis: \(error)")
                                _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)
                                print("🤖 Full analyze triggered for entry \(row.id) with \(payload.count) blocks")
                            }

                            // Poll for updated totals and per-block calories after analysis completes
                            // Extend window to tolerate slower analysis completion
                            var hasReceivedNutritionData = false
                            let delays: [Double] = [0.8, 1.2, 2.0, 2.8, 4.0, 5.5, 7.5, 10.0, 13.0, 16.0]
                            for delay in delays {
                                if hasReceivedNutritionData {
                                    break
                                }

                                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                
                                // Check if task was cancelled before making database calls
                                if Task.isCancelled {
                                    print("🐛 DEBUG: Autosave polling cancelled for entry \(row.id)")
                                    return
                                }
                                
                                let refreshed = try? await DiaryAPI.getById(row.id)
                                let dbBlocks = try? await DiaryAPI.getBlocksById(row.id)
                                print("🐛 DEBUG: Polling call getBlocksById(\(row.id)) returned \(dbBlocks?.count ?? 0) blocks: \(dbBlocks?.map { $0.content ?? "nil" } ?? [])")

                                await MainActor.run {
                                    if let refreshed {
                                        NotificationCenter.default.post(
                                            name: .diaryEntryTotalsUpdated,
                                            object: nil,
                                            userInfo: [
                                                "entryId": canonicalEntryId,
                                                "totalCalories": refreshed.total_calories as Any
                                            ]
                                        )
                                        self.liveTotalCalories = refreshed.total_calories ?? self.liveTotalCalories
                                    }

                                    if let dbBlocks {
                                        // Check if we now have actual nutrition data
                                        let nowHasNutritionData = dbBlocks.contains { block in
                                            (block.calories ?? 0) > 0 ||
                                            (block.protein ?? 0) > 0 ||
                                            (block.fat ?? 0) > 0 ||
                                            (block.carbs ?? 0) > 0
                                        }

                                        if nowHasNutritionData {
                                            hasReceivedNutritionData = true
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
                                        }
                                    }
                                }
                            }


                        }
                    }
                }
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .diaryEntryTotalsUpdated,
                        object: nil,
                        userInfo: [
                            "entryId": canonicalEntryId,
                            "totalCalories": row.total_calories as Any
                        ]
                    )
                }
            } else {
                print("⚠️ Missing user id; deferring insert until available")
                return
            }
            lastSavedAt = Date()
            lastSavedContent = trimmed
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            print("❌ Autosave error: \(error)")
        }
    }
    
    /// Save content to database without triggering AI analysis (used during overlay dismissal)
    private func saveWithoutAIAnalysis(blocks: [Block]) async {
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = [
            "write what you ate today",
            "write what you ate this day"
        ]
        if trimmed.isEmpty || placeholders.contains(trimmed) {
            print("⏭️ Flush save skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        
        do {
            guard let _ = try? KeychainManager.shared.loadTokens() else {
                print("⚠️ Missing auth session; flush save deferred")
                return
            }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                print("⬆️ Flush saving content for day \(day)… (overlay)")
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                print("🐛 DEBUG: Flush save result - local_id=\(canonicalEntryId.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                
                lastSavedAt = Date()
                lastSavedContent = trimmed
                print("✅ Flush save success (no AI analysis)")
                // Save blocks cache on flush as well
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
            } else {
                print("⚠️ Missing user id; deferring flush save")
            }
        } catch {
            print("❌ Flush save error: \(error)")
        }
    }
}



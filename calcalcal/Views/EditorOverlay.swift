import SwiftUI
import UIKit
import os.log

private let logger = Logger(subsystem: "com.calcalcal.app", category: "EditorOverlay")

struct EditorOverlay: View {
    @Binding var entry: DiaryEntry
    @Binding var shouldBecomeFirstResponder: Bool
    let namespace: Namespace.ID
    let onClose: (DiaryEntry) -> Void  // Now passes the final entry back
    
    // Local mutable copy to prevent binding updates from re-triggering the fullScreenCover
    @State private var localEntry: DiaryEntry
    
    // Computed property for blocks (cleaner access)
    private var blocks: Binding<[Block]> {
        Binding(
            get: { localEntry.blocks },
            set: { localEntry.blocks = $0 }
        )
    }

    @State private var showImagePicker: Bool = false
    @State private var pickedImage: UIImage? = nil
    @GestureState private var dragOffset: CGSize = .zero
    @State private var hasDismissedKeyboardForDrag: Bool = false
    @State private var isClosing: Bool = false  // Prevent autosaves during close
    @State private var hasCalledOnClose: Bool = false  // Prevent double-calling onClose
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var lastSavedAt: Date? = nil
    @State private var lastSavedContent: String? = nil
    @State private var liveTotalCalories: Int? = nil
    @State private var suppressRemoteBlockUpdates: Bool = false
    @State private var pendingRemoteBlocks: [Block]? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var autosaveTask: Task<Void, Error>? = nil
    @State private var imageMap: [UUID: UIImage] = [:]
    @State private var keyboardHeight: CGFloat = 0
    
    @Environment(\.dismiss) private var dismiss

    init(entry: Binding<DiaryEntry>,
         shouldBecomeFirstResponder: Binding<Bool>,
         namespace: Namespace.ID,
         onClose: @escaping (DiaryEntry) -> Void) {
        self._entry = entry
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.namespace = namespace
        self.onClose = onClose
        // Initialize local copy with the entry value
        self._localEntry = State(initialValue: entry.wrappedValue)
    }

    var body: some View {
        // Transparent container with padding - this creates space but doesn't zoom
        Color.clear
            .overlay(
                // The actual card - this is what zooms
                cardContent
                    .padding(.horizontal, 12)
                    .padding(.top, 2)
                    .padding(.bottom, max(keyboardHeight, -8))
            )
            .ignoresSafeArea(.keyboard)
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    
    private var cardContent: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle at the top
                dragHandle
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                DiaryEditorCard(
                    entry: localEntry,
                    height: nil, // Let it fill available space
                    cornerRadius: 24,
                    showShadow: false,
                    useExternalDecoration: true,
                    onAddImage: { showImagePicker = true },
                    imageMap: imageMap,
                    isEditable: true,
                    shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                    forceExpanded: true, // Expand to fill
                    onBlocksChange: { updated in
                        localEntry.blocks = updated
                        BlocksCache.shared.save(entryId: localEntry.id, blocks: updated)
                        scheduleAutosaveIfTextChanged(blocks: updated)
                    },
                    overrideTotalCalories: liveTotalCalories,
                    externalBlocks: blocks
                )
                .onChange(of: localEntry.blocks) { newValue in
                    let updatedBlocks = newValue.map { block in
                        if block.stableId == nil {
                            return block.withUpdatedChangeTracking()
                        }
                        return block
                    }
                    if updatedBlocks != newValue {
                        localEntry.blocks = updatedBlocks
                    }
                    BlocksCache.shared.save(entryId: localEntry.id, blocks: updatedBlocks)
                    scheduleAutosaveIfTextChanged(blocks: updatedBlocks)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(alignment: .topTrailing) {
            Button(action: { dismissEditor() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .offset(y: max(0, dragOffset.height))
        .fullScreenCover(isPresented: $showImagePicker) {
            UnifiedMediaPickerView(
                onImageSelected: { image in
                    showImagePicker = false
                    handleImageSelected(image)
                },
                onDismiss: {
                    showImagePicker = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) {
                    keyboardHeight = keyboardFrame.height
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) {
                keyboardHeight = 0
            }
        }
        .onAppear {
            liveTotalCalories = localEntry.totalCalories
            
            // Auto-focus the editor after a short delay to let the transition complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shouldBecomeFirstResponder = true
            }
            
            // Fetch existing per-block calories for this entry (if already analyzed)
            loadTask = Task {
                do {
                    logger.debug("Loading blocks for localEntry.id=\(self.localEntry.id.uuidString)")
                    let dbBlocks = try await DiaryAPI.getBlocksById(localEntry.id.uuidString)
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
                                "entryId": localEntry.id.uuidString,
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
            localEntry.blocks = localEntry.blocks.withStableIdsAndChangeTracking()

            // Initialize lastSavedContent to current textual content to avoid initial autosave loop
            let initial = localEntry.blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
            lastSavedContent = initial
            // Initial hydration pass
            hydrateImagesForOverlay()
        }
        .onDisappear {
            print("🟣 onDisappear START")
            let finalEntryId = localEntry.id
            let finalBlocks = localEntry.blocks
            
            DataFlowLogger.shared.editorDisappearing(
                entryId: finalEntryId, 
                blockCount: finalBlocks.count, 
                contentPreview: DataFlowLogger.preview(from: finalBlocks)
            )
            
            // Cancel any pending async tasks to prevent contamination with new overlays
            loadTask?.cancel()
            loadTask = nil
            autosaveTask?.cancel()
            logger.debug("EditorOverlay dismissed, cancelled autosaveTask for localEntry.id=\(self.localEntry.id.uuidString)")
            autosaveTask = nil

            // CRITICAL: Save to cache SYNCHRONOUSLY before view disappears
            BlocksCache.shared.saveSync(entryId: finalEntryId, blocks: finalBlocks)
            DataFlowLogger.shared.editorCacheSyncComplete(entryId: finalEntryId)
            
            flushSave()
            
            // Apply any queued remote updates only after editor closes
            if let pending = pendingRemoteBlocks {
                localEntry.blocks = pending
                pendingRemoteBlocks = nil
            }
            suppressRemoteBlockUpdates = false
            
            // CRITICAL: Call onClose to pass data back, in case dismissEditor() wasn't called
            // This happens when SwiftUI auto-dismisses (e.g., swipe gesture)
            if !hasCalledOnClose {
                print("🟣 onDisappear calling onClose to sync data (dismissEditor was NOT called)")
                hasCalledOnClose = true
                onClose(localEntry)
            } else {
                print("🟣 onDisappear skipping onClose (already called from dismissEditor)")
            }
            
            DataFlowLogger.shared.editorDisappeared(entryId: finalEntryId)
            print("🟣 onDisappear END")
        }
        // Listen for paragraph-level commit/edit notifications to control autosave
        .onReceive(NotificationCenter.default.publisher(for: .editorParagraphCommitted)) { _ in
            guard !isClosing else { return }
            logger.debug("Paragraph committed -> schedule autosave")
            scheduleAutosave(blocks: localEntry.blocks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorSavedParagraphEdited)) { _ in
            guard !isClosing else { return }
            logger.debug("Saved paragraph edited -> schedule autosave")
            scheduleAutosave(blocks: localEntry.blocks)
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
    // Editor-internal notifications (not for cross-component sync)
    static let editorParagraphCommitted = Notification.Name("editorParagraphCommitted")
    static let editorSavedParagraphEdited = Notification.Name("editorSavedParagraphEdited")
    
    // AI analysis results from backend (async, needs notifications)
    static let editorApplyPerBlockMetadata = Notification.Name("editorApplyPerBlockMetadata")
    
    // Global app-level events
    static let diaryEntryCanonicalIdResolved = Notification.Name("diaryEntryCanonicalIdResolved")
    static let streaksDataUpdated = Notification.Name("streaksDataUpdated")
}

// MARK: - Utilities
struct ConditionalMatchedGeometry<ID: Hashable>: ViewModifier {
    let enabled: Bool
    let id: ID
    let namespace: Namespace.ID
    let isSource: Bool
    let anchor: UnitPoint

    init(
        enabled: Bool,
        id: ID,
        namespace: Namespace.ID,
        isSource: Bool = true,
        anchor: UnitPoint = .top  // Use .top anchor by default for proper animation alignment
    ) {
        self.enabled = enabled
        self.id = id
        self.namespace = namespace
        self.isSource = isSource
        self.anchor = anchor
    }

    func body(content: Content) -> some View {
        if enabled {
            content.matchedGeometryEffect(id: id, in: namespace, anchor: anchor, isSource: isSource)
        } else {
            content
        }
    }
}

// MARK: - Private helpers
extension EditorOverlay {
    /// Drag handle view - a small pill that indicates the overlay can be dismissed
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 36, height: 5)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($dragOffset) { value, state, _ in
                        // Only allow downward drags
                        if value.translation.height > 0 {
                            state = value.translation
                        }
                        // Dismiss keyboard when dragging down
                        if value.translation.height > 8 && !hasDismissedKeyboardForDrag {
                            shouldBecomeFirstResponder = false
                            hasDismissedKeyboardForDrag = true
                        }
                    }
                    .onEnded { value in
                        // Check if drag was far enough or fast enough to dismiss
                        let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                        if shouldDismiss {
                            dismissEditor()
                        } else {
                            // Restore keyboard if we dismissed it but didn't close
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
    
    private func dismissEditor() {
        print("🔵 dismissEditor() called")
        
        // Set flag to prevent any autosaves during close
        isClosing = true
        
        // Cancel any pending autosaves
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        autosaveTask?.cancel()
        autosaveTask = nil
        
        // iOS 18+ handles the zoom-out animation automatically via navigationTransition
        // Pass the final entry data to parent via callback
        if !hasCalledOnClose {
            print("🔵 dismissEditor() calling onClose with localEntry")
            hasCalledOnClose = true
            onClose(localEntry)
            print("🔵 dismissEditor() onClose completed")
        } else {
            print("🔵 dismissEditor() skipping onClose (already called)")
        }
    }


}

// MARK: - Image hydration
extension EditorOverlay {
    private func hydrateImagesForOverlay() {
        for block in localEntry.blocks {
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
                    if let cached = ImageCache.shared.localImage(ref: ref, legacyEntryId: localEntry.id) {
                        imageMap[ref] = cached
                    }
                }
            default:
                continue
            }
        }
    }
    
    private func handleImageSelected(_ image: UIImage) {
        let uuid = UUID()
        // Downscale for local display and future upload
        let compressed = ImageCompression.compressForUpload(image, maxDimension: 720, quality: 0.7)
        // Use resized image in the UI
        imageMap[uuid] = compressed.resizedImage
        // Store in local image cache under deterministic key for fallback before URL is known
        ImageCache.shared.storeLocal(compressed.resizedImage, ref: uuid)
        // Store PNG data of resized image in the model for stable internal rendering
        if let resizedPNG = compressed.resizedImage.pngData() {
            let newBlock = Block(type: .imageText(resizedPNG, uuid, ""), calorieData: nil, nutrition: nil)
            localEntry.blocks.append(newBlock)

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
                        if let idx = localEntry.blocks.firstIndex(where: { block in
                            if case let .imageText(_, ref, _) = block.type { return ref == capturedUUID }
                            return false
                        }) {
                            var updated = localEntry.blocks[idx]
                            updated.imageUrl = upload.publicUrl
                            updated.imageObjectKey = upload.objectKey
                            localEntry.blocks[idx] = updated
                            // Persist blocks cache immediately
                            BlocksCache.shared.save(entryId: localEntry.id, blocks: localEntry.blocks)
                        }
                    }
                    let analysis = try await ImageAPI.analyzeImageLegacy(imageUrl: upload.publicUrl, entryId: entryIdString, blockId: blockId.uuidString)

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
                        weight: analysis.macros?.weight,
                        metric_description: analysis.macros?.metric_description,
                        confidence: analysis.confidence
                    )

                    // Apply to the inserted block (by imageRef match)
                    await MainActor.run {
                        if let idx = localEntry.blocks.firstIndex(where: { block in
                            if case let .imageText(_, ref, _) = block.type {
                                return ref == capturedUUID
                            }
                            return false
                        }) {
                            var updated = localEntry.blocks[idx]
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
                            localEntry.blocks[idx] = updated
                            BlocksCache.shared.save(entryId: localEntry.id, blocks: localEntry.blocks)
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
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            shouldBecomeFirstResponder = true
        }
    }
}

// MARK: - Autosave helpers
extension EditorOverlay {
    @MainActor
    private func canonicalizeEntryIfNeeded(row: DiaryAPI.Row, blocks: [Block]) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == localEntry.id { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: localEntry.id, serverId: serverUUID, blocks: blocks)
        localEntry.id = serverUUID
    }

    private func scheduleAutosaveIfTextChanged(blocks: [Block]) {
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

    private func scheduleAutosave(blocks: [Block]) {
        // Don't schedule autosaves if we're closing
        if isClosing {
            logger.debug("Autosave skipped (editor closing)")
            return
        }
        
        debounceWorkItem?.cancel()
        autosaveTask?.cancel() // Cancel any existing autosave to prevent overlap
        logger.debug("Autosave scheduled in 1s…")
        let workItem = DispatchWorkItem {
            logger.debug("Autosave firing…")
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
        logger.debug("Flushing autosave on close…")
        // Do immediate save without AI analysis to prevent contamination
        Task { await saveWithoutAIAnalysis(blocks: localEntry.blocks) }
    }

    private func save(blocks: [Block]) async {
        // Check if task was cancelled before starting save
        if Task.isCancelled {
            logger.debug("Save task cancelled for localEntry.id=\(self.localEntry.id.uuidString)")
            return
        }

        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let placeholders: Set<String> = [
            "write what you ate today",
            "write what you ate this day"
        ]
        if trimmed.isEmpty || placeholders.contains(trimmed) {
            logger.debug("Autosave skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: localEntry.date, offsetMinutes: offsetMinutes)
        logger.debug("Autosave: localEntry.id=\(self.localEntry.id.uuidString), computed day=\(day)")
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
                logger.debug("Autosave result - local_id=\(self.localEntry.id.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                // Save blocks cache after successful upsert
                BlocksCache.shared.save(entryId: localEntry.id, blocks: blocks)

                // Check if task was cancelled before starting AI analysis
                if Task.isCancelled {
                    logger.debug("Save task cancelled before AI analysis for localEntry.id=\(self.localEntry.id.uuidString)")
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
                                localEntry.totalCalories = 0
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
                                    logger.debug("Autosave polling cancelled for entry \(row.id)")
                                    return
                                }

                                let refreshed = try? await DiaryAPI.getById(row.id)
                                let dbBlocks = try? await DiaryAPI.getBlocksById(row.id)
                                logger.debug("Polling call getBlocksById(\(row.id)) returned \(dbBlocks?.count ?? 0) blocks")

                    await MainActor.run {
                        if let refreshed {
                            localEntry.totalCalories = refreshed.total_calories
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
                                                    "weight": ((block.weight ?? 0) > 0 ? block.weight! : NSNull()),
                                                    "metric_description": (block.metric_description as Any?) ?? NSNull(),
                                                    "confidence": (block.confidence as Any?) ?? NSNull()
                                                ]
                                            }
                                            NotificationCenter.default.post(
                                                name: .editorApplyPerBlockMetadata,
                                                object: nil,
                                                userInfo: [
                                                    "entryId": localEntry.id.uuidString,
                                                    "analyzedBlocks": payload
                                                ]
                                            )
                                            
                                            // Refresh streaks now that we have nutrition data (analysis complete)
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
                                                    print("🔥 Streaks refreshed after analysis completion")
                                                } catch {
                                                    print("⚠️ Failed to refresh streaks after analysis: \(error)")
                                                }
                                            }
                                        }
                                    }
                                }
                            }


                        }
                    }
                }
                await MainActor.run {
                    localEntry.totalCalories = row.total_calories
                }
            } else {
                logger.warning("Missing user id; deferring insert until available")
                return
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
                    logger.warning("Failed to refresh streaks after autosave: \(error.localizedDescription)")
                }
            }
            
            logger.info("Autosave success")
        } catch {
            logger.error("Autosave error: \(error.localizedDescription)")
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
            logger.debug("Flush save skipped (empty/placeholder content)")
            return
        }
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: localEntry.date, offsetMinutes: offsetMinutes)

        do {
            guard let _ = try? KeychainManager.shared.loadTokens() else {
                logger.warning("Missing auth session; flush save deferred")
                return
            }
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                logger.debug("Flush saving content for day \(day)…")
                let blocksPayload = blocks.toAnalyzeBlocks()
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content, blocks: blocksPayload)
                logger.debug("Flush save result - local_id=\(self.localEntry.id.uuidString), db_id=\(row.id)")
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }

                lastSavedAt = Date()
                lastSavedContent = trimmed
                logger.info("Flush save success (no AI analysis)")
                // Save blocks cache on flush as well
                BlocksCache.shared.save(entryId: localEntry.id, blocks: blocks)
                
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
                        logger.warning("Failed to refresh streaks after flush save: \(error.localizedDescription)")
                    }
                }
            } else {
                logger.warning("Missing user id; deferring flush save")
            }
        } catch {
            logger.error("Flush save error: \(error.localizedDescription)")
        }
    }
}

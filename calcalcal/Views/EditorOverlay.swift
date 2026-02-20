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
    @State private var hasCalledOnClose: Bool = false  // Prevent double-calling onClose
    @State private var suppressRemoteBlockUpdates: Bool = false
    @State private var pendingRemoteBlocks: [Block]? = nil
    @State private var imageMap: [UUID: UIImage] = [:]
    @State private var keyboardHeight: CGFloat = 0
    @State private var headerScrollOffsetY: CGFloat = 0  // Drives progressive blur (0 = none, ~60+ = full)
    @State private var pendingAnimationSourceRect: CGRect? = nil
    @State private var pendingAnimationImage: UIImage? = nil

    // Autosave service handles all save/load operations
    @StateObject private var autosaveService: EditorAutosaveService
    
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
        // Initialize autosave service
        self._autosaveService = StateObject(wrappedValue: EditorAutosaveService(
            entryId: entry.wrappedValue.id,
            entryDate: entry.wrappedValue.date,
            initialCalories: entry.wrappedValue.totalCalories
        ))
    }

    var body: some View {
        // Transparent container with padding - this creates space but doesn't zoom
        Color.clear
            .overlay(
                // The actual card - this is what zooms
                cardContent
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DSColors.backgroundSecondary)
                    .ignoresSafeArea(.all)
            )
            .animation(.easeOut(duration: 0.25), value: keyboardHeight)
    }
    
    private var cardContent: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top
            
            VStack(spacing: 0) {
                // Editor with sticky header overlaid on top (content scrolls under)
                ZStack(alignment: .top) {
                    EntryCard(
                        entry: localEntry,
                        height: nil, // Let it fill available space
                        cornerRadius: 0,
                        showShadow: false,
                        useExternalDecoration: true,
                        onAddImage: { showImagePicker = true },
                        imageMap: imageMap,
                        isEditable: true,
                        shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                        forceExpanded: true, // Expand to fill
                        onBlocksChange: { updated in
                            // Add stable IDs if needed, then update localEntry in one go
                            // This prevents the circular update that causes cursor jumping
                            let blocksWithStableIds = updated.map { block in
                                if block.stableId == nil {
                                    return block.withUpdatedChangeTracking()
                                }
                                return block
                            }
                            localEntry.blocks = blocksWithStableIds
                            BlocksCache.shared.save(entryId: localEntry.id, blocks: blocksWithStableIds)
                            autosaveService.scheduleAutosaveIfTextChanged(blocks: blocksWithStableIds)
                        },
                        overrideTotalCalories: autosaveService.liveTotalCalories,
                        onScrollOffsetChange: { offsetY in
                            // Update header blur based on scroll position
                            headerScrollOffsetY = max(0, offsetY)
                        },
                        topContentInset: 56, // Extra space for the sticky header
                        bottomContentInset: 80, // Extra space for the sticky footer
                        onNewImageOverlayPositioned: { blockID, destRect in
                            guard pendingAnimationSourceRect != nil else { return }
                            startFlyToAnimation(destinationRect: destRect, blockID: blockID)
                        },
                        pendingFlyToAnimation: pendingAnimationSourceRect != nil,
                        externalBlocks: blocks
                    )
                    // Note: No onChange handler here - all block updates now happen in onBlocksChange callback
                    // This eliminates the circular update that was causing cursor jumping

                    // Variable blur background - covers safe area + header, ignores safe area to extend to screen edge
                    headerBlurBackground(safeAreaTop: safeAreaTop)
                    
                    // Sticky header content (date + close) – positioned with safe area padding
                    stickyHeaderContent(safeAreaTop: safeAreaTop)

                    // Variable blur background for footer – inverted direction from header
                    footerBlurBackground(safeAreaBottom: geometry.safeAreaInsets.bottom)

                    // Sticky footer content (gallery button + calorie number)
                    stickyFooterContent()
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }

        .fullScreenCover(isPresented: $showImagePicker) {
            UnifiedMediaPickerView(
                onImageSelected: { image, sourceRect in
                    showImagePicker = false
                    if let sourceRect = sourceRect, sourceRect != .zero {
                        pendingAnimationSourceRect = sourceRect
                        pendingAnimationImage = image
                    }
                    handleImageSelected(image)
                },
                onDismiss: {
                    showImagePicker = false
                },
                geometryNamespace: namespace
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
            headerScrollOffsetY = 0

            // Setup autosave service callbacks
            autosaveService.onEntryIdUpdated = { newId in
                localEntry.id = newId
            }
            autosaveService.onTotalCaloriesUpdated = { calories in
                localEntry.totalCalories = calories
            }

            // Auto-focus the editor after a short delay to let the transition complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                shouldBecomeFirstResponder = true
            }
            
            // Fetch existing per-block calories for this entry (if already analyzed)
            autosaveService.loadBlocks()
            
            // Initialize blocks with stable IDs and change tracking
            localEntry.blocks = localEntry.blocks.withStableIdsAndChangeTracking()

            // Initialize lastSavedContent to current textual content to avoid initial autosave loop
            autosaveService.setInitialContent(blocks: localEntry.blocks)
            
            // Note: Image hydration is handled by EntryCard internally
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
            
            // CRITICAL: Set isClosing to prevent any new autosaves during dismissal
            autosaveService.markAsClosing()
            
            // Cancel any pending async tasks to prevent contamination with new overlays
            autosaveService.cancelAll()
            logger.debug("EditorOverlay dismissed, cancelled autosave tasks for localEntry.id=\(self.localEntry.id.uuidString)")

            // CRITICAL: Save to cache SYNCHRONOUSLY before view disappears
            BlocksCache.shared.saveSync(entryId: finalEntryId, blocks: finalBlocks)
            DataFlowLogger.shared.editorCacheSyncComplete(entryId: finalEntryId)
            
            // CRITICAL: Call onClose BEFORE flushSave to ensure parent has latest data
            if !hasCalledOnClose {
                print("🟣 onDisappear calling onClose to sync data (dismissEditor was NOT called)")
                hasCalledOnClose = true
                onClose(localEntry)
                // NOTE: Streaks are refreshed AFTER save completes in EditorAutosaveService
            } else {
                print("🟣 onDisappear skipping onClose (already called from dismissEditor)")
            }
            
            // Now flush any pending save after parent has been notified
            autosaveService.flushSave(blocks: localEntry.blocks)
            
            // Apply any queued remote updates only after editor closes
            if let pending = pendingRemoteBlocks {
                localEntry.blocks = pending
                pendingRemoteBlocks = nil
            }
            suppressRemoteBlockUpdates = false
            
            DataFlowLogger.shared.editorDisappeared(entryId: finalEntryId)
            print("🟣 onDisappear END")
        }
        // Listen for paragraph-level commit/edit notifications to control autosave
        .onReceive(NotificationCenter.default.publisher(for: .editorParagraphCommitted)) { _ in
            guard !autosaveService.isClosing else { return }
            logger.debug("Paragraph committed -> schedule autosave")
            autosaveService.scheduleAutosave(blocks: localEntry.blocks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorSavedParagraphEdited)) { _ in
            guard !autosaveService.isClosing else { return }
            logger.debug("Saved paragraph edited -> schedule autosave")
            autosaveService.scheduleAutosave(blocks: localEntry.blocks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorScrollOffsetDidChange)) { notification in
            guard let userInfo = notification.userInfo,
                  let offsetY = userInfo["offsetY"] as? CGFloat else { return }
            let notifiedId: UUID? = (userInfo["entryId"] as? UUID) ?? (userInfo["entryId"] as? String).flatMap(UUID.init(uuidString:))
            guard notifiedId == localEntry.id else { return }
            headerScrollOffsetY = max(0, offsetY)
        }
    }
}

// MARK: - Private helpers
extension EditorOverlay {
    /// Variable blur background that extends over the safe area to the screen edge.
    /// Blurs content as it scrolls underneath the header.
    private func headerBlurBackground(safeAreaTop: CGFloat) -> some View {
        let blurHeight = safeAreaTop + 48
        
        return VStack(spacing: 0) {
            // Variable blur - strongest at bottom (where content scrolls from), clear at top
            VariableBlurView(maxBlurRadius: 32, direction: .blurredTopClearBottom, startOffset: 0)
                .frame(height: blurHeight)  // Fade in as content scrolls
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .top)  // Extend blur to screen edge
    }
    
    /// Header content - date and close button, positioned below the safe area.
    private func stickyHeaderContent(safeAreaTop: CGFloat) -> some View {
        HStack {
            Text(formattedDate(localEntry.date))
                .font(.dsHeadline)
                .foregroundColor(DSColors.primary)
            Spacer(minLength: 0)
            Button(action: { dismissEditor() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DSColors.textSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)  // Position below safe area with small offset
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// Variable blur background for the footer.
    /// Uses a fixed height so it doesn't expand when the keyboard opens.
    private func footerBlurBackground(safeAreaBottom: CGFloat) -> some View {
        let blurHeight: CGFloat = 72

        return VStack(spacing: 0) {
            Spacer()
            VariableBlurView(maxBlurRadius: 32, direction: .blurredBottomClearTop, startOffset: 0)
                .frame(height: blurHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(false)
    }

    /// Footer content — gallery thumbnail button and animated calorie number.
    private func stickyFooterContent() -> some View {
        VStack(spacing: 0) {
            Spacer()
            EditorFooterView(
                blocks: localEntry.blocks,
                remoteTotalCalories: autosaveService.liveTotalCalories ?? localEntry.totalCalories,
                scrollOffset: headerScrollOffsetY,
                onAddImage: { showImagePicker = true }
            )
            .padding(.bottom, DSSpacing.xs)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: date)
    }
    
    private func dismissEditor() {
        print("🔵 dismissEditor() called")
        
        // Set flag to prevent any autosaves during close
        autosaveService.markAsClosing()
        
        // Cancel any pending autosaves
        autosaveService.cancelAll()
        
        // Pass the final entry data to parent via callback BEFORE dismissing
        // This ensures the parent view has updated data before the overlay animates away
        if !hasCalledOnClose {
            print("🔵 dismissEditor() calling onClose with localEntry")
            hasCalledOnClose = true
            onClose(localEntry)
            print("🔵 dismissEditor() onClose completed")
            // NOTE: Streaks are refreshed AFTER save completes in EditorAutosaveService
        } else {
            print("🔵 dismissEditor() skipping onClose (already called)")
        }
        
        // Now trigger the dismissal
        // The parent's handleOverlayClose sets presentedEntry = nil, which dismisses the fullScreenCover
        // But we also call dismiss() here to ensure proper dismissal in all cases
        dismiss()
    }
}

// MARK: - Image handling
extension EditorOverlay {
    /// Handles newly selected images from the image picker.
    /// Note: Existing image hydration is handled by EntryCard internally.
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
            let entryIdString = localEntry.id.uuidString // backend requires entryId for analyze-image
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

    /// Starts a window-level fly-to animation from source rect to destination rect.
    func startFlyToAnimation(destinationRect: CGRect, blockID: BlockID) {
        guard let sourceRect = pendingAnimationSourceRect,
              let image = pendingAnimationImage,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: { $0.isKeyWindow })
        else {
            // No pending animation or no window — clean up
            pendingAnimationSourceRect = nil
            pendingAnimationImage = nil
            return
        }

        // Create snapshot UIImageView at source position
        let snapshot = UIImageView(image: image)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.layer.cornerRadius = 6
        snapshot.frame = sourceRect
        window.addSubview(snapshot)

        // Clear pending state
        pendingAnimationSourceRect = nil
        pendingAnimationImage = nil

        // Animate to destination
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.82,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut]
        ) {
            snapshot.frame = destinationRect
            snapshot.layer.cornerRadius = 8
        } completion: { _ in
            snapshot.removeFromSuperview()
            // Tell the text view to reveal the real overlay
            NotificationCenter.default.post(
                name: .editorRevealImageOverlay,
                object: nil,
                userInfo: ["blockID": blockID.rawValue]
            )
        }
    }
}

// MARK: - Previews
#if DEBUG
struct EditorOverlay_Previews: PreviewProvider {
    static var previews: some View {
        let mockEntry = DiaryEntry(
            id: UUID(),
            date: Date(),
            blocks: [
                Block(type: .text("Breakfast: oatmeal with banana and honey"), calorieData: "320", nutrition: nil),
                Block(type: .text("Lunch: chicken salad and a cup of coffee"), calorieData: "450", nutrition: nil),
                Block(type: .text("Dinner: grilled salmon with vegetables"), calorieData: "520", nutrition: nil),
            ],
            totalCalories: 1290,
            lastModified: Date(),
            aiGeneratedSummary: nil
        )
        return EditorOverlayPreviewContainer(mockEntry: mockEntry)
    }
}

/// Wrapper that holds @State and @Namespace so we can pass bindings into EditorOverlay.
private struct EditorOverlayPreviewContainer: View {
    let mockEntry: DiaryEntry
    @State private var entry: DiaryEntry
    @State private var shouldBecomeFirstResponder = false
    @Namespace private var namespace

    init(mockEntry: DiaryEntry) {
        self.mockEntry = mockEntry
        self._entry = State(initialValue: mockEntry)
    }

    var body: some View {
        EditorOverlay(
            entry: $entry,
            shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
            namespace: namespace,
            onClose: { _ in }
        )
    }
}
#endif

import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var appState: AppState

    @State private var presentedEntry: DiaryEntry? = nil
    @State private var presentedBlocks: [Block] = []
    @State private var shouldFocusEditor: Bool = false
    @State private var isOverlayVisible: Bool = false
    @State private var shouldHideSourceCard: Bool = false

    // Source card frame tracking for custom animation
    @State private var sourceCardFrame: CGRect = .zero
    @State private var overlayScale: CGFloat = 1.0
    @State private var overlayOffset: CGSize = .zero

    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var anchorDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var dayEntryStates: [String: DayEntryState] = [:]
    @State private var showAllDaysSheet: Bool = false
    @State private var isLoadingRecentDays: Bool = false
    @State private var pendingEntryFromSheet: DiaryEntry? = nil

    private let overlayAnimation = Animation.easeInOut(duration: 0.35)
    private let overlayAnimationDuration: Double = 0.35
    private let stripDayCount: Int = 6
    private let calendar = Calendar.current
    private let placeholderPrompts: Set<String> = [
        "write what you ate today",
        "write what you ate this day"
    ]

    // Named coordinate space for tracking card positions
    private let rootCoordinateSpace = "rootCoordinateSpace"

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                dayFocusedDiaryTab
                    .tabItem {
                        Image(systemName: "book.fill")
                        Text("Diary")
                    }

                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("Profile")
                    }
            }

            overlayLayer
        }
        .coordinateSpace(name: rootCoordinateSpace)
        .onAppear {
            anchorDate = calendar.startOfDay(for: Date())
            clampSelectedDayIfNeeded()
            ensurePlaceholdersForVisibleDays()
            refreshVisibleEntries()
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCanonicalIdResolved)) { notification in
            guard let info = notification.userInfo,
                  let localId = info["localId"] as? UUID,
                  let serverId = info["serverId"] as? UUID else { return }
            if var current = presentedEntry, current.id == localId {
                current.id = serverId
                presentedEntry = current
            }
            replaceEntryId(localId: localId, with: serverId)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorOverlayDidCommit)) { notification in
            guard let info = notification.userInfo,
                  let entryId = info["entryId"] as? UUID,
                  let blocks = info["blocks"] as? [Block] else { return }
            updateDayEntry(entryId: entryId) { state in
                state.entry.blocks = blocks
                state.entry.lastModified = Date()
                state.isPlaceholder = isPlaceholderContent(blocks)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryTotalsUpdated)) { notification in
            guard let info = notification.userInfo,
                  let entryId = info["entryId"] as? UUID else { return }
            let value = info["totalCalories"]
            let total: Int?
            if value is NSNull {
                total = nil
            } else {
                total = value as? Int
            }
            updateDayEntry(entryId: entryId) { state in
                state.entry.totalCalories = total
            }
        }
    }
}

private extension MainTabView {
    @ViewBuilder
    var dayFocusedDiaryTab: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diary")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 24)

                    DayStripView(
                        items: dayStripItems(),
                        selectedDate: selectedDay,
                        onSelectDate: { selectDay($0, animated: true) },
                        onShowAllDays: { showAllDaysSheet = true }
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.top, 2)

                dayPager
                    .padding(.top, 12)
                    .padding(.bottom, 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .sheet(isPresented: $showAllDaysSheet, onDismiss: {
            refreshVisibleEntries()
            // If an entry was queued to open from the sheet, present it now
            if let entry = pendingEntryFromSheet {
                pendingEntryFromSheet = nil
                // Small delay to ensure sheet dismissal animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    presentOverlay(for: entry)
                }
            }
        }) {
            DiaryListView(
                sharedNamespace: nil, // Not using matched geometry anymore
                presentedEntryId: presentedEntry?.id,
                onRequestOpen: { entry in
                    // Queue the entry and dismiss sheet first - overlay will show after sheet closes
                    pendingEntryFromSheet = entry
                    showAllDaysSheet = false
                },
                isOverlayActive: shouldHideSourceCard
            )
        }
    }

    @ViewBuilder
    var dayPager: some View {
        if pagerItems.isEmpty {
            placeholderCard {
                Text("loading...")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        } else {
            DiaryPagerView(
                items: pagerItems,
                selectedDate: $selectedDay,
                calendar: calendar,
                spacing: 12,
                trailingSpace: 0
            ) { item, isActive in
                cardView(for: item.entry, isActive: isActive)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay(alignment: .topTrailing) {
                if isLoadingRecentDays {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
            }
        }
    }

    func cardView(for entry: DiaryEntry, isActive: Bool) -> some View {
        let shouldHideForOverlay = isOverlayVisible && presentedEntry?.id == entry.id

        return GeometryReader { geometry in
            VStack(spacing: 0) {
                BigEntryBlock(
                    entry: entry,
                    height: 540,
                    cornerRadius: 24,
                    showShadow: true,
                    useExternalDecoration: false,
                    onAddImage: nil,
                    onTap: isActive ? {
                        // Capture the card's frame in root coordinate space before opening
                        let frame = geometry.frame(in: .named(rootCoordinateSpace))
                        presentOverlay(for: entry, sourceFrame: frame)
                    } : nil,
                    imageMap: [:],
                    isEditable: false,
                    shouldBecomeFirstResponder: .constant(false),
                    forceExpanded: false
                )
                .padding(.horizontal, 8)
                .id(entry.id)
                .opacity(shouldHideForOverlay ? 0 : 1)
                .allowsHitTesting(isActive ? !shouldHideForOverlay : false)
                .frame(height: 500, alignment: .top)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Update source frame when the active card's geometry changes
            .onChange(of: geometry.frame(in: .named(rootCoordinateSpace))) { newFrame in
                if isActive && presentedEntry?.id == entry.id {
                    sourceCardFrame = newFrame
                }
            }
            .onAppear {
                // Capture initial frame for active card
                if isActive && presentedEntry?.id == entry.id {
                    sourceCardFrame = geometry.frame(in: .named(rootCoordinateSpace))
                }
            }
        }
    }

    func placeholderCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 32, style: .continuous)
            .fill(Color(.systemBackground))
            .frame(height: 540)
            .overlay(content())
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
    }

    func presentOverlay(for entry: DiaryEntry, sourceFrame: CGRect? = nil) {
        shouldFocusEditor = false
        shouldHideSourceCard = true
        presentedBlocks = entry.blocks

        // Store the source frame for animation
        if let frame = sourceFrame {
            sourceCardFrame = frame
        }

        // Show overlay immediately - the overlay handles its own animation
        presentedEntry = entry
        isOverlayVisible = true
        // Note: shouldFocusEditor is set by EditorOverlaySimple after morph animation completes
    }

    func dayStripItems() -> [DayStripItemModel] {
        visibleDates.reversed().map { date in
            let key = dayKey(for: date)
            let state = dayEntryStates[key]
            return DayStripItemModel(
                id: key,
                date: date,
                calories: state?.entry.totalCalories,
                hasEntry: !(state?.isPlaceholder ?? true)
            )
        }
    }

    var pagerItems: [DiaryPagerItem] {
        visibleDates
            .reversed()
            .compactMap { date in
            guard let state = state(for: date) else { return nil }
            return DiaryPagerItem(
                id: dayKey(for: date),
                date: date,
                entry: state.entry
            )
        }
    }

    func selectDay(_ date: Date, animated: Bool) {
        let normalized = calendar.startOfDay(for: date)
        guard isDateVisible(normalized) else { return }
        guard normalized != selectedDay else { return }
        selectedDay = normalized
    }

    func state(for date: Date) -> DayEntryState? {
        dayEntryStates[dayKey(for: date)]
    }

    func isDateVisible(_ date: Date) -> Bool {
        visibleDates.contains { calendar.isDate($0, inSameDayAs: date) }
    }

    func ensurePlaceholdersForVisibleDays() {
        var updated = dayEntryStates
        for date in visibleDates {
            let key = dayKey(for: date)
            if updated[key] == nil {
                updated[key] = DayEntryState(entry: placeholderEntry(for: date), isPlaceholder: true)
            }
        }
        dayEntryStates = updated
    }

    func refreshVisibleEntries() {
        anchorDate = calendar.startOfDay(for: Date())
        clampSelectedDayIfNeeded()
        ensurePlaceholdersForVisibleDays()
        if isLoadingRecentDays { return }
        isLoadingRecentDays = true
        let dates = visibleDates
        let offset = effectiveOffsetMinutes()
        let oldest = dates.last ?? anchorDate
        let newest = dates.first ?? anchorDate
        Task {
            do {
                let rows = try await DiaryAPI.listEntries(
                    dateFrom: LocalDayMath.yyyymmdd(for: oldest, offsetMinutes: offset),
                    dateTo: LocalDayMath.yyyymmdd(for: newest, offsetMinutes: offset)
                )
                let mapped = rows.map { $0.toDiaryEntry() }
                await MainActor.run {
                    apply(entries: mapped)
                    isLoadingRecentDays = false
                }
            } catch {
                await MainActor.run {
                    isLoadingRecentDays = false
                }
            }
        }
    }

    func apply(entries: [DiaryEntry]) {
        var updated = dayEntryStates
        let offset = effectiveOffsetMinutes()
        for date in visibleDates {
            let key = dayKey(for: date)
            if updated[key] == nil {
                updated[key] = DayEntryState(entry: placeholderEntry(for: date), isPlaceholder: true)
            }
        }
        for entry in entries {
            let key = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offset)
            if updated[key] != nil {
                updated[key] = DayEntryState(entry: entry, isPlaceholder: isPlaceholderContent(entry.blocks))
            }
        }
        dayEntryStates = updated
    }

    func clampSelectedDayIfNeeded() {
        guard !isDateVisible(selectedDay), let fallback = visibleDates.first else { return }
        selectedDay = fallback
    }

    var visibleDates: [Date] {
        (0..<stripDayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: anchorDate)
        }
    }

    func dayKey(for date: Date) -> String {
        LocalDayMath.yyyymmdd(for: date, offsetMinutes: effectiveOffsetMinutes())
    }

    func effectiveOffsetMinutes() -> Int {
        TimeZone.current.secondsFromGMT() / 60
    }

    func placeholderPrompt(isToday: Bool) -> String {
        isToday ? "write what you ate today" : "write what you ate this day"
    }

    func placeholderEntry(for date: Date) -> DiaryEntry {
        DiaryEntry(
            id: UUID(),
            date: date,
            blocks: [
                Block(
                    type: .text(placeholderPrompt(isToday: calendar.isDateInToday(date))),
                    calorieData: nil
                )
            ],
            totalCalories: nil,
            lastModified: date,
            aiGeneratedSummary: nil
        )
    }

    func updateDayEntry(entryId: UUID, update: (inout DayEntryState) -> Void) {
        for key in dayEntryStates.keys {
            guard var state = dayEntryStates[key], state.entry.id == entryId else { continue }
            update(&state)
            dayEntryStates[key] = state
            break
        }
    }

    func replaceEntryId(localId: UUID, with serverId: UUID) {
        for key in dayEntryStates.keys {
            guard var state = dayEntryStates[key], state.entry.id == localId else { continue }
            state.entry.id = serverId
            dayEntryStates[key] = state
        }
    }

    func isPlaceholderContent(_ blocks: [Block]) -> Bool {
        let trimmed = blocks.toContentString()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return placeholderPrompts.contains(trimmed)
    }

    @ViewBuilder
    var overlayLayer: some View {
        if let entry = presentedEntry, isOverlayVisible {
            EditorOverlaySimple(
                entry: entry,
                blocks: $presentedBlocks,
                shouldBecomeFirstResponder: $shouldFocusEditor,
                sourceFrame: sourceCardFrame,
                onClose: {
                    // Show source card again (overlay animates back to it)
                    shouldHideSourceCard = false
                    shouldFocusEditor = false

                    // Update entry data
                    updateDayEntry(entryId: entry.id) { state in
                        state.entry.blocks = presentedBlocks
                        state.entry.lastModified = Date()
                        state.isPlaceholder = isPlaceholderContent(presentedBlocks)
                    }
                    NotificationCenter.default.post(
                        name: .editorOverlayDidCommit,
                        object: nil,
                        userInfo: [
                            "entryId": entry.id,
                            "blocks": presentedBlocks
                        ]
                    )

                    // Remove overlay from view hierarchy after morph animation
                    isOverlayVisible = false
                    presentedEntry = nil
                }
            )
            .zIndex(100)
        }
    }

    struct DayEntryState {
        var entry: DiaryEntry
        var isPlaceholder: Bool
    }
}

// MARK: - Editor Overlay with custom morphing animation
struct EditorOverlaySimple: View {
    let entry: DiaryEntry
    @Binding var blocks: [Block]
    @Binding var shouldBecomeFirstResponder: Bool
    let sourceFrame: CGRect
    let onClose: () -> Void

    @State private var canonicalEntryId: UUID
    @State private var showImagePicker: Bool = false
    @State private var pickedImage: UIImage? = nil
    @GestureState private var dragOffset: CGSize = .zero
    @State private var hasDismissedKeyboardForDrag: Bool = false
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var lastSavedAt: Date? = nil
    @State private var lastSavedContent: String? = nil
    @State private var liveTotalCalories: Int? = nil
    @State private var suppressRemoteBlockUpdates: Bool = false
    @State private var pendingRemoteBlocks: [Block]? = nil
    @State private var loadTask: Task<Void, Never>? = nil
    @State private var autosaveTask: Task<Void, Error>? = nil
    @State private var imageMap: [UUID: UIImage] = [:]
    @State private var dimmingProgress: Double = 0

    // Morphing animation state: 0 = at source card, 1 = expanded to full screen
    @State private var morphProgress: CGFloat = 0
    @State private var isClosing: Bool = false

    private let morphDuration: Double = 0.35

    init(entry: DiaryEntry,
         blocks: Binding<[Block]>,
         shouldBecomeFirstResponder: Binding<Bool>,
         sourceFrame: CGRect,
         onClose: @escaping () -> Void) {
        self.entry = entry
        self._blocks = blocks
        self._shouldBecomeFirstResponder = shouldBecomeFirstResponder
        self.sourceFrame = sourceFrame
        self.onClose = onClose
        _canonicalEntryId = State(initialValue: entry.id)
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            let safeSource = validSourceFrame(screenSize: screenSize)

            // Target frame: full width with padding, full height
            let targetFrame = CGRect(
                x: 8,
                y: 0,
                width: screenSize.width - 16,
                height: screenSize.height
            )

            // Interpolated values based on morphProgress
            let currentFrame = interpolateFrame(from: safeSource, to: targetFrame, progress: morphProgress)
            let currentCornerRadius = interpolate(from: 24, to: 24, progress: morphProgress)

            ZStack(alignment: .topLeading) {
                // Dimmed background - fades with morph progress
                let dragDimming = min(1.0, max(0.0, 1.0 - (dragOffset.height / 400.0)))
                Color.black.opacity(0.25 * morphProgress * dragDimming)
                    .ignoresSafeArea()
                    .onTapGesture { dismissOverlay() }

                // Editor card with morphing frame
                VStack(spacing: 0) {
                    DiaryEditorCard(
                        entry: overlayEntry(),
                        height: 550,
                        cornerRadius: currentCornerRadius,
                        showShadow: false,
                        useExternalDecoration: true,
                        onAddImage: { showImagePicker = true },
                        imageMap: imageMap,
                        isEditable: true,
                        shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
                        forceExpanded: morphProgress > 0.5, // Only expand content when mostly open
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

                    Spacer(minLength: 0)
                }
                .frame(width: currentFrame.width, height: currentFrame.height)
                .background(
                    RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.12 * morphProgress), radius: 12, x: 0, y: 8)
                )
                .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                .position(
                    x: currentFrame.midX,
                    y: currentFrame.midY + max(0, dragOffset.height)
                )
                .overlay(alignment: .topTrailing) {
                    // Close button - only show when expanded
                    if morphProgress > 0.8 {
                        Button(action: { dismissOverlay() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary)
                                .padding(12)
                        }
                        .opacity(Double((morphProgress - 0.8) / 0.2)) // Fade in during last 20% of animation
                        .position(x: currentFrame.maxX - 30, y: currentFrame.minY + 30)
                    }
                }
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            // Only allow drag when fully expanded
                            guard morphProgress >= 1.0 else { return }
                            state = value.translation
                            if value.translation.height > 8 && !hasDismissedKeyboardForDrag {
                                shouldBecomeFirstResponder = false
                                hasDismissedKeyboardForDrag = true
                            }
                        }
                        .onEnded { value in
                            guard morphProgress >= 1.0 else { return }
                            let shouldDismiss = value.translation.height > 120 || value.predictedEndTranslation.height > 180
                            if shouldDismiss {
                                dismissOverlay()
                            } else {
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
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $pickedImage)
                .onDisappear {
                    handleImagePicked()
                }
        }
        .onAppear {
            setupOverlay()
        }
        .onDisappear {
            cleanupOverlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorParagraphCommitted)) { _ in
            scheduleAutosave(blocks: blocks)
        }
        .onReceive(NotificationCenter.default.publisher(for: .editorSavedParagraphEdited)) { _ in
            scheduleAutosave(blocks: blocks)
        }
    }

    private func dismissOverlay() {
        guard !isClosing else { return }
        isClosing = true

        // Dismiss keyboard first
        shouldBecomeFirstResponder = false

        // Animate back to source position
        withAnimation(.easeInOut(duration: morphDuration)) {
            morphProgress = 0
        }

        // Call onClose after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + morphDuration) {
            onClose()
        }
    }

    // Ensure source frame is valid (has reasonable size and position)
    private func validSourceFrame(screenSize: CGSize) -> CGRect {
        // If source frame is invalid or too small, use a centered default
        if sourceFrame.width < 50 || sourceFrame.height < 50 ||
           sourceFrame.minX < -100 || sourceFrame.minY < -100 {
            // Fallback: start from center of screen with card-like size
            let fallbackWidth = screenSize.width - 32
            let fallbackHeight: CGFloat = 500
            return CGRect(
                x: 16,
                y: (screenSize.height - fallbackHeight) / 2,
                width: fallbackWidth,
                height: fallbackHeight
            )
        }
        return sourceFrame
    }

    // Linear interpolation between two CGFloat values
    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    // Interpolate between two CGRect frames
    private func interpolateFrame(from: CGRect, to: CGRect, progress: CGFloat) -> CGRect {
        CGRect(
            x: interpolate(from: from.minX, to: to.minX, progress: progress),
            y: interpolate(from: from.minY, to: to.minY, progress: progress),
            width: interpolate(from: from.width, to: to.width, progress: progress),
            height: interpolate(from: from.height, to: to.height, progress: progress)
        )
    }

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

    private func setupOverlay() {
        // Start at source position (morphProgress = 0)
        morphProgress = 0
        isClosing = false

        // Animate to full screen
        withAnimation(.easeInOut(duration: morphDuration)) {
            morphProgress = 1
        }

        // Focus editor after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + morphDuration) {
            if !isClosing {
                shouldBecomeFirstResponder = true
            }
        }

        liveTotalCalories = entry.totalCalories

        loadTask = Task {
            do {
                let dbBlocks = try await DiaryAPI.getBlocksById(canonicalEntryId.uuidString)
                if Task.isCancelled { return }

                await MainActor.run {
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
                }
            } catch {
                // Best-effort
            }
        }

        Task {
            await MainActor.run {
                blocks = blocks.withStableIdsAndChangeTracking()
            }
        }

        let initial = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        lastSavedContent = initial
        hydrateImagesForOverlay()
    }

    private func cleanupOverlay() {
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

    private func handleImagePicked() {
        guard let image = pickedImage else { return }
        let uuid = UUID()
        let compressed = ImageCompression.compressForUpload(image, maxDimension: 720, quality: 0.7)
        imageMap[uuid] = compressed.resizedImage
        ImageCache.shared.storeLocal(compressed.resizedImage, ref: uuid)

        if let resizedPNG = compressed.resizedImage.pngData() {
            let newBlock = Block(type: .imageText(resizedPNG, uuid, ""), calorieData: nil)
            blocks.append(newBlock)

            let capturedUUID = uuid
            let blockId = newBlock.id

            Task.detached(priority: .userInitiated) {
                do {
                    let upload = try await ImageAPI.uploadJPEG(data: compressed.data, filename: "photo.jpg", contentType: "image/jpeg")
                    ImageCache.shared.store(compressed.resizedImage, for: upload.publicUrl)

                    await MainActor.run {
                        if let idx = blocks.firstIndex(where: { block in
                            if case let .imageText(_, ref, _) = block.type { return ref == capturedUUID }
                            return false
                        }) {
                            var updated = blocks[idx]
                            updated.imageUrl = upload.publicUrl
                            updated.imageObjectKey = upload.objectKey
                            blocks[idx] = updated
                            BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                        }
                    }

                    let analysis = try await ImageAPI.analyzeImage(imageUrl: upload.publicUrl, entryId: nil, blockId: blockId.uuidString)
                    let nutrition = NutritionData(
                        calories: analysis.calories,
                        protein: analysis.macros?.protein,
                        fat: analysis.macros?.fat,
                        carbs: analysis.macros?.carbs,
                        fiber: analysis.macros?.fiber,
                        sugar: analysis.macros?.sugar,
                        sodium: analysis.macros?.sodium,
                        weight: analysis.weight,
                        metric_description: analysis.metric_description,
                        confidence: analysis.confidence
                    )

                    await MainActor.run {
                        if let idx = blocks.firstIndex(where: { block in
                            if case let .imageText(_, ref, _) = block.type { return ref == capturedUUID }
                            return false
                        }) {
                            var updated = blocks[idx]
                            if case let .imageText(data, ref, _) = updated.type {
                                updated.type = .imageText(data, ref, analysis.description)
                            }
                            updated.imageUrl = updated.imageUrl ?? upload.publicUrl
                            updated.nutrition = nutrition
                            if let cals = analysis.calories, cals > 0 {
                                updated.calorieData = String(cals)
                            }
                            blocks[idx] = updated
                            BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
                        }
                    }
                } catch {
                    #if DEBUG
                    print("❌ Image pipeline error: \(error)")
                    #endif
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldBecomeFirstResponder = true
        }
        pickedImage = nil
    }

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

// MARK: - Autosave helpers for EditorOverlaySimple
extension EditorOverlaySimple {
    @MainActor
    private func canonicalizeEntryIfNeeded(row: DiaryAPI.Row, blocks: [Block]) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == canonicalEntryId { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: canonicalEntryId, serverId: serverUUID, blocks: blocks)
        canonicalEntryId = serverUUID
    }

    private func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        if suppressRemoteBlockUpdates { return }
        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent { return }
    }

    private func scheduleAutosave(blocks: [Block]) {
        debounceWorkItem?.cancel()
        autosaveTask?.cancel()
        let workItem = DispatchWorkItem {
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
        autosaveTask?.cancel()
        Task { await saveWithoutAIAnalysis(blocks: blocks) }
    }

    private func save(blocks: [Block]) async {
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
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)

                if Task.isCancelled { return }

                let payload = blocks.toAnalyzeBlocks()
                let isContentEmpty = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

                autosaveTask = Task {
                    do {
                        if isContentEmpty {
                            try await DiaryAPI.clearEntryNutrition(entryId: row.id)
                            await MainActor.run {
                                NotificationCenter.default.post(
                                    name: .diaryEntryTotalsUpdated,
                                    object: nil,
                                    userInfo: ["entryId": canonicalEntryId, "totalCalories": 0]
                                )
                                self.liveTotalCalories = 0
                            }
                        } else {
                            _ = try await DiaryAPI.analyze(entryId: row.id, blocksPayload: payload)

                            var hasReceivedNutritionData = false
                            let delays: [Double] = [0.8, 1.2, 2.0, 2.8, 4.0, 5.5, 7.5, 10.0]
                            for delay in delays {
                                if hasReceivedNutritionData { break }
                                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                                if Task.isCancelled { return }

                                let refreshed = try? await DiaryAPI.getById(row.id)
                                let dbBlocks = try? await DiaryAPI.getBlocksById(row.id)

                                await MainActor.run {
                                    if let refreshed {
                                        NotificationCenter.default.post(
                                            name: .diaryEntryTotalsUpdated,
                                            object: nil,
                                            userInfo: ["entryId": canonicalEntryId, "totalCalories": refreshed.total_calories as Any]
                                        )
                                        self.liveTotalCalories = refreshed.total_calories ?? self.liveTotalCalories
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
                                                        entryId: row.id
                                                    )
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
                    NotificationCenter.default.post(
                        name: .diaryEntryTotalsUpdated,
                        object: nil,
                        userInfo: ["entryId": canonicalEntryId, "totalCalories": row.total_calories as Any]
                    )
                }
            }
            lastSavedAt = Date()
            lastSavedContent = trimmed
        } catch {
            #if DEBUG
            print("❌ Autosave error: \(error)")
            #endif
        }
    }

    private func saveWithoutAIAnalysis(blocks: [Block]) async {
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
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                }
                lastSavedAt = Date()
                lastSavedContent = trimmed
                BlocksCache.shared.save(entryId: canonicalEntryId, blocks: blocks)
            }
        } catch {
            #if DEBUG
            print("❌ Flush save error: \(error)")
            #endif
        }
    }

    // MARK: - HealthKit Sync

    /// Sync nutrition data to HealthKit after AI analysis completes
    private func syncToHealthKit(
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
            // This will show the permission sheet if needed
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
            // Log error but don't interrupt user experience
            print("[HealthKit] Sync error: \(error.localizedDescription)")
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
}

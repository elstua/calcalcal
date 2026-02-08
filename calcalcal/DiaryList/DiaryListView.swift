import SwiftUI
import Foundation
import UIKit
import os.log

private let logger = Logger(subsystem: "com.calcalcal.app", category: "DiaryListView")

// MARK: - DiaryListView
struct DiaryListView: View {
    @State private var entries: [DiaryEntry] = DiaryListView.initialPlaceholderEntries()
    @State private var items: [TimelineItem] = []
    @State private var selectedEntry: DiaryEntry? = nil
    @State private var showPopup: Bool = false
    @State private var isLoadingRemote: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var currentLoadedDays: Int = 10
    
    // Shared geometry hooks (optional)
    var sharedNamespace: Namespace.ID? = nil
    var presentedEntryId: UUID? = nil
    var isOverlayActive: Bool = false
    var onRequestOpen: ((DiaryEntry) -> Void)? = nil
    var onRequestImageMap: (([UUID: UIImage]) -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    var userOffsetMinutes: Int? = nil // Optional override; fallback to device timezone if nil
    var streaksData: StreaksData? = nil
    private var timelineConfig = DayTimelineConfig(keepHeadCount: 0, collapseWithinInitialWindow: false)

    init(
        sharedNamespace: Namespace.ID? = nil,
        presentedEntryId: UUID? = nil,
        onRequestOpen: ((DiaryEntry) -> Void)? = nil,
        onRequestImageMap: (([UUID: UIImage]) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        userOffsetMinutes: Int? = nil,
        isOverlayActive: Bool = false,
        streaksData: StreaksData? = nil
    ) {
        self.sharedNamespace = sharedNamespace
        self.presentedEntryId = presentedEntryId
        self.isOverlayActive = isOverlayActive
        self.onRequestOpen = onRequestOpen
        self.onRequestImageMap = onRequestImageMap
        self.onDismiss = onDismiss
        self.userOffsetMinutes = userOffsetMinutes
        self.streaksData = streaksData
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                let enumeratedItems = Array(items.enumerated())
                VStack(spacing: 10) {
                    // Streak statistics at the top
                    StreakStatsView(streaksData: streaksData)
                        .padding(.top, 8)
                    
                    ForEach(enumeratedItems, id: \.element.id) { (index, item) in
                        timelineRowView(index: index, item: item)
                            .onAppear {
                                // Load more when approaching the end (within last 5 items)
                                if index >= items.count - 5 {
                                    Task {
                                        await loadMoreEntriesIfNeeded()
                                    }
                                }
                            }
                    }
                    
                    // Loading indicator at bottom
                    if isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                            Spacer()
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 16)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            
            // If no external opener is supplied, show local popup regardless of namespace
            if showPopup, let entry = selectedEntry, onRequestOpen == nil {
                DiaryEntryPopupView(entry: entry, isPresented: $showPopup)
                    .transition(.move(edge: .bottom))
                    .zIndex(1)
            }
        }
        .onAppear {
            recalcTimeline()
            Task { await loadInitialEntries() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCanonicalIdResolved)) { notification in
            guard let info = notification.userInfo,
                  let localId = info["localId"] as? UUID,
                  let serverId = info["serverId"] as? UUID else { return }
            if let index = entries.firstIndex(where: { $0.id == localId }) {
                entries[index].id = serverId
                recalcTimeline()
            }
            if var current = selectedEntry, current.id == localId {
                current.id = serverId
                selectedEntry = current
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryCaloriesUpdated)) { notification in
            guard let info = notification.userInfo,
                  let entryId = info["entryId"] as? UUID,
                  let totalCalories = info["totalCalories"] as? Int else { return }

            // Update the entry's calories in the list
            if let index = entries.firstIndex(where: { $0.id == entryId }) {
                entries[index].totalCalories = totalCalories
                recalcTimeline()
            }
        }
    }

    @ViewBuilder
    private func timelineRowView(index: Int, item: TimelineItem) -> some View {
        switch item {
        case .todayEntry(let entry):
            // Use compact card for all entries in all-days view
            compactCard(entry: entry, placeholderDay: nil)
        case .entry(let entry):
            compactCard(entry: entry, placeholderDay: nil)
        case .placeholder(let localDay):
            compactCard(
                entry: placeholderDisplayEntry(for: localDay, isToday: index == 0),
                placeholderDay: localDay
            )
        case .collapsed:
            // Skip collapsed sections - we load everything automatically now
            EmptyView()
        }
    }
    
    @ViewBuilder
    private func compactCard(entry: DiaryEntry, placeholderDay: LocalDay?) -> some View {
        let openAction = tapAction(for: entry, placeholderDay: placeholderDay)
        let tappableCard = compactCardShell(entry: entry)
            .contentShape(Rectangle())
            .highPriorityGesture(TapGesture().onEnded(openAction))
            .allowsHitTesting(!isEntryPresented(entry))
        
        // iOS 18+ uses zoomTransitionSource for the zoom animation
        if let ns = sharedNamespace {
            tappableCard
                .zoomTransitionSource(id: entry.id, namespace: ns)
        } else {
            tappableCard
        }
    }
    
    private func tapAction(for entry: DiaryEntry, placeholderDay: LocalDay?) -> () -> Void {
        {
            if let localDay = placeholderDay {
                // Check if today for placeholder prompt
                let offset = effectiveOffsetMinutes()
                let todayYYYYMMDD = LocalDayMath.yyyymmdd(for: Date(), offsetMinutes: offset)
                let isToday = localDay.yyyymmdd == todayYYYYMMDD
                handlePlaceholderTap(localDay: localDay, isToday: isToday)
            } else {
                present(entry: entry)
            }
        }
    }

    private func isEntryPresented(_ entry: DiaryEntry) -> Bool {
        guard isOverlayActive, let presentedEntryId else { return false }
        return presentedEntryId == entry.id
    }

    @ViewBuilder
    private func compactCardShell(entry: DiaryEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                .allowsHitTesting(false)
            EntrySummaryCard(entry: entry)
        }
    }

    private func placeholderDisplayEntry(for localDay: LocalDay, isToday: Bool) -> DiaryEntry {
        let placeholderBlock = Block(
            type: .text(placeholderPrompt(isToday: isToday)),
            calorieData: nil
        )
        return DiaryEntry(
            id: UUID(),
            date: localDay.startUTC,
            blocks: [placeholderBlock],
            totalCalories: nil,
            lastModified: localDay.startUTC,
            aiGeneratedSummary: nil
        )
    }
    
    private func handlePlaceholderTap(localDay: LocalDay, isToday: Bool) {
        if let existing = entry(for: localDay) {
            present(entry: existing)
            return
        }
        let newEntry = DiaryEntry(
            id: UUID(),
            date: localDay.startUTC,
            blocks: [Block(type: .text(placeholderPrompt(isToday: isToday)), calorieData: nil)],
            totalCalories: nil,
            lastModified: Date(),
            aiGeneratedSummary: nil
        )
        entries.append(newEntry)
        recalcTimeline()
        present(entry: newEntry)
    }
    
    private func entry(for localDay: LocalDay) -> DiaryEntry? {
        let offset = effectiveOffsetMinutes()
        return entries.first(where: { LocalDayMath.yyyymmdd(for: $0.date, offsetMinutes: offset) == localDay.yyyymmdd })
    }
    
    private func present(entry: DiaryEntry) {
        if let onRequestOpen {
            onRequestOpen(entry)
        } else {
            selectedEntry = entry
            showPopup = true
        }
    }
    
    private func placeholderPrompt(isToday: Bool) -> String {
        let baseText = isToday ? "write what you ate today" : "write what you ate this day"
        return "\(placeholderMarker)\(baseText)"
    }

    private func recalcTimeline() {
        items = DayTimelineGenerator.generate(
            entries: entries,
            userOffsetMinutes: effectiveOffsetMinutes(),
            config: timelineConfig
        )
    }

    private func effectiveOffsetMinutes() -> Int {
        if let m = userOffsetMinutes { return m }
        return TimeZone.current.secondsFromGMT() / 60
    }

    private func mapEntriesByLocalDay() -> [String: DiaryEntry] {
        var result: [String: DiaryEntry] = [:]
        let offset = effectiveOffsetMinutes()
        for e in entries {
            let key = LocalDayMath.yyyymmdd(for: e.date, offsetMinutes: offset)
            result[key] = e
        }
        return result
    }

    // MARK: - Remote loading
    private func computeDateWindow(days: Int = 30) -> (from: String, to: String) {
        let offset = effectiveOffsetMinutes()
        let to = LocalDayMath.yyyymmdd(for: Date(), offsetMinutes: offset)
        let fromStartUTC = LocalDayMath.localDayStartUTC(anchor: Date(), offsetMinutes: offset, daysBack: max(0, days - 1))
        let from = LocalDayMath.yyyymmdd(for: fromStartUTC, offsetMinutes: offset)
        return (from, to)
    }

    private func loadInitialEntries() async {
        if isLoadingRemote { return }
        isLoadingRemote = true
        let window = computeDateWindow(days: currentLoadedDays)
        do {
            let rows = try await DiaryAPI.listEntries(dateFrom: window.from, dateTo: window.to)
            let mapped = rows.map { $0.toDiaryEntry() }
            await MainActor.run {
                self.entries = mapped
                self.recalcTimeline()
            }
        } catch {
            logger.error("Failed to load entries: \(error.localizedDescription)")
        }
        isLoadingRemote = false
    }
    
    private func loadMoreEntriesIfNeeded() async {
        if isLoadingMore || isLoadingRemote { return }
        
        await MainActor.run {
            isLoadingMore = true
        }
        
        // Load 10 more days
        let newDaysCount = currentLoadedDays + 10
        let window = computeDateWindow(days: newDaysCount)
        
        do {
            let rows = try await DiaryAPI.listEntries(dateFrom: window.from, dateTo: window.to)
            let mapped = rows.map { $0.toDiaryEntry() }
            await MainActor.run {
                self.entries = mapped
                self.currentLoadedDays = newDaysCount
                self.recalcTimeline()
                self.isLoadingMore = false
            }
            logger.info("Loaded \(newDaysCount) days of entries")
        } catch {
            logger.error("Failed to load more entries: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoadingMore = false
            }
        }
    }
}

// MARK: - Small helper for optional ViewModifier application
extension View {
    @ViewBuilder
    func ifLet<T, V: View>(_ value: T?, transform: (Self, T) -> V) -> some View {
        if let value = value {
            transform(self, value)
        } else {
            self
        }
    }
}

// MARK: - Fullscreen Popup View
struct DiaryEntryPopupView: View {
    @State var entry: DiaryEntry
    @Binding var isPresented: Bool
    @GestureState private var dragOffset = CGSize.zero
    @State private var shouldFocusEditor = false
    @State private var debounceWorkItem: DispatchWorkItem? = nil
    @State private var lastSavedAt: Date? = nil
    @State private var lastSavedContent: String? = nil
    @State private var canonicalEntryId: UUID

    init(entry: DiaryEntry, isPresented: Binding<Bool>) {
        self._entry = State(initialValue: entry)
        self._isPresented = isPresented
        _canonicalEntryId = State(initialValue: entry.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            EntryCard(
                entry: entry,
                isEditable: true,
                shouldBecomeFirstResponder: $shouldFocusEditor,
                forceExpanded: true,
                onBlocksChange: { newBlocks in
                    entry.blocks = newBlocks
                    BlocksCache.shared.save(entryId: canonicalEntryId, blocks: newBlocks)
                }
            )
                .padding()
                .cornerRadius(24)
                .shadow(radius: 10)
                .onChange(of: entry.blocks) { newBlocks in
                    scheduleAutosaveIfTextChanged(blocks: newBlocks)
                    BlocksCache.shared.save(entryId: canonicalEntryId, blocks: newBlocks)
                }
            Spacer()
        }
        .background(Color.black.opacity(0.2).ignoresSafeArea())
        .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        isPresented = false
                    }
                }
        )
        .animation(.spring(), value: dragOffset)
        .onAppear {
            shouldFocusEditor = true
            // Initialize lastSavedContent to current content to avoid initial autosave loop
            let initial = entry.blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
            lastSavedContent = initial
        }
        .onChange(of: isPresented) { presented in
            if !presented {
                flushSave()
            }
        }
    }

    // MARK: - Autosave helpers
    private func scheduleAutosaveIfTextChanged(blocks: [Block]) {
        let content = blocks.toContentString().trimmingCharacters(in: .whitespacesAndNewlines)
        if content == lastSavedContent {
            print("⏭️ Autosave skipped (text unchanged)")
            return
        }
        scheduleAutosave(blocks: blocks)
    }

    private func scheduleAutosave(blocks: [Block]) {
        debounceWorkItem?.cancel()
        print("🕐 Autosave scheduled in 1s…")
        let workItem = DispatchWorkItem { [entry] in
            print("💾 Autosave firing…")
            Task { await save(blocks: blocks) }
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func flushSave() {
        if let work = debounceWorkItem {
            work.cancel()   
            debounceWorkItem = nil
        }
        print("🔚 Flushing autosave on close…")
        Task { await save(blocks: entry.blocks) }
    }

    private func save(blocks: [Block]) async {
        let content = blocks.toContentString()
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Skip saving if content is empty or contains only placeholder
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
            print("⏭️ Autosave skipped (empty/placeholder content)")
            return
        }
        // Compute yyyy-MM-dd for entry.date using device timezone for now (timeline already applied offset)
        let offsetMinutes = TimeZone.current.secondsFromGMT() / 60
        let day = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: offsetMinutes)
        print("⬆️ Upserting content for day \(day)…")
        do {
            if let userId = UserDefaults.standard.string(forKey: "current_user_id") {
                let row = try await DiaryAPI.upsertContent(date: day, userId: userId, content: content)
                await MainActor.run {
                    canonicalizeEntryIfNeeded(row: row, blocks: blocks)
                    // Update visible totals in the editor footer and list
                    entry.totalCalories = row.total_calories
                }
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
                        print("⚠️ Failed to refresh streaks after autosave: \(error)")
                    }
                }
            } else {
                // Fallback: do nothing; next save will update once user id is available.
                print("⚠️ Missing user id; deferring insert until available")
            }
            lastSavedAt = Date()
            lastSavedContent = trimmed
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            // For v1, ignore errors silently; could add retry/indicator later.
            print("❌ Autosave error: \(error)")
        }
    }
}


extension DiaryEntryPopupView {
    @MainActor
    private func canonicalizeEntryIfNeeded(row: DiaryAPI.Row, blocks: [Block]) {
        guard let serverUUID = UUID(uuidString: row.id) else { return }
        if serverUUID == canonicalEntryId { return }
        EntryIdentityCoordinator.shared.canonicalize(localId: canonicalEntryId, serverId: serverUUID, blocks: blocks)
        canonicalEntryId = serverUUID
        entry.id = serverUUID
    }
}

// MARK: - Mock Data Generation
extension DiaryListView {
    static func initialPlaceholderEntries() -> [DiaryEntry] {
        let today = Date()
        let placeholderText = "\(placeholderMarker)write what you ate today"
        let placeholderBlock = Block(type: .text(placeholderText), calorieData: nil)
        let entry = DiaryEntry(
            id: UUID(),
            date: today,
            blocks: [placeholderBlock],
            totalCalories: nil,
            lastModified: today,
            aiGeneratedSummary: nil
        )
        return [entry]
    }
}

// MARK: - Preview
struct DiaryListView_Previews: PreviewProvider {
    static var previews: some View {
        DiaryListView()
    }
} 

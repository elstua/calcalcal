import SwiftUI
import Foundation
import UIKit
// Explicit imports for model visibility

// MARK: - DiaryListView
struct DiaryListView: View {
    @State private var entries: [DiaryEntry] = DiaryListView.initialPlaceholderEntries()
    @State private var items: [TimelineItem] = []
    @State private var selectedEntry: DiaryEntry? = nil
    @State private var showPopup: Bool = false
    @State private var isLoadingRemote: Bool = false
    
    // Shared geometry hooks (optional)
    var sharedNamespace: Namespace.ID? = nil
    var presentedEntryId: UUID? = nil
    var onRequestOpen: ((DiaryEntry) -> Void)? = nil
    var onRequestImageMap: (([UUID: UIImage]) -> Void)? = nil
    var userOffsetMinutes: Int? = nil // Optional override; fallback to device timezone if nil
    private var timelineConfig = DayTimelineConfig(keepHeadCount: 5, collapseWithinInitialWindow: true)

    init(
        sharedNamespace: Namespace.ID? = nil,
        presentedEntryId: UUID? = nil,
        onRequestOpen: ((DiaryEntry) -> Void)? = nil,
        onRequestImageMap: (([UUID: UIImage]) -> Void)? = nil,
        userOffsetMinutes: Int? = nil
    ) {
        self.sharedNamespace = sharedNamespace
        self.presentedEntryId = presentedEntryId
        self.onRequestOpen = onRequestOpen
        self.onRequestImageMap = onRequestImageMap
        self.userOffsetMinutes = userOffsetMinutes
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                let enumeratedItems = Array(items.enumerated())
                VStack(spacing: 10) {
                    ForEach(enumeratedItems, id: \.element.id) { (index, item) in
                        timelineRowView(index: index, item: item)
                    }
                }
                .padding(.vertical)
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
        .onReceive(NotificationCenter.default.publisher(for: .editorOverlayDidCommit)) { notification in
            guard let userInfo = notification.userInfo,
                  let entryId = userInfo["entryId"] as? UUID,
                  let blocks = userInfo["blocks"] as? [Block] else { return }
            if let index = entries.firstIndex(where: { $0.id == entryId }) {
                entries[index].blocks = blocks
                entries[index].lastModified = Date()
                recalcTimeline()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .diaryEntryTotalsUpdated)) { notification in
            guard let userInfo = notification.userInfo,
                  let entryId = userInfo["entryId"] as? UUID,
                  let total = userInfo["totalCalories"] as? Int? else { return }
            if let index = entries.firstIndex(where: { $0.id == entryId }) {
                entries[index].totalCalories = total
                recalcTimeline()
            }
        }
    }

    @ViewBuilder
    private func timelineRowView(index: Int, item: TimelineItem) -> some View {
        switch item {
        case .todayEntry(let entry):
            if let ns = sharedNamespace {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.systemBackground))
                        .matchedGeometryEffect(id: "bg-\(entry.id)", in: ns)
                        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        .allowsHitTesting(false)
                    BigEntryBlock(
                        entry: entry,
                        height: 550,
                        cornerRadius: 0,
                        showShadow: false,
                        useExternalDecoration: true,
                        onAddImage: { },
                        onTap: { },
                        isEditable: false,
                        shouldBecomeFirstResponder: .constant(false)
                    )
                    .padding(.horizontal)
                }
                .matchedGeometryEffect(id: entry.id, in: ns)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        if let open = onRequestOpen { open(entry) }
                        else { showPopup = true; selectedEntry = entry }
                    }
                )
                .opacity(presentedEntryId == entry.id ? 0 : 1)
                .allowsHitTesting(presentedEntryId != entry.id)
            } else {
                BigEntryBlock(
                    entry: entry,
                    onAddImage: { },
                    onTap: {
                        if let open = onRequestOpen { open(entry) }
                        else { showPopup = true; selectedEntry = entry }
                    },
                    isEditable: false,
                    shouldBecomeFirstResponder: .constant(false)
                )
                .padding(.horizontal)
            }
        case .entry(let entry):
            if let ns = sharedNamespace {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                        .matchedGeometryEffect(id: "bg-\(entry.id)", in: ns)
                        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
                        .allowsHitTesting(false)
                    SmallEntryBlock(
                        entry: entry,
                        onTap: nil,
                        isEditable: false,
                        useExternalDecoration: true
                    )
                    .padding(.horizontal)
                }
                .matchedGeometryEffect(id: entry.id, in: ns)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    TapGesture().onEnded {
                        if let open = onRequestOpen { open(entry) }
                        else { showPopup = true; selectedEntry = entry }
                    }
                )
                .opacity(presentedEntryId == entry.id ? 0 : 1)
                .allowsHitTesting(presentedEntryId != entry.id)
            } else {
                SmallEntryBlock(
                    entry: entry,
                    onTap: {
                        if let open = onRequestOpen { open(entry) }
                        else { showPopup = true; selectedEntry = entry }
                    },
                    isEditable: false
                )
                .padding(.horizontal)
            }
        case .placeholder(let localDay):
            placeholderRow(localDay: localDay, isToday: index == 0)
                .padding(.horizontal)
        case .collapsed(let range, let count, let id):
            let primary = "\(count) \(count == 1 ? "day" : "days"), \(DayTimelineGenerator.formatRange(range: range, offsetMinutes: effectiveOffsetMinutes()))"
            let secondary = "Tap to show \(min(14, count)) more days"
            CollapsedEmptyRunView(primaryText: primary, secondaryText: secondary) {
                let mapping = mapEntriesByLocalDay()
                items = DayTimelineGenerator.apply(
                    .expandCollapsedRun(id: id),
                    to: items,
                    userOffsetMinutes: effectiveOffsetMinutes(),
                    config: timelineConfig,
                    entriesByDay: mapping
                )
            }
            .padding(.horizontal)
        }
    }

    private func placeholderRow(localDay: LocalDay, isToday: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Day number
            Text(dayNumberString(from: localDay))
                .font(.title.bold())
                .foregroundColor(.primary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.15))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(isToday ? "write what you ate today" : "No entry yet. Start logging your food!")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
                Text("… kcal")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(.top, 2)
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            // Create or reuse an entry for this placeholder day, then open it
            let key = localDay.yyyymmdd
            let offset = effectiveOffsetMinutes()
            if let index = entries.firstIndex(where: { LocalDayMath.yyyymmdd(for: $0.date, offsetMinutes: offset) == key }) {
                let target = entries[index]
                if let open = onRequestOpen { open(target) }
                else { selectedEntry = target; showPopup = true }
            } else {
                let placeholderBlock = Block(type: .text(isToday ? "write what you ate today" : "write what you ate this day"), calorieData: nil)
                let newEntry = DiaryEntry(
                    id: UUID(),
                    date: localDay.startUTC,
                    blocks: [placeholderBlock],
                    totalCalories: nil,
                    lastModified: Date(),
                    aiGeneratedSummary: nil
                )
                entries.append(newEntry)
                recalcTimeline()
                if let open = onRequestOpen { open(newEntry) }
                else { selectedEntry = newEntry; showPopup = true }
            }
        }
    }

    private func dayNumberString(from localDay: LocalDay) -> String {
        let local = localDay.startUTC.addingTimeInterval(TimeInterval(effectiveOffsetMinutes() * 60))
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: local)
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
        let window = computeDateWindow(days: 30)
        do {
            let rows = try await DiaryAPI.listEntries(dateFrom: window.from, dateTo: window.to)
            let mapped = rows.map { $0.toDiaryEntry() }
            await MainActor.run {
                self.entries = mapped
                self.recalcTimeline()
            }
        } catch {
            print("Failed to load entries: \(error)")
        }
        isLoadingRemote = false
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
            BigEntryBlock(
                entry: entry,
                isEditable: true,
                shouldBecomeFirstResponder: $shouldFocusEditor,
                forceExpanded: true,
                onBlocksChange: { newBlocks in
                    entry.blocks = newBlocks
                }
            )
                .padding()
                .cornerRadius(24)
                .shadow(radius: 10)
                .onChange(of: entry.blocks) { newBlocks in
                    scheduleAutosaveIfTextChanged(blocks: newBlocks)
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
        struct Static { static var lastSavedContent: String? }
        if content == Static.lastSavedContent {
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
        // Skip saving if content is empty or equals placeholder prompts
        let placeholders: Set<String> = [
            "write what you ate today",
            "write what you ate this day"
        ]
        if trimmed.isEmpty || placeholders.contains(trimmed) {
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
                    // Update visible totals in the editor footer
                    entry.totalCalories = row.total_calories
                    // Broadcast to update day list cards in place
                    NotificationCenter.default.post(
                        name: .diaryEntryTotalsUpdated,
                        object: nil,
                        userInfo: [
                            "entryId": entry.id,
                            "totalCalories": row.total_calories as Any
                        ]
                    )
                }
            } else {
                // Fallback: do nothing; next save will update once user id is available.
                print("⚠️ Missing user id; deferring insert until available")
            }
            lastSavedAt = Date()
            struct Static { static var lastSavedContent: String? }
            Static.lastSavedContent = trimmed
            print("✅ Autosave success at \(lastSavedAt?.description ?? "now")")
        } catch {
            // For v1, ignore errors silently; could add retry/indicator later.
            print("❌ Autosave error: \(error)")
        }
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let diaryEntryTotalsUpdated = Notification.Name("diaryEntryTotalsUpdated")
}

// MARK: - Mock Data Generation
extension DiaryListView {
    static func initialPlaceholderEntries() -> [DiaryEntry] {
        let today = Date()
        let placeholderBlock = Block(type: .text("write what you ate today"), calorieData: nil)
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

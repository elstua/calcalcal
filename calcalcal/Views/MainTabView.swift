import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @Namespace private var editorNamespace
    
    @State private var presentedEntry: DiaryEntry? = nil
    @State private var presentedBlocks: [Block] = []
    @State private var shouldFocusEditor: Bool = false
    @State private var isOverlayVisible: Bool = false
    @State private var shouldHideSourceCard: Bool = false
    
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var anchorDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var dayEntryStates: [String: DayEntryState] = [:]
    @State private var showAllDaysSheet: Bool = false
    @State private var isLoadingRecentDays: Bool = false
    
    private let overlayAnimation = Animation.easeInOut(duration: 0.35)
    private let overlayAnimationDuration: Double = 0.35
    private let stripDayCount: Int = 6
    private let calendar = Calendar.current
    private let placeholderPrompts: Set<String> = [
        "write what you ate today",
        "write what you ate this day"
    ]
    
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
        }) {
            DiaryListView(
                sharedNamespace: editorNamespace,
                presentedEntryId: presentedEntry?.id,
                onRequestOpen: { entry in
                    presentOverlay(for: entry)
                },
                isOverlayActive: shouldHideSourceCard
            )
        }
    }
    
    @ViewBuilder
    var dayPager: some View {
        if pagerItems.isEmpty {
            placeholderCard {
                Text("No entry for this day yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        } else {
            DiaryPagerView(
                items: pagerItems,
                selectedDate: $selectedDay,
                calendar: calendar,
                spacing: 12,
                trailingSpace: 48
            ) { item, isActive in
                cardView(for: item.entry, enableMatchedGeometry: isActive)
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
    
    func cardView(for entry: DiaryEntry, enableMatchedGeometry: Bool) -> some View {
        let shouldHideForOverlay = isOverlayVisible && presentedEntry?.id == entry.id
        
        return VStack(spacing: 0) {
            BigEntryBlock(
                entry: entry,
                height: 500,
                cornerRadius: 24,
                showShadow: true,
                useExternalDecoration: false,
                onAddImage: nil,
                onTap: enableMatchedGeometry ? { presentOverlay(for: entry) } : nil,
                imageMap: [:],
                isEditable: false,
                shouldBecomeFirstResponder: .constant(false),
                forceExpanded: false
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .id(entry.id)
            .modifier(
                ConditionalMatchedGeometry(
                    enabled: enableMatchedGeometry,
                    id: entry.id,
                    namespace: editorNamespace
                )
            )
            .opacity(shouldHideForOverlay ? 0 : 1)
            .allowsHitTesting(enableMatchedGeometry ? !shouldHideForOverlay : false)
            .frame(height: 500, alignment: .top)
            
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    func placeholderCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Color(.systemBackground))
            .frame(height: 500)
            .overlay(content())
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
    }
    
    func presentOverlay(for entry: DiaryEntry) {
        shouldFocusEditor = false
        shouldHideSourceCard = true
        presentedBlocks = entry.blocks
        withAnimation(overlayAnimation) {
            presentedEntry = entry
            isOverlayVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            shouldFocusEditor = true
        }
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
            EditorOverlay(
                entry: entry,
                blocks: $presentedBlocks,
                shouldBecomeFirstResponder: $shouldFocusEditor,
                namespace: editorNamespace,
                onClose: {
                    shouldHideSourceCard = false
                    DispatchQueue.main.async {
                        shouldFocusEditor = false
                    }
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
                    
                    let closingId = entry.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + overlayAnimationDuration) {
                        if presentedEntry?.id == closingId {
                            withAnimation(overlayAnimation) {
                                isOverlayVisible = false
                            }
                            presentedEntry = nil
                        }
                    }
                }
            )
            .transition(.identity)
            .zIndex(100)
        }
    }
    
    struct DayEntryState {
        var entry: DiaryEntry
        var isPlaceholder: Bool
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppState())
    }
}


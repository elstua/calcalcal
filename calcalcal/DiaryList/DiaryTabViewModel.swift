import Foundation
import Combine

/// ViewModel for the DiaryTabView that manages day state, entry fetching, and data transformations.
/// Separates business logic from the view layer.
@MainActor
final class DiaryTabViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var dayEntryStates: [String: DayEntryState] = [:]
    @Published var selectedDay: Date
    @Published var anchorDate: Date
    @Published var isLoadingRecentDays: Bool = false
    
    // MARK: - Constants
    let stripDayCount: Int = 6
    
    // MARK: - Placeholder Options
    var placeholderOptions: PlaceholderOptions = .default
    
    // MARK: - Dependencies
    private let calendar: Calendar
    
    // MARK: - Initialization
    init(calendar: Calendar = .current) {
        self.calendar = calendar
        let today = calendar.startOfDay(for: Date())
        self.selectedDay = today
        self.anchorDate = today
    }
    
    // MARK: - Computed Properties
    
    /// Array of visible dates (today and previous days based on stripDayCount)
    var visibleDates: [Date] {
        (0..<stripDayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: anchorDate)
        }
    }
    
    /// Pager items derived from visible dates and entry states
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
    
    // MARK: - Day Strip Items
    
    /// Generate day strip items with streak information
    func dayStripItems(streaksData: StreaksData?) -> [DayStripItemModel] {
        // Parse streak start date
        let streakStart: Date?
        if let startString = streaksData?.streakStartDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            streakStart = formatter.date(from: startString)
        } else {
            streakStart = nil
        }
        
        return visibleDates.reversed().map { date in
            let key = dayKey(for: date)
            let state = dayEntryStates[key]
            
            // Check if date is in streak range AND has actual content
            let hasEntry = !(state?.isPlaceholder ?? true)
            var isInStreak = false
            if let start = streakStart, hasEntry {
                let dayStart = calendar.startOfDay(for: date)
                let streakDayStart = calendar.startOfDay(for: start)
                let today = calendar.startOfDay(for: Date())

                isInStreak = dayStart >= streakDayStart && dayStart <= today
            }
            
            return DayStripItemModel(
                id: key,
                date: date,
                calories: state?.entry.blocks.resolvedCalorieTotal() ?? state?.entry.totalCalories,
                hasEntry: !(state?.isPlaceholder ?? true),
                isInStreak: isInStreak
            )
        }
    }
    
    /// Returns a streak value that never lags behind entries already visible in
    /// local UI state. Backend streaks remain the source of truth, but this keeps
    /// the header from snapping back to zero while a just-closed editor is still
    /// saving or while a stale refresh finishes.
    func optimisticCurrentStreak(baseline: Int) -> Int {
        let today = calendar.startOfDay(for: Date())
        var localStreak = 0
        
        for offset in 0..<stripDayCount {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { break }
            let key = dayKey(for: date)
            guard let state = dayEntryStates[key],
                  hasUserVisibleContent(state.entry.blocks, isPlaceholder: state.isPlaceholder) else {
                break
            }
            localStreak += 1
        }
        
        return max(baseline, localStreak)
    }
    
    // MARK: - Day Selection
    
    func selectDay(_ date: Date) {
        let normalized = calendar.startOfDay(for: date)
        guard isDateVisible(normalized) else { return }
        guard normalized != selectedDay else { return }
        selectedDay = normalized
    }
    
    // MARK: - Entry State Management
    
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
    
    func clampSelectedDayIfNeeded() {
        guard !isDateVisible(selectedDay), let fallback = visibleDates.first else { return }
        selectedDay = fallback
    }
    
    func updateDayEntry(entryId: UUID, update: (inout DayEntryState) -> Void) {
        for key in dayEntryStates.keys {
            guard var state = dayEntryStates[key], state.entry.id == entryId else { continue }
            update(&state)
            dayEntryStates[key] = state
            break
        }
    }
    
    func replaceEntryForVisibleDay(_ entry: DiaryEntry, isPlaceholder: Bool) {
        let key = dayKey(for: entry.date)
        dayEntryStates[key] = DayEntryState(entry: entry, isPlaceholder: isPlaceholder)
    }
    
    func replaceEntryId(localId: UUID, with serverId: UUID) {
        for key in dayEntryStates.keys {
            guard var state = dayEntryStates[key], state.entry.id == localId else { continue }
            state.entry.id = serverId
            dayEntryStates[key] = state
        }
    }

    /// Updates the calorie count for a specific entry
    /// Used when backend AI analysis completes and sends updated nutrition data
    func updateEntryCalories(entryId: UUID, totalCalories: Int?) {
        for key in dayEntryStates.keys {
            guard var state = dayEntryStates[key], state.entry.id == entryId else { continue }
            state.entry.totalCalories = totalCalories
            dayEntryStates[key] = state
            DataFlowLogger.shared.entryCaloriesUpdated(dayKey: key, entryId: entryId, calories: totalCalories)
            break
        }
    }
    
    // MARK: - Data Fetching
    
    func refreshVisibleEntries() async {
        anchorDate = calendar.startOfDay(for: Date())
        clampSelectedDayIfNeeded()
        ensurePlaceholdersForVisibleDays()
        
        guard !isLoadingRecentDays else { 
            DataFlowLogger.shared.backendRefreshSkipped(reason: "already loading")
            return 
        }
        isLoadingRecentDays = true
        
        let dates = visibleDates
        let offset = effectiveOffsetMinutes()
        let oldest = dates.last ?? anchorDate
        let newest = dates.first ?? anchorDate
        
        let dateFrom = LocalDayMath.yyyymmdd(for: oldest, offsetMinutes: offset)
        let dateTo = LocalDayMath.yyyymmdd(for: newest, offsetMinutes: offset)
        DataFlowLogger.shared.backendRefreshStarted(dateFrom: dateFrom, dateTo: dateTo)
        
        do {
            let rows = try await DiaryAPI.listEntries(dateFrom: dateFrom, dateTo: dateTo)
            let mapped = rows.map { $0.toDiaryEntry() }
            apply(entries: mapped)
            isLoadingRecentDays = false
            DataFlowLogger.shared.backendRefreshCompleted(entryCount: mapped.count)
        } catch {
            isLoadingRecentDays = false
            DataFlowLogger.shared.backendRefreshFailed(error: error.localizedDescription)
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
            
            DataFlowLogger.shared.entryApplied(
                dayKey: key, 
                entryId: entry.id, 
                blockCount: entry.blocks.count
            )
            
            if updated[key] != nil {
                // Check if we're about to overwrite a newer version
                if let existing = updated[key] {
                    let existingContent = existing.entry.blocks.toContentString()
                    let newContent = entry.blocks.toContentString()
                    if existingContent != newContent {
                        DataFlowLogger.shared.entryOverwritten(
                            dayKey: key,
                            oldBlockCount: existing.entry.blocks.count,
                            newBlockCount: entry.blocks.count,
                            oldContent: String(existingContent.prefix(50)),
                            newContent: String(newContent.prefix(50))
                        )
                    }
                    
                    // Preserve local content/calorie updates if the backend response is
                    // stale or still waiting for analysis totals. This prevents the
                    // main card, day strip, and streak header from snapping back to
                    // empty/zero right after the editor closes.
                    let localCalories = existing.entry.blocks.resolvedCalorieTotal() ?? existing.entry.totalCalories
                    let remoteCalories = entry.totalCalories
                    let hasLocalContent = hasUserVisibleContent(existing.entry.blocks, isPlaceholder: existing.isPlaceholder)
                    let hasRemoteContent = hasUserVisibleContent(entry.blocks, isPlaceholder: isPlaceholderContent(entry.blocks))
                    let remoteHasNoCalories = remoteCalories == nil || remoteCalories == 0
                    let shouldPreserveLocalCalories = hasLocalContent
                        && localCalories != nil
                        && remoteHasNoCalories
                        && localCalories != remoteCalories
                    let shouldPreserveLocalBlocks = hasLocalContent
                        && (!hasRemoteContent || existing.entry.lastModified >= entry.lastModified)
                    
                    if shouldPreserveLocalCalories || shouldPreserveLocalBlocks {
                        var entryWithPreservedCalories = entry
                        if shouldPreserveLocalBlocks {
                            entryWithPreservedCalories.blocks = existing.entry.blocks
                            entryWithPreservedCalories.lastModified = max(existing.entry.lastModified, entry.lastModified)
                        }
                        if shouldPreserveLocalCalories {
                            entryWithPreservedCalories.totalCalories = localCalories
                        }
                        updated[key] = DayEntryState(
                            entry: entryWithPreservedCalories,
                            isPlaceholder: isPlaceholderContent(entryWithPreservedCalories.blocks)
                        )
                        DataFlowLogger.shared.caloriesPreserved(dayKey: key, entryId: entry.id, calories: localCalories)
                        continue
                    }
                }
                
                updated[key] = DayEntryState(entry: entry, isPlaceholder: isPlaceholderContent(entry.blocks))
            }
        }
        
        dayEntryStates = updated
    }
    
    // MARK: - Helper Methods
    
    func dayKey(for date: Date) -> String {
        LocalDayMath.yyyymmdd(for: date, offsetMinutes: effectiveOffsetMinutes())
    }
    
    func effectiveOffsetMinutes() -> Int {
        TimeZone.current.secondsFromGMT() / 60
    }
    
    func placeholderPrompt(isToday: Bool) -> String {
        let baseText = isToday ? "write what you ate today" : "write what you ate this day"
        return "\(placeholderMarker)\(baseText)"
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

    func isPlaceholderContent(_ blocks: [Block]) -> Bool {
        // Treat the entry as a placeholder only when it has no user-entered
        // text or images. A block can still carry the placeholder marker while
        // the user is replacing the prompt, so checking "any marker" is too
        // aggressive and can make real entries look empty.
        let contentBlocks = blocks.filter { block in
            switch block.type {
            case .text(let text):
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .imageText(_, _, let text):
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || block.imageUrl != nil
            case .image:
                return true
            default:
                return false
            }
        }
        guard !contentBlocks.isEmpty else { return true }
        
        return contentBlocks.allSatisfy { block in
            switch block.type {
            case .text(let text):
                return text.isPlaceholderText
            case .imageText(_, _, let text):
                return text.isPlaceholderText && block.imageUrl == nil
            default:
                return false
            }
        }
    }
    
    private func hasUserVisibleContent(_ blocks: [Block], isPlaceholder: Bool) -> Bool {
        guard !isPlaceholder else { return false }
        return blocks.contains { block in
            switch block.type {
            case .text(let text):
                return !text.strippingPlaceholderMarker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .imageText(_, _, let text):
                return !text.strippingPlaceholderMarker.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || block.imageUrl != nil
            case .image:
                return true
            case .spacer:
                return false
            }
        }
    }
}

import Foundation

// Ensure model types are visible in this file's scope
// If you encounter module visibility issues in Xcode, make sure these files are in the same target
// or import the appropriate module.

// MARK: - Local Day Math

/// Utilities for computing user-local calendar days using an explicit offset (in minutes) from UTC.
/// We avoid relying on device `TimeZone` to keep server/user-profile sourced offsets authoritative
/// and to keep day keys stable across DST transitions.
enum LocalDayMath {
	static func startUTC(forDayKey dayKey: String, offsetMinutes: Int) -> Date? {
		let parts = dayKey.split(separator: "-").compactMap { Int($0) }
		guard parts.count == 3 else { return nil }
		var components = DateComponents()
		components.calendar = Calendar(identifier: .gregorian)
		components.timeZone = TimeZone(secondsFromGMT: 0)
		components.year = parts[0]
		components.month = parts[1]
		components.day = parts[2]
		guard let localMidnightInShiftedUTC = components.calendar?.date(from: components) else { return nil }
		return localMidnightInShiftedUTC.addingTimeInterval(-TimeInterval(offsetMinutes * 60))
	}

	/// Returns the UTC `Date` corresponding to the start of the local day for the given `date`
	/// using `offsetMinutes` (positive east of UTC). For example, if offset is +180 (UTC+3),
	/// local midnight corresponds to UTC 21:00 of the previous day.
	static func startOfLocalDay(for date: Date, offsetMinutes: Int) -> Date {
		// Shift date by offset to obtain pseudo-local time, truncate to day, then shift back
		let offsetSeconds = TimeInterval(offsetMinutes * 60)
		let shifted = date.addingTimeInterval(TimeInterval(offsetSeconds))
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		let comps = calendar.dateComponents([.year, .month, .day], from: shifted)
		let startShifted = calendar.date(from: comps) ?? shifted
		return startShifted.addingTimeInterval(-offsetSeconds)
	}

	/// Formats a day key `yyyy-MM-dd` for the provided `date` at the given `offsetMinutes`.
	static func yyyymmdd(for date: Date, offsetMinutes: Int) -> String {
		let start = startOfLocalDay(for: date, offsetMinutes: offsetMinutes)
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0)!
		let comps = calendar.dateComponents([.year, .month, .day], from: start.addingTimeInterval(TimeInterval(offsetMinutes * 60)))
		let year = comps.year ?? 1970
		let month = comps.month ?? 1
		let day = comps.day ?? 1
		return String(format: "%04d-%02d-%02d", year, month, day)
	}

	/// Returns the `Date` for the day that is `daysBack` days before the provided `anchor` local day.
	/// The returned date is the UTC moment corresponding to local midnight of that day.
	static func localDayStartUTC(anchor: Date, offsetMinutes: Int, daysBack: Int) -> Date {
		let start = startOfLocalDay(for: anchor, offsetMinutes: offsetMinutes)
		return start.addingTimeInterval(-TimeInterval(86400 * daysBack))
	}
}

// MARK: - Local Day Types

/// Canonical representation for a user-local calendar day.
struct LocalDay: Hashable, Equatable {
	/// Day key (yyyy-MM-dd) computed with user-local offset.
	let yyyymmdd: String
	/// UTC instant corresponding to local midnight at the start of this day.
	let startUTC: Date
}

struct LocalDayRange: Equatable {
	/// Older boundary (earlier in time)
	let start: LocalDay
	/// Newer boundary (later in time)
	let end: LocalDay
}

// MARK: - Timeline Items

enum TimelineItem: Identifiable, Equatable {
	case todayEntry(DiaryEntry)
	case entry(DiaryEntry)
	case placeholder(LocalDay)
	case collapsed(LocalDayRange, count: Int, id: UUID)

	var id: String {
		switch self {
		case .todayEntry(let e): return "today-" + e.id.uuidString
		case .entry(let e): return "entry-" + e.id.uuidString
		case .placeholder(let d): return "ph-" + d.yyyymmdd
		case .collapsed(_, _, let uuid): return "collapsed-" + uuid.uuidString
		}
	}
}

extension TimelineItem {
	static func == (lhs: TimelineItem, rhs: TimelineItem) -> Bool {
		switch (lhs, rhs) {
		case (.todayEntry(let la), .todayEntry(let ra)):
			return la.id == ra.id
		case (.entry(let la), .entry(let ra)):
			return la.id == ra.id
		case (.placeholder(let ld), .placeholder(let rd)):
			return ld == rd
		case (.collapsed(let lr, let lc, let lid), .collapsed(let rr, let rc, let rid)):
			return lid == rid && lc == rc && lr == rr
		default:
			return false
		}
	}
}

// MARK: - Config & Actions

struct DayTimelineConfig {
	var daysBack: Int = 30
	var collapseThreshold: Int = 14
	var expansionStep: Int = 14
	/// Keep the first N days expanded (newest first), regardless of placeholder run sizes
	var keepHeadCount: Int = 3
	/// If true, apply placeholder run collapsing even within the initial N-day window.
	/// We keep this false by default to match first-ship UX for brand-new users.
	var collapseWithinInitialWindow: Bool = false
}

enum DayTimelineAction {
	case expandCollapsedRun(id: UUID)
}

// MARK: - Generator

struct DayTimelineGenerator {
	/// Generate timeline items for the last N days (newest first), mapping provided entries by user-local day.
	/// - Parameters:
	///   - entries: Known entries (may be sparse). Multiple entries on the same local day are not expected; last one wins if duplicates occur.
	///   - userOffsetMinutes: Minutes from UTC representing the user's local timezone offset.
	///   - config: Tuning parameters for generation and condensation.
	///   - now: Anchor time (defaults to current time); useful for testing.
	static func generate(
		entries: [DiaryEntry],
		userOffsetMinutes: Int,
		config: DayTimelineConfig = .init(),
		now: Date = Date()
	) -> [TimelineItem] {
		let entriesByDay = Self.mapEntriesByLocalDay(entries: entries, userOffsetMinutes: userOffsetMinutes)
		let localDays = Self.buildLastNDays(anchor: now, n: config.daysBack, offsetMinutes: userOffsetMinutes)
		var items: [TimelineItem] = []
		for (index, localDay) in localDays.enumerated() {
			if let entry = entriesByDay[localDay.yyyymmdd] {
				if index == 0 {
					items.append(.todayEntry(entry))
				} else {
					items.append(.entry(entry))
				}
			} else {
				items.append(.placeholder(localDay))
			}
		}
		guard config.collapseWithinInitialWindow else { return items }
		return Self.condensePlaceholders(items: items, threshold: config.collapseThreshold, keepHeadCount: config.keepHeadCount)
	}

	/// Applies a UI action to the timeline, such as expanding a collapsed empty run.
	/// - Parameters:
	///   - action: The user action to apply.
	///   - items: Current timeline items (newest first).
	///   - userOffsetMinutes: Minutes from UTC for local day derivations.
	///   - config: Configuration for expansion step and thresholds.
	///   - entriesByDay: A mapping of `yyyy-MM-dd` -> `DiaryEntry` to fill revealed days with entries when available.
	static func apply(
		_ action: DayTimelineAction,
		to items: [TimelineItem],
		userOffsetMinutes: Int,
		config: DayTimelineConfig = .init(),
		entriesByDay: [String: DiaryEntry]
	) -> [TimelineItem] {
		switch action {
		case .expandCollapsedRun(let targetId):
			return expandCollapsed(items: items, targetId: targetId, step: config.expansionStep, userOffsetMinutes: userOffsetMinutes, entriesByDay: entriesByDay)
		}
	}

	// MARK: - Internal helpers

	private static func mapEntriesByLocalDay(entries: [DiaryEntry], userOffsetMinutes: Int) -> [String: DiaryEntry] {
		var result: [String: DiaryEntry] = [:]
		for entry in entries {
			let key = LocalDayMath.yyyymmdd(for: entry.date, offsetMinutes: userOffsetMinutes)
			result[key] = entry
		}
		return result
	}

	private static func buildLastNDays(anchor: Date, n: Int, offsetMinutes: Int) -> [LocalDay] {
		guard n > 0 else { return [] }
		var days: [LocalDay] = []
		for i in 0..<n {
			let startUTC = LocalDayMath.localDayStartUTC(anchor: anchor, offsetMinutes: offsetMinutes, daysBack: i)
			let key = LocalDayMath.yyyymmdd(for: startUTC, offsetMinutes: offsetMinutes)
			days.append(LocalDay(yyyymmdd: key, startUTC: startUTC))
		}
		return days
	}

	/// Formats a human-readable date range for a local day range using current locale.
	static func formatRange(range: LocalDayRange, offsetMinutes: Int = 0) -> String {
		let startLocal = range.start.startUTC.addingTimeInterval(TimeInterval(offsetMinutes * 60))
		let endLocal = range.end.startUTC.addingTimeInterval(TimeInterval(offsetMinutes * 60))
		let cal = Calendar(identifier: .gregorian)
		let startComps = cal.dateComponents([.year, .month, .day], from: startLocal)
		let endComps = cal.dateComponents([.year, .month, .day], from: endLocal)

		let monthFormatter = DateFormatter()
		monthFormatter.locale = Locale.current
		monthFormatter.setLocalizedDateFormatFromTemplate("MMM")

		let dayFormatter = DateFormatter()
		dayFormatter.locale = Locale.current
		dayFormatter.setLocalizedDateFormatFromTemplate("d")

		let startMonth = monthFormatter.string(from: startLocal)
		let endMonth = monthFormatter.string(from: endLocal)
		let startDay = dayFormatter.string(from: startLocal)
		let endDay = dayFormatter.string(from: endLocal)

		if startComps.year == endComps.year {
			if startComps.month == endComps.month {
				return "\(endMonth) \(startDay)–\(endDay)"
			} else {
				return "\(startMonth) \(startDay)–\(endMonth) \(endDay)"
			}
		} else {
			let yearFormatter = DateFormatter()
			yearFormatter.setLocalizedDateFormatFromTemplate("y")
			let startYear = yearFormatter.string(from: startLocal)
			let endYear = yearFormatter.string(from: endLocal)
			return "\(startMonth) \(startDay), \(startYear)–\(endMonth) \(endDay), \(endYear)"
		}
	}

	/// Collapses long contiguous runs of placeholders to a single `.collapsed` item.
	/// Keeps the first three newest days always expanded.
	private static func condensePlaceholders(items: [TimelineItem], threshold: Int, keepHeadCount: Int) -> [TimelineItem] {
		guard threshold > 0 else { return items }
		guard !items.isEmpty else { return items }

		var result: [TimelineItem] = []
		var index = 0
		let keepHead = min(max(0, keepHeadCount), items.count)
		// Always keep the first up-to-three items as-is
		while index < keepHead {
			result.append(items[index])
			index += 1
		}

		while index < items.count {
			// Identify placeholder run starting at index
			if case .placeholder(let firstDay) = items[index] {
				var runStartIndex = index
				var runEndIndex = index
				var lastDay = firstDay
				while runEndIndex + 1 < items.count {
					if case .placeholder(let day) = items[runEndIndex + 1] {
						lastDay = day
						runEndIndex += 1
					} else { break }
				}
				let runLength = runEndIndex - runStartIndex + 1
				if runLength > threshold {
					let range = LocalDayRange(start: lastDay, end: firstDay) // older..newer within the run
					let primary = "\(runLength) \(runLength == 1 ? "day" : "days"), \(formatRange(range: range))"
					let secondary = "Tap to show \(min(14, runLength)) more days"
					// Use collapsed marker with range metadata; text will be built by the view using helpers if needed
					result.append(.collapsed(range, count: runLength, id: UUID()))
					index = runEndIndex + 1
				} else {
					// Keep small runs expanded
					while runStartIndex <= runEndIndex {
						result.append(items[runStartIndex])
						runStartIndex += 1
					}
					index = runEndIndex + 1
				}
			} else {
				result.append(items[index])
				index += 1
			}
		}
		return result
	}

	private static func expandCollapsed(
		items: [TimelineItem],
		targetId: UUID,
		step: Int,
		userOffsetMinutes: Int,
		entriesByDay: [String: DiaryEntry]
	) -> [TimelineItem] {
		guard step > 0 else { return items }
		var output: [TimelineItem] = []
		for item in items {
			switch item {
			case .collapsed(let range, let count, let id) where id == targetId:
				// Reveal up to `step` most recent days from the collapsed range (i.e., from range.end going older)
				let revealedDays = generateLocalDaysDescending(from: range.end, toOlderInclusive: range.start, limit: step, offsetMinutes: userOffsetMinutes)
				for day in revealedDays {
					if let entry = entriesByDay[day.yyyymmdd] {
						output.append(.entry(entry))
					} else {
						output.append(.placeholder(day))
					}
				}
				let remaining = count - revealedDays.count
				if remaining > 0 {
					// Compute new remaining range: shift the end (newer) towards older by revealedDays.count
					let newEnd = stepLocalDay(range.end, daysBack: revealedDays.count, offsetMinutes: userOffsetMinutes)
					let newRange = LocalDayRange(start: range.start, end: newEnd)
					output.append(.collapsed(newRange, count: remaining, id: id))
				}
			case .todayEntry, .entry, .placeholder, .collapsed:
				output.append(item)
			}
		}
		return output
	}

	/// Generate days from `startNewer` going older down to `toOlderInclusive`, limited by `limit`.
	/// Returns in newest-first order.
	private static func generateLocalDaysDescending(
		from startNewer: LocalDay,
		toOlderInclusive: LocalDay,
		limit: Int,
		offsetMinutes: Int
	) -> [LocalDay] {
		guard limit > 0 else { return [] }
		var days: [LocalDay] = []
		var current = startNewer
		while days.count < limit {
			days.append(current)
			if current == toOlderInclusive { break }
			let next = stepLocalDay(current, daysBack: 1, offsetMinutes: offsetMinutes)
			current = next
		}
		return days
	}

	/// Steps a local day by `daysBack` towards older days.
	private static func stepLocalDay(_ localDay: LocalDay, daysBack: Int, offsetMinutes: Int) -> LocalDay {
		let nextStartUTC = localDay.startUTC.addingTimeInterval(-TimeInterval(86400 * daysBack))
		let key = LocalDayMath.yyyymmdd(for: nextStartUTC, offsetMinutes: offsetMinutes)
		return LocalDay(yyyymmdd: key, startUTC: nextStartUTC)
	}
}


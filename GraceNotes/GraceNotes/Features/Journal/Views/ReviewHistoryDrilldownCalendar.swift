import SwiftUI
import SwiftData

/// One structural row in the continuous drill-down calendar (week rows + month banners).
enum ReviewHistoryDrilldownCalendarRow: Identifiable, Equatable {
    case monthBanner(id: String, title: String)
    case week(id: String, cells: [Date?])

    var id: String {
        switch self {
        case .monthBanner(let id, _):
            return id
        case .week(let id, _):
            return id
        }
    }
}

/// VoiceOver and styling disposition for each day cell in the drill-down grid (issue #186).
enum ReviewHistoryDrilldownDayDisposition: Equatable {
    case matched
    case journalDayNotMatched
    case emptyHistoryDay
    case outsideHistoryWindow

    static func resolve(
        dayStart: Date,
        historyDayRange: Range<Date>,
        journalDaysInHistoryWindow: Set<Date>,
        matchingDayStarts: Set<Date>
    ) -> Self {
        let inHistory = dayStart >= historyDayRange.lowerBound && dayStart < historyDayRange.upperBound
        guard inHistory else {
            return .outsideHistoryWindow
        }
        if matchingDayStarts.contains(dayStart) {
            return .matched
        }
        if journalDaysInHistoryWindow.contains(dayStart) {
            return .journalDayNotMatched
        }
        return .emptyHistoryDay
    }
}

enum ReviewHistoryDrilldownCalendarLayout {
    /// Lower: first day of the month containing the earliest entry; upper: statistics window end (exclusive).
    static func drilldownGridDisplayRange(
        entries: [Journal],
        historyDayRange: Range<Date>,
        calendar: Calendar
    ) -> Range<Date> {
        let upper = historyDayRange.upperBound
        guard let minDate = entries.lazy.map(\.entryDate).min() else {
            return (historyDayRange.lowerBound < upper)
                ? historyDayRange.lowerBound ..< upper
                : historyDayRange
        }
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: minDate)) else {
            return historyDayRange.lowerBound ..< upper
        }
        let lower = calendar.startOfDay(for: firstOfMonth)
        if lower >= upper {
            return historyDayRange.lowerBound ..< upper
        }
        return lower ..< upper
    }

    static func weekdaySymbolsOrdered(calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        let tail = Array(symbols[firstIndex...])
        let head = Array(symbols[..<firstIndex])
        return tail + head
    }

    /// Week row id containing ``dayStart``, if ``dayStart`` appears in a week cell within ``rows``.
    static func weekRowIdContaining(
        dayStart: Date,
        rows: [ReviewHistoryDrilldownCalendarRow],
        calendar: Calendar
    ) -> String? {
        let normalized = calendar.startOfDay(for: dayStart)
        for row in rows {
            guard case .week(let id, let cells) = row else { continue }
            for cell in cells {
                guard let dayDate = cell else { continue }
                if calendar.startOfDay(for: dayDate) == normalized {
                    return id
                }
            }
        }
        return nil
    }

    /// Week-aligned rows from ``displayRange`` (half-open); interleaves month banners at month boundaries.
    static func continuousRows(displayRange: Range<Date>, calendar: Calendar) -> [ReviewHistoryDrilldownCalendarRow] {
        guard let lower = normalizedRangeLower(displayRange: displayRange, calendar: calendar),
              let lastInclusive = normalizedRangeLastInclusive(displayRange: displayRange, calendar: calendar),
              lastInclusive >= lower else { return [] }

        let flat = paddedDayCells(lower: lower, lastInclusive: lastInclusive, calendar: calendar)
        let weeks = chunkIntoWeeks(flat)
        return rowsWithBannersFromWeeks(weeks, calendar: calendar)
    }

    private static func normalizedRangeLower(displayRange: Range<Date>, calendar: Calendar) -> Date? {
        let upperEx = displayRange.upperBound
        let cand = calendar.startOfDay(for: displayRange.lowerBound)
        return upperEx > cand ? cand : nil
    }

    private static func normalizedRangeLastInclusive(displayRange: Range<Date>, calendar: Calendar) -> Date? {
        let upperEx = displayRange.upperBound
        guard let dayBeforeUpper = calendar.date(byAdding: .day, value: -1, to: upperEx) else { return nil }
        return calendar.startOfDay(for: dayBeforeUpper)
    }

    private static func paddedDayCells(lower: Date, lastInclusive: Date, calendar: Calendar) -> [Date?] {
        let firstWeekday = calendar.component(.weekday, from: lower)
        let leadingPad = (firstWeekday - calendar.firstWeekday + 7) % 7
        var flat: [Date?] = Array(repeating: nil, count: leadingPad)
        var cursor = lower
        while cursor <= lastInclusive {
            flat.append(cursor)
            guard let rawNext = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: rawNext)
        }
        while !flat.isEmpty, flat.count % 7 != 0 {
            flat.append(nil)
        }
        return flat
    }

    private static func chunkIntoWeeks(_ flat: [Date?]) -> [[Date?]] {
        var weeks: [[Date?]] = []
        var index = 0
        while index < flat.count {
            let end = min(index + 7, flat.count)
            weeks.append(Array(flat[index..<end]))
            index = end
        }
        return weeks
    }

    /// Month keys in cell order (year-month). Weeks spanning two months yield two specs.
    private static func orderedMonthBannerSpecs(
        for week: [Date?],
        calendar: Calendar
    ) -> [(key: String, monthDate: Date)] {
        var seen = Set<String>()
        var specs: [(String, Date)] = []
        for cell in week {
            guard let date = cell else { continue }
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"
            if seen.insert(key).inserted {
                specs.append((key, date))
            }
        }
        return specs
    }

    private static func rowsWithBannersFromWeeks(
        _ weeks: [[Date?]],
        calendar: Calendar
    ) -> [ReviewHistoryDrilldownCalendarRow] {
        var rows: [ReviewHistoryDrilldownCalendarRow] = []
        var lastBannerMonthKey: String?
        for (weekIndex, week) in weeks.enumerated() {
            let monthSpecs = orderedMonthBannerSpecs(for: week, calendar: calendar)
            for spec in monthSpecs where lastBannerMonthKey != spec.key {
                let title = spec.monthDate.formatted(.dateTime.month(.wide).year())
                rows.append(.monthBanner(id: "banner-\(spec.key)", title: title))
                lastBannerMonthKey = spec.key
            }
            let weekDays = week.compactMap { $0 }
            let weekId: String
            if let first = weekDays.first {
                weekId = "week-\(Int(first.timeIntervalSince1970))-\(weekIndex)"
            } else {
                weekId = "week-pad-\(weekIndex)"
            }
            rows.append(.week(id: weekId, cells: week))
        }
        return rows
    }
}

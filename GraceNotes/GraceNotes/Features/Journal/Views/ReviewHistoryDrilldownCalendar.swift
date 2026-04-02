import SwiftUI
import SwiftData

// Opens ``JournalScreen`` from Past history drill-down calendars (``navigationDestination`` item).
// swiftlint:disable:next type_name
struct ReviewHistoryDrilldownJournalNavigationDay: Identifiable, Hashable {
    let id: String
    let date: Date

    init(dayStart: Date, calendar: Calendar) {
        let normalized = calendar.startOfDay(for: dayStart)
        date = normalized
        let components = calendar.dateComponents([.year, .month, .day], from: normalized)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        id = "\(year)-\(month)-\(day)"
    }
}

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

enum ReviewHistoryDrilldownCalendarLayout {
    /// Lower: first day of the month containing the earliest entry; upper: statistics window end (exclusive).
    static func drilldownGridDisplayRange(
        entries: [JournalEntry],
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

    private static func rowsWithBannersFromWeeks(
        _ weeks: [[Date?]],
        calendar: Calendar
    ) -> [ReviewHistoryDrilldownCalendarRow] {
        var rows: [ReviewHistoryDrilldownCalendarRow] = []
        var lastBannerMonthKey: String?
        for (weekIndex, week) in weeks.enumerated() {
            if let firstDate = week.compactMap({ $0 }).first {
                let year = calendar.component(.year, from: firstDate)
                let month = calendar.component(.month, from: firstDate)
                let key = "\(year)-\(month)"
                if lastBannerMonthKey != key {
                    let title = firstDate.formatted(.dateTime.month(.wide).year())
                    rows.append(.monthBanner(id: "banner-\(key)", title: title))
                    lastBannerMonthKey = key
                }
            }
            let weekId: String
            if let first = week.compactMap({ $0 }).first {
                weekId = "week-\(Int(first.timeIntervalSince1970))-\(weekIndex)"
            } else {
                weekId = "week-pad-\(weekIndex)"
            }
            rows.append(.week(id: weekId, cells: week))
        }
        return rows
    }
}

/// Continuous week grid for Growth / Section drill-downs (week header, month banners, one week per row).
struct ReviewHistoryDrilldownCalendarGrid: View {
    let matchingDayStarts: Set<Date>
    let historyDayRange: Range<Date>
    let displayRange: Range<Date>
    let calendar: Calendar
    let onMatchingDaySelected: (Date) -> Void

    private var rows: [ReviewHistoryDrilldownCalendarRow] {
        ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: displayRange, calendar: calendar)
    }

    private var orderedWeekdaySymbols: [String] {
        ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(AppTheme.warmPaperCaption)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(rows) { row in
                    switch row {
                    case .monthBanner(_, let title):
                        Text(title)
                            .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityAddTraits(.isHeader)
                    case .week(_, let cells):
                        calendarWeekRow(cells: cells)
                    }
                }
            }
        }
    }

    private func calendarWeekRow(cells: [Date?]) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cellDay in
                dayCell(cellDay)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cellDay: Date?) -> some View {
        if let dayStart = cellDay {
            let inWindow = dayStart >= historyDayRange.lowerBound && dayStart < historyDayRange.upperBound
            let isMatch = matchingDayStarts.contains(dayStart)
            let dayNumber = calendar.component(.day, from: dayStart)

            if isMatch {
                Button {
                    onMatchingDaySelected(dayStart)
                } label: {
                    dayNumberLabel(dayNumber: dayNumber, emphasized: true, outsideWindow: !inWindow)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dayStart.formatted(date: .complete, time: .omitted))
                .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
            } else {
                dayNumberLabel(dayNumber: dayNumber, emphasized: false, outsideWindow: !inWindow)
                    .accessibilityHidden(true)
            }
        } else {
            Color.clear
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 36)
                .accessibilityHidden(true)
        }
    }

    private func dayNumberLabel(dayNumber: Int, emphasized: Bool, outsideWindow: Bool) -> some View {
        Text("\(dayNumber)")
            .monospacedDigit()
            .font(emphasized ? AppTheme.warmPaperBody.weight(.semibold) : AppTheme.warmPaperBody)
            .foregroundStyle(labelColor(emphasized: emphasized, outsideWindow: outsideWindow))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 36)
            .background {
                if emphasized {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.reviewPaper.opacity(outsideWindow ? 0.45 : 0.88))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        AppTheme.reviewStandardBorder.opacity(emphasized ? (outsideWindow ? 0.22 : 0.42) : 0),
                        lineWidth: 1
                    )
            }
    }

    private func labelColor(emphasized: Bool, outsideWindow: Bool) -> Color {
        if emphasized {
            return outsideWindow ? AppTheme.reviewTextMuted : AppTheme.reviewTextPrimary
        }
        return outsideWindow ? AppTheme.reviewTextMuted.opacity(0.48) : AppTheme.reviewTextMuted
    }
}

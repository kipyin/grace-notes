import SwiftUI

/// Shared layout for Growth / Section Past drill-downs (issue #178): stacked month grids with matching days emphasized.
enum ReviewHistoryDrilldownCalendarLayout {
    /// First day of each distinct calendar month that appears in `matchingDayStarts`, newest month first.
    static func monthStartsDescending(matchingDayStarts: Set<Date>, calendar: Calendar) -> [Date] {
        var monthStarts: Set<Date> = []
        for day in matchingDayStarts {
            let parts = calendar.dateComponents([.year, .month], from: day)
            guard let first = calendar.date(from: parts) else { continue }
            monthStarts.insert(calendar.startOfDay(for: first))
        }
        return monthStarts.sorted { $0 > $1 }
    }

    /// Leading padding cells + each day in the month as start-of-day; trailing nils pad to a full week row.
    static func dayCellsForMonth(monthStart: Date, calendar: Calendar) -> [Date?] {
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthStart)),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth)
        else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPad = (firstWeekday - calendar.firstWeekday + 7) % 7
        var cells: [Date?] = Array(repeating: nil, count: leadingPad)
        for dayNumber in dayRange {
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: firstOfMonth) else { continue }
            cells.append(calendar.startOfDay(for: date))
        }
        while !cells.isEmpty, cells.count % 7 != 0 {
            cells.append(nil)
        }
        return cells
    }

    static func weekdaySymbolsOrdered(calendar: Calendar) -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        guard !symbols.isEmpty else { return [] }
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        let tail = Array(symbols[firstIndex...])
        let head = Array(symbols[..<firstIndex])
        return tail + head
    }
}

struct ReviewHistoryDrilldownCalendarMonthStack: View {
    let matchingDayStarts: Set<Date>
    let calendar: Calendar
    let historyDayRange: Range<Date>

    private var monthStarts: [Date] {
        ReviewHistoryDrilldownCalendarLayout.monthStartsDescending(
            matchingDayStarts: matchingDayStarts,
            calendar: calendar
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ForEach(monthStarts, id: \.self) { monthStart in
                ReviewHistoryDrilldownMonthCalendar(
                    monthStart: monthStart,
                    matchingDayStarts: matchingDayStarts,
                    calendar: calendar,
                    historyDayRange: historyDayRange
                )
            }
        }
    }
}

private struct ReviewHistoryDrilldownMonthCalendar: View {
    let monthStart: Date
    let matchingDayStarts: Set<Date>
    let calendar: Calendar
    let historyDayRange: Range<Date>

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var cells: [Date?] {
        ReviewHistoryDrilldownCalendarLayout.dayCellsForMonth(monthStart: monthStart, calendar: calendar)
    }

    private var orderedWeekdaySymbols: [String] {
        ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: calendar)
    }

    private let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthTitle)
                .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(AppTheme.warmPaperCaption)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            LazyVGrid(columns: gridColumns, spacing: 6) {
                ForEach(Array(cells.enumerated()), id: \.offset) { index, cellDay in
                    dayCell(cellDay)
                        .id("\(monthStart.timeIntervalSince1970)-\(index)")
                }
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
                NavigationLink {
                    JournalScreen(entryDate: dayStart)
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

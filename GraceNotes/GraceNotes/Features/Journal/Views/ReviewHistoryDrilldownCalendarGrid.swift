import SwiftUI
import SwiftData

// MARK: - Section strip (read-only)

private struct ReviewHistorySectionStripDots: View {
    let filledCount: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<Journal.slotCount, id: \.self) { index in
                let isFilled = index < filledCount
                Circle()
                    .fill(isFilled ? AppTheme.journalComplete : Color.clear)
                    .frame(width: 5, height: 5)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                AppTheme.journalPendingOutline.opacity(isFilled ? 0 : 0.45),
                                lineWidth: 1
                            )
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Grid

// Continuous week grid for Growth / Section drill-downs (week header, month banners, one week per row).
// swiftlint:disable type_body_length
struct ReviewHistoryDrilldownCalendarGrid: View {
    enum Metrics {
        /// Roughly 1.5 months of vertical space for the scrolling region (issue #186).
        static let scrollViewportHeight: CGFloat = 396
    }

    let matchingDayStarts: Set<Date>
    let journalDaysInHistoryWindow: Set<Date>
    let historyDayRange: Range<Date>
    let displayRange: Range<Date>
    let calendar: Calendar
    let growthStageForMatchedDays: JournalCompletionLevel?
    let sectionStripChipCountsByDay: [Date: Int]?
    let onMatchingDaySelected: (Date) -> Void

    private var rows: [ReviewHistoryDrilldownCalendarRow] {
        ReviewHistoryDrilldownCalendarLayout.continuousRows(displayRange: displayRange, calendar: calendar)
    }

    private var orderedWeekdaySymbols: [String] {
        ReviewHistoryDrilldownCalendarLayout.weekdaySymbolsOrdered(calendar: calendar)
    }

    private var calendarDayFeatherMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .black, location: 0.07),
                .init(color: .black, location: 0.93),
                .init(color: .clear, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                String(
                    format: String(localized: "PastDrilldown.calendarWeekdaysRow.a11y"),
                    orderedWeekdaySymbols.joined(separator: ", ")
                )
            )

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(rows) { row in
                            Group {
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
                            .id(row.id)
                        }
                    }
                }
                .frame(maxHeight: Metrics.scrollViewportHeight)
                .mask(calendarDayFeatherMask)
                .onAppear {
                    scrollToLatestMatchIfNeeded(proxy: proxy)
                }
            }
        }
    }

    private func scrollToLatestMatchIfNeeded(proxy: ScrollViewProxy) {
        guard let latest = matchingDayStarts.max(),
              let rowId = ReviewHistoryDrilldownCalendarLayout.weekRowIdContaining(
                dayStart: latest,
                rows: rows,
                calendar: calendar
              )
        else {
            return
        }
        func scroll() {
            proxy.scrollTo(rowId, anchor: UnitPoint(x: 0.5, y: 1.0))
        }
        DispatchQueue.main.async(execute: scroll)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: scroll)
    }

    private func calendarWeekRow(cells: [Date?]) -> some View {
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, cellDay in
                dayCell(cellDay)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ cellDay: Date?) -> some View {
        if let dayStart = cellDay {
            let disposition = ReviewHistoryDrilldownDayDisposition.resolve(
                dayStart: dayStart,
                historyDayRange: historyDayRange,
                journalDaysInHistoryWindow: journalDaysInHistoryWindow,
                matchingDayStarts: matchingDayStarts
            )
            let dayNumber = calendar.component(.day, from: dayStart)
            let dateSpeech = dayStart.formatted(date: .complete, time: .omitted)

            switch disposition {
            case .matched:
                Button {
                    onMatchingDaySelected(dayStart)
                } label: {
                    matchedDayLabel(
                        dayNumber: dayNumber,
                        dayStart: dayStart,
                        disposition: disposition
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(matchedAccessibilityLabel(dateSpeech: dateSpeech))
                .accessibilityHint(String(localized: "ThemeDrilldown.openEntry.a11yHint"))
            default:
                matchedDayLabel(dayNumber: dayNumber, dayStart: dayStart, disposition: disposition)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        nonMatchedAccessibilityLabel(dateSpeech: dateSpeech, disposition: disposition)
                    )
                    .accessibilityHint(nonMatchedAccessibilityHint(disposition: disposition))
            }
        } else {
            Color.clear
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func matchedDayLabel(
        dayNumber: Int,
        dayStart: Date,
        disposition: ReviewHistoryDrilldownDayDisposition
    ) -> some View {
        let stripCount = sectionStripChipCountsByDay?[dayStart]
        let growthLevel = growthStageForMatchedDays
        let showGrowthChrome = disposition == .matched && growthLevel != nil
        let showSectionStrip = disposition == .matched && stripCount != nil

        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("\(dayNumber)")
                    .monospacedDigit()
                    .font(textFont(disposition: disposition, matched: disposition == .matched))
                    .foregroundStyle(textColor(disposition: disposition))

                if showGrowthChrome, let level = growthLevel {
                    ReviewGrowthStageSkylineGlyph(calendarDayCellLevel: level)
                }
            }

            if showSectionStrip, let stripCount {
                ReviewHistorySectionStripDots(filledCount: stripCount)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, showSectionStrip ? 2 : 0)
        .background {
            cellBackground(disposition: disposition, growthLevel: growthLevel)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    cellBorderColor(disposition: disposition, growthLevel: growthLevel),
                    lineWidth: cellBorderWidth(disposition: disposition)
                )
        }
        .shadow(
            color: cellShadow(disposition: disposition, growthLevel: growthLevel),
            radius: 3,
            x: 0,
            y: 1.2
        )
    }

    private func textFont(disposition: ReviewHistoryDrilldownDayDisposition, matched: Bool) -> Font {
        let emphasizes = matched || disposition == .journalDayNotMatched
        return emphasizes ? AppTheme.warmPaperBody.weight(.semibold) : AppTheme.warmPaperBody
    }

    private func textColor(disposition: ReviewHistoryDrilldownDayDisposition) -> Color {
        switch disposition {
        case .matched:
            return AppTheme.reviewTextPrimary
        case .journalDayNotMatched:
            return AppTheme.reviewTextPrimary.opacity(0.92)
        case .emptyHistoryDay:
            return AppTheme.reviewTextMuted.opacity(0.62)
        case .outsideHistoryWindow:
            return AppTheme.reviewTextMuted.opacity(0.48)
        }
    }

    @ViewBuilder
    private func cellBackground(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> some View {
        switch disposition {
        case .matched:
            if let level = growthLevel {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.reviewRhythmPillBackground(for: level))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AppTheme.reviewPaper.opacity(0.88))
            }
        case .journalDayNotMatched:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AppTheme.reviewPaper.opacity(0.42))
        case .emptyHistoryDay, .outsideHistoryWindow:
            EmptyView()
        }
    }

    private func cellBorderColor(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> Color {
        switch disposition {
        case .matched:
            if let level = growthLevel {
                return AppTheme.reviewRhythmPillBorder(for: level)
            }
            return AppTheme.reviewStandardBorder.opacity(0.42)
        case .journalDayNotMatched:
            return AppTheme.reviewStandardBorder.opacity(0.28)
        case .emptyHistoryDay:
            return AppTheme.reviewStandardBorder.opacity(0.12)
        case .outsideHistoryWindow:
            return Color.clear
        }
    }

    private func cellBorderWidth(disposition: ReviewHistoryDrilldownDayDisposition) -> CGFloat {
        switch disposition {
        case .matched, .journalDayNotMatched, .emptyHistoryDay:
            return 1
        case .outsideHistoryWindow:
            return 0
        }
    }

    private func cellShadow(
        disposition: ReviewHistoryDrilldownDayDisposition,
        growthLevel: JournalCompletionLevel?
    ) -> Color {
        guard disposition == .matched, let level = growthLevel else {
            return .clear
        }
        return AppTheme.reviewRhythmPillShadow(for: level)
    }

    private func matchedAccessibilityLabel(dateSpeech: String) -> String {
        String(
            format: String(localized: "PastDrilldown.calendarDay.a11y.matchedFormat"),
            dateSpeech
        )
    }

    private func nonMatchedAccessibilityLabel(
        dateSpeech: String,
        disposition: ReviewHistoryDrilldownDayDisposition
    ) -> String {
        switch disposition {
        case .journalDayNotMatched:
            return String(
                format: String(localized: "PastDrilldown.calendarDay.a11y.journalNotMatchedFormat"),
                dateSpeech
            )
        case .emptyHistoryDay:
            return String(
                format: String(localized: "PastDrilldown.calendarDay.a11y.emptyFormat"),
                dateSpeech
            )
        case .outsideHistoryWindow:
            return String(
                format: String(localized: "PastDrilldown.calendarDay.a11y.outsideRangeFormat"),
                dateSpeech
            )
        case .matched:
            return dateSpeech
        }
    }

    private func nonMatchedAccessibilityHint(disposition: ReviewHistoryDrilldownDayDisposition) -> String {
        switch disposition {
        case .journalDayNotMatched:
            return String(localized: "PastDrilldown.calendarDay.a11yHint.journalNotMatched")
        case .emptyHistoryDay:
            return String(localized: "PastDrilldown.calendarDay.a11yHint.emptyHistoryDay")
        case .outsideHistoryWindow:
            return String(localized: "PastDrilldown.calendarDay.a11yHint.outsideStatisticsRange")
        case .matched:
            return ""
        }
    }
}
// swiftlint:enable type_body_length

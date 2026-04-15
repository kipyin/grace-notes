import Foundation

/// Review insights use the **calendar week** that contains the reference date, as defined by
/// the given ``Calendar``’s `firstWeekday` (for example via
/// ``ReviewWeekBoundaryPreference/configuredCalendar(base:)``).
enum ReviewInsightsPeriod {
    /// The calendar week containing `referenceDate`, as half-open `[lower, upper)` where
    /// `lower` is the start of the week’s first day and `upper` is the start of the day after
    /// the week’s last day (exactly seven local days).
    static func currentPeriod(
        containing referenceDate: Date,
        calendar: Calendar,
        weekExclusiveEnd: ((Date) -> Date?)? = nil,
        weekIntervalForReference: ((Date) -> DateInterval?)? = nil
    ) -> Range<Date> {
        let interval: DateInterval?
        if let override = weekIntervalForReference {
            interval = override(referenceDate)
        } else {
            interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate)
        }
        guard let interval else {
            return rollingSevenDayFallback(containing: referenceDate, calendar: calendar)
        }
        let weekStart = calendar.startOfDay(for: interval.start)
        let exclusiveEnd: Date?
        if let override = weekExclusiveEnd {
            exclusiveEnd = override(weekStart)
        } else {
            exclusiveEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
        }
        if let exclusiveEnd, exclusiveEnd > weekStart {
            return weekStart..<exclusiveEnd
        }
        if interval.end > weekStart {
            return weekStart..<interval.end
        }
        return rollingSevenDayFallback(containing: referenceDate, calendar: calendar)
    }

    /// The calendar week immediately before `current` (the seven local days whose end abuts
    /// `current.lowerBound`).
    static func previousPeriod(before current: Range<Date>, calendar: Calendar) -> Range<Date> {
        // Anchor on the last instant before the current week so `startOfDay` + day offsets match
        // local week boundaries (including across DST). A fixed −604_800s stride is not seven
        // local days when offset changes break the SI-second count between week starts.
        let lastInstantBeforeCurrent = current.lowerBound.addingTimeInterval(-1)
        let lastDayStart = calendar.startOfDay(for: lastInstantBeforeCurrent)
        guard let previousStart = calendar.date(byAdding: .day, value: -6, to: lastDayStart) else {
            let fallback = rollingSevenDayFallback(containing: lastInstantBeforeCurrent, calendar: calendar)
            return fallback.lowerBound..<current.lowerBound
        }
        return previousStart..<current.lowerBound
    }

    private static func rollingSevenDayFallback(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        let endDay = calendar.startOfDay(for: referenceDate)
        let periodEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let periodStart = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        return periodStart..<periodEndExclusive
    }
}

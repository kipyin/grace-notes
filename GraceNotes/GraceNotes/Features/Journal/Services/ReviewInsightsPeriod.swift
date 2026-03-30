import Foundation

/// Review insights use the **calendar week** that contains the reference date, as defined by
/// the given ``Calendar``’s `firstWeekday` (for example via
/// ``ReviewWeekBoundaryPreference/configuredCalendar(base:)``).
enum ReviewInsightsPeriod {
    /// The calendar week containing `referenceDate`, as half-open `[lower, upper)` where
    /// `lower` is the start of the week’s first day and `upper` is the start of the day after
    /// the week’s last day (exactly seven local days).
    static func currentPeriod(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: referenceDate) else {
            return rollingSevenDayFallback(containing: referenceDate, calendar: calendar)
        }
        let weekStart = calendar.startOfDay(for: interval.start)
        guard let periodEndExclusive = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return weekStart..<interval.end
        }
        return weekStart..<periodEndExclusive
    }

    /// The calendar week immediately before `current` (the seven local days whose end abuts
    /// `current.lowerBound`).
    static func previousPeriod(before current: Range<Date>, calendar: Calendar) -> Range<Date> {
        let previousStart = calendar.date(byAdding: .day, value: -7, to: current.lowerBound)
            ?? current.lowerBound
        return previousStart..<current.lowerBound
    }

    private static func rollingSevenDayFallback(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        let endDay = calendar.startOfDay(for: referenceDate)
        let periodEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let periodStart = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        return periodStart..<periodEndExclusive
    }
}

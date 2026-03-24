import Foundation

/// Review insights use **seven calendar days** ending on the reference day (not ISO/calendar week).
enum ReviewInsightsPeriod {
    /// Seven local days ending on `referenceDate`'s day: from `startOfDay(ref) − 6` through end of that day,
    /// as half-open `[lower, upper)`.
    static func currentPeriod(containing referenceDate: Date, calendar: Calendar) -> Range<Date> {
        let endDay = calendar.startOfDay(for: referenceDate)
        let periodEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
        let periodStart = calendar.date(byAdding: .day, value: -6, to: endDay) ?? endDay
        return periodStart..<periodEndExclusive
    }

    /// The seven calendar days immediately before `current.lowerBound`.
    static func previousPeriod(before current: Range<Date>, calendar: Calendar) -> Range<Date> {
        let previousStart = calendar.date(byAdding: .day, value: -7, to: current.lowerBound)
            ?? current.lowerBound
        return previousStart..<current.lowerBound
    }
}

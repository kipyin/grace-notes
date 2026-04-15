import Foundation
import os

private let reviewWeekTrendPolicyLogger = Logger(
    subsystem: Bundle(for: PersistenceController.self).bundleIdentifier ?? "GraceNotes",
    category: "ReviewWeekTrendPolicy"
)

/// Calendar-week trend surfacing: warm-up (first two local days of the week) plus balanced floors.
enum ReviewWeekTrendPolicy {
    /// First two days of the configured week (`firstWeekday` … +1 day).
    private static let warmUpDayRange = 0..<2

    /// Whether `referenceDate` falls on the first or second local day of `currentPeriod`.
    static func isWarmUpPhase(currentPeriod: Range<Date>, referenceDate: Date, calendar: Calendar) -> Bool {
        guard currentPeriod.lowerBound < currentPeriod.upperBound else {
            return false
        }
        let weekStart = calendar.startOfDay(for: currentPeriod.lowerBound)
        let refDay = calendar.startOfDay(for: referenceDate)
        guard refDay >= weekStart, refDay < currentPeriod.upperBound else {
            return false
        }
        guard let dayOffset = calendar.dateComponents([.day], from: weekStart, to: refDay).day,
              dayOffset >= 0 else {
            return false
        }
        return warmUpDayRange.contains(dayOffset)
    }

    /// Raw week-over-week direction from mention counts (before confidence / floors).
    static func rawTrend(current: Int, previous: Int) -> ReviewThemeTrend {
        guard current >= 0, previous >= 0 else {
            reviewWeekTrendPolicyLogger.warning(
                "Negative mention counts in rawTrend (current=\(current, privacy: .public), previous=\(previous, privacy: .public))"
            )
            return .stable
        }
        if previous == 0, current > 0 {
            return .new
        }
        if current > previous {
            return .rising
        }
        if current < previous {
            return .down
        }
        return .stable
    }

    /// Trend for **Trending** after warm-up rules and balanced floors; otherwise `.stable`.
    static func trendingSurfacingTrend(current: Int, previous: Int, isWarmUpPhase: Bool) -> ReviewThemeTrend {
        let raw = rawTrend(current: current, previous: previous)
        switch raw {
        case .stable:
            return .stable
        case .new:
            guard current >= 2 else { return .stable }
            return .new
        case .rising:
            guard current >= 2, current > previous else { return .stable }
            return .rising
        case .down:
            if isWarmUpPhase {
                guard previous >= 3, current == 0 else { return .stable }
            } else {
                guard previous >= 3, current < previous else { return .stable }
            }
            return .down
        }
    }
}

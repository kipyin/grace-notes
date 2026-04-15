import Foundation

/// Stable key for when the visible reflection-rhythm **columns** change.
///
/// Used to reset trailing-edge scroll pinning after a real dataset change, without clearing user scroll when
/// `ReviewInsights` is regenerated for the same week with the same per-day rhythm payload (#131).
///
/// Equality matches **week anchor + ordered calendar day columns** only: `ReviewSummaryCard` renders one column per
/// `days` element, so horizontal extent is driven by ``weekStart``, ``days.count``, and each paired day’s
/// ``ReviewDayActivity/date``.
/// Fields that affect only cell content (``ReviewDayActivity/hasReflectiveActivity``,
/// ``ReviewDayActivity/hasPersistedEntry``, ``ReviewDayActivity/strongestCompletionLevel``) are ignored so pin state
/// does not reset when those values refresh without layout changes.
///
/// If new fields are added to ``ReviewDayActivity`` that affect column count or width, extend this comparison
/// accordingly.
struct ReviewRhythmScrollPinIdentity: Equatable {
    let weekStart: Date
    let days: [ReviewDayActivity]

    static func == (lhs: ReviewRhythmScrollPinIdentity, rhs: ReviewRhythmScrollPinIdentity) -> Bool {
        guard lhs.weekStart == rhs.weekStart, lhs.days.count == rhs.days.count else { return false }
        return zip(lhs.days, rhs.days).allSatisfy { left, right in
            left.date == right.date
        }
    }
}

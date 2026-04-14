import Foundation

/// Stable key for when the visible reflection-rhythm **columns** change.
///
/// Used to reset trailing-edge scroll pinning after a real dataset change, without clearing user scroll when
/// `ReviewInsights` is regenerated for the same week with the same per-day rhythm payload (#131).
///
/// Equality ignores ``ReviewDayActivity/strongestCompletionLevel``: it only affects which growth-stage row is
/// highlighted, not column count or horizontal extent, so recomputing completion staging must not reset pin state.
struct ReviewRhythmScrollPinIdentity: Equatable {
    let weekStart: Date
    let days: [ReviewDayActivity]

    static func == (lhs: ReviewRhythmScrollPinIdentity, rhs: ReviewRhythmScrollPinIdentity) -> Bool {
        guard lhs.weekStart == rhs.weekStart, lhs.days.count == rhs.days.count else { return false }
        return zip(lhs.days, rhs.days).allSatisfy { left, right in
            left.date == right.date
                && left.hasReflectiveActivity == right.hasReflectiveActivity
                && left.hasPersistedEntry == right.hasPersistedEntry
        }
    }
}

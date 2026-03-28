import Foundation

/// Stable key for when the visible reflection-rhythm **columns** change.
///
/// Used to reset trailing-edge scroll pinning after a real dataset change, without clearing user scroll when
/// `ReviewInsights` is regenerated for the same week with the same per-day rhythm payload (#131).
struct ReviewRhythmScrollPinIdentity: Equatable {
    let weekStart: Date
    let days: [ReviewDayActivity]
}

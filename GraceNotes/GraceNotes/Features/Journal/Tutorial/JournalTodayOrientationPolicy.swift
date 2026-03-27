import Foundation

/// Read-only policy for **Today-only** orientation: when to present the post-Seed journey and when to
/// suppress the Seed unlock toast so it does not stack with that full-screen flow.
///
/// **Product matrix (summary):**
/// - **Today, not yet seen C:** At or above **Seed**, show the post-Seed journey once. Skip the
///   congratulations page when `completedGuidedJournal` is already true (user already knows the sections).
/// - **Dated entry** (`entryDate != nil`), **UI tests:** No post-Seed presentation from this policy.
///
/// **Dual completion:** Guided first entry can end by reaching **Abundance** on Today
/// (`JournalScreen.syncGuidedJournalCompletionIfNeeded`) or by finishing the post-Seed journey
/// (`JournalScreen.completePostSeedJourney`). Both set `completedGuidedJournal`.
enum JournalTodayOrientationPolicy {

    struct Inputs: Equatable {
        /// `true` when `JournalScreen` shows Today's entry (`entryDate == nil`).
        var isTodayEntry: Bool
        var isRunningUITests: Bool
        var hasSeenPostSeedJourney: Bool
        var hasCompletedGuidedJournal: Bool
        var completionLevel: JournalCompletionLevel
    }

    /// - Returns: Outcome when the full-screen post-Seed journey should be presented; `nil` otherwise.
    static func postSeedJourneyOutcome(for inputs: Inputs) -> PostSeedJourneyTrigger.Outcome? {
        guard inputs.isTodayEntry else { return nil }
        guard !inputs.isRunningUITests else { return nil }
        return PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: inputs.hasSeenPostSeedJourney,
            hasCompletedGuidedJournal: inputs.hasCompletedGuidedJournal,
            todayCompletionLevel: inputs.completionLevel
        )
    }

    /// Suppress the Seed unlock toast on rank-up into **Seed** when the post-Seed journey has not been
    /// seen yet (avoids stacking with the full-screen flow).
    static func shouldSuppressSeedUnlockToast(
        isTodayEntry: Bool,
        newLevel: JournalCompletionLevel,
        hasSeenPostSeedJourney: Bool,
        milestoneHighlight: JournalUnlockMilestoneHighlight
    ) -> Bool {
        guard milestoneHighlight == .none else { return false }
        guard isTodayEntry, newLevel == .started, !hasSeenPostSeedJourney else { return false }
        return true
    }
}

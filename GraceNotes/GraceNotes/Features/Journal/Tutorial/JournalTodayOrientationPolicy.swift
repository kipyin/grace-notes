import Foundation

/// Read-only policy for **Today-only** orientation: when to present the post-Seed journey and when to
/// suppress the Seed unlock toast so it does not stack with that full-screen flow.
///
/// **Product matrix (summary):**
/// - **Today, not yet seen C:** After **1/1/1** (at least one chip in gratitudes, needs, and people), show the
///   post-Seed journey once. Skip the congratulations page when `completedGuidedJournal` is already true.
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
        var hasAtLeastOneInEachChipSection: Bool
    }

    /// - Returns: Outcome when the full-screen post-Seed journey should be presented; `nil` otherwise.
    static func postSeedJourneyOutcome(for inputs: Inputs) -> PostSeedJourneyTrigger.Outcome? {
        guard inputs.isTodayEntry else { return nil }
        guard !inputs.isRunningUITests else { return nil }
        return PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: inputs.hasSeenPostSeedJourney,
            hasCompletedGuidedJournal: inputs.hasCompletedGuidedJournal,
            hasAtLeastOneInEachChipSection: inputs.hasAtLeastOneInEachChipSection
        )
    }

    /// Suppress the generic **Started** unlock toast when Post-Seed is about to present at **1/1/1** (avoids
    /// stacking with the full-screen flow). The first chip alone still shows the toast.
    static func shouldSuppressSeedUnlockToast(
        isTodayEntry: Bool,
        newLevel: JournalCompletionLevel,
        hasSeenPostSeedJourney: Bool,
        milestoneHighlight: JournalUnlockMilestoneHighlight,
        hasAtLeastOneInEachChipSection: Bool
    ) -> Bool {
        guard milestoneHighlight == .none else { return false }
        guard isTodayEntry, newLevel == .started, !hasSeenPostSeedJourney else { return false }
        guard hasAtLeastOneInEachChipSection else { return false }
        return true
    }
}

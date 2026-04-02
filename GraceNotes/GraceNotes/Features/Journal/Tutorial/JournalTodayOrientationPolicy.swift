import Foundation

/// Read-only policy for **Today-only** orientation: when to present the App Tour and when to
/// suppress the Sprout unlock toast so it does not stack with that full-screen flow.
///
/// **Product matrix (summary):**
/// - **Today, not yet seen tour:** After **1/1/1** (at least one line in gratitudes, needs, and people), show the
///   App Tour once. Skip the congratulations page when `completedGuidedJournal` is already true.
/// - **Dated entry** (`entryDate != nil`), **UI tests:** No App Tour presentation from this policy.
///
/// **Dual completion:** Guided first entry can end by filling all fifteen strips on Today
/// (`JournalScreen.syncGuidedJournalCompletionIfNeeded`) or by finishing the App Tour
/// (`JournalScreen.completeAppTour`). Both set `completedGuidedJournal`.
enum JournalTodayOrientationPolicy {

    struct Inputs: Equatable {
        /// `true` when `JournalScreen` shows Today (`entryDate == nil`).
        var isTodayEntry: Bool
        var isRunningUITests: Bool
        var hasSeenAppTour: Bool
        var hasCompletedGuidedJournal: Bool
        var hasAtLeastOneInEachChipSection: Bool
    }

    /// - Returns: Outcome when the full-screen App Tour should be presented; `nil` otherwise.
    static func appTourOutcome(for inputs: Inputs) -> AppTourTrigger.Outcome? {
        guard inputs.isTodayEntry else { return nil }
        guard !inputs.isRunningUITests else { return nil }
        return AppTourTrigger.evaluate(
            hasSeenAppTour: inputs.hasSeenAppTour,
            hasCompletedGuidedJournal: inputs.hasCompletedGuidedJournal,
            hasAtLeastOneInEachChipSection: inputs.hasAtLeastOneInEachChipSection
        )
    }

    /// Suppress the generic **Started** unlock toast when the App Tour is about to present at **1/1/1** (avoids
    /// stacking with the full-screen flow). The first line alone still shows the toast.
    static func shouldSuppressSeedUnlockToast(
        isTodayEntry: Bool,
        newLevel: JournalCompletionLevel,
        hasSeenAppTour: Bool,
        milestoneHighlight: JournalUnlockMilestoneHighlight,
        hasAtLeastOneInEachChipSection: Bool
    ) -> Bool {
        guard milestoneHighlight == .none else { return false }
        guard isTodayEntry, newLevel == .sprout, !hasSeenAppTour else { return false }
        guard hasAtLeastOneInEachChipSection else { return false }
        return true
    }
}

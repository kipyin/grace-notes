import Foundation

/// Read-only policy for **Today-only** orientation: when to present the App Tour and when to
/// suppress Sprout-stage unlock feedback (toast + celebration in ``JournalScreen``) so it does not
/// stack with that full-screen flow at **1/1/1**, including the first-triple-one milestone toast.
///
/// **Product matrix (summary):**
/// - **Today, not yet seen tour:** After **1/1/1** (at least one line in gratitudes, needs, and people), show the
///   App Tour once. Skip the congratulations page when `completedGuidedJournal` is already true.
/// - **Dated entry** (`entryDate != nil`), **UI tests:** No App Tour presentation from this policy.
///
/// **Dual completion:** Guided first entry can end by filling all fifteen entry rows on Today
/// (`JournalScreen.syncGuidedJournalCompletionIfNeeded`) or by finishing the App Tour
/// (`JournalScreen.completeAppTour`). Both set `completedGuidedJournal`.
enum JournalTodayOrientationPolicy {

    struct Inputs: Equatable {
        /// `true` when `JournalScreen` shows Today (`entryDate == nil`).
        var isTodayEntry: Bool
        var isRunningUITests: Bool
        var hasSeenAppTour: Bool
        var hasCompletedGuidedJournal: Bool
        var hasAtLeastOneEntryInEachSection: Bool
    }

    /// - Returns: Outcome when the full-screen App Tour should be presented; `nil` otherwise.
    static func appTourOutcome(for inputs: Inputs) -> AppTourTrigger.Outcome? {
        guard inputs.isTodayEntry else { return nil }
        guard !inputs.isRunningUITests else { return nil }
        return AppTourTrigger.evaluate(
            hasSeenAppTour: inputs.hasSeenAppTour,
            hasCompletedGuidedJournal: inputs.hasCompletedGuidedJournal,
            hasAtLeastOneEntryInEachSection: inputs.hasAtLeastOneEntryInEachSection
        )
    }

    /// Suppress Sprout-stage unlock toast (and matching header celebration) when the App Tour is about to
    /// present at **1/1/1**—for both the generic rank-up case and the first 1/1/1 milestone highlight.
    /// The first line alone in a section still shows feedback (`hasAtLeastOneEntryInEachSection` is false).
    ///
    /// Tour eligibility (Today, not UI tests, 1/1/1, not yet seen) is delegated to ``appTourOutcome(for:)``
    /// so it cannot drift from `AppTourTrigger.evaluate`. ``Inputs/hasCompletedGuidedJournal`` only affects
    /// congratulations skipping inside the tour, not whether suppression applies.
    static func shouldSuppressSproutUnlockToast(
        newLevel: JournalCompletionLevel,
        milestoneHighlight: JournalUnlockMilestoneHighlight,
        orientationInputs: Inputs
    ) -> Bool {
        switch milestoneHighlight {
        case .none, .firstOneOneOne:
            break
        case .firstBalanced, .firstFull:
            return false
        }
        guard newLevel == .sprout else { return false }
        return appTourOutcome(for: orientationInputs) != nil
    }

    /// Bridge for call sites that pass orientation fields separately (for example ``JournalScreen``), using
    /// the same app-wide defaults for UITesting and guided-journal completion as a fully specified ``Inputs``.
    static func shouldSuppressSproutUnlockToast(
        isTodayEntry: Bool,
        newLevel: JournalCompletionLevel,
        hasSeenAppTour: Bool,
        milestoneHighlight: JournalUnlockMilestoneHighlight,
        hasAtLeastOneEntryInEachSection: Bool
    ) -> Bool {
        let guidedDone = UserDefaults.standard.bool(
            forKey: JournalOnboardingStorageKeys.completedGuidedJournal
        )
        let orientationInputs = Inputs(
            isTodayEntry: isTodayEntry,
            isRunningUITests: ProcessInfo.graceNotesIsRunningUITests,
            hasSeenAppTour: hasSeenAppTour,
            hasCompletedGuidedJournal: guidedDone,
            hasAtLeastOneEntryInEachSection: hasAtLeastOneEntryInEachSection
        )
        return shouldSuppressSproutUnlockToast(
            newLevel: newLevel,
            milestoneHighlight: milestoneHighlight,
            orientationInputs: orientationInputs
        )
    }
}

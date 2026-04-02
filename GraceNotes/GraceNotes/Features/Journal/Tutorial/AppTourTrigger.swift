import Foundation

/// Pure policy for when the full-screen App Tour appears on Today (see `JournalScreen`).
enum AppTourTrigger {
    struct Outcome {
        var skipsCongratulationsPage: Bool
    }

    /// - Returns: `nil` when the tour should not be presented.
    ///
    /// The App Tour runs once each section has at least one item (1/1/1 minimum). ``JournalCompletionLevel``
    /// does not distinguish (1,0,0) from (1,1,1), so callers pass ``Journal``/view-model strip counts via
    /// `hasAtLeastOneInEachChipSection`.
    static func evaluate(
        hasSeenAppTour: Bool,
        hasCompletedGuidedJournal: Bool,
        hasAtLeastOneInEachChipSection: Bool
    ) -> Outcome? {
        guard !hasSeenAppTour else { return nil }
        guard hasAtLeastOneInEachChipSection else { return nil }

        let skipsCongratulationsPage = hasCompletedGuidedJournal
        return Outcome(skipsCongratulationsPage: skipsCongratulationsPage)
    }
}

import Foundation

/// Pure policy for when the full-screen post-Seed orientation appears on Today (see `JournalScreen`).
enum PostSeedJourneyTrigger {
    struct Outcome {
        var skipsCongratulationsPage: Bool
    }

    /// - Returns: `nil` when the journey should not be presented.
    ///
    /// Post-Seed runs once each chip section has at least one item (1/1/1 minimum). ``JournalCompletionLevel``
    /// does not distinguish (1,0,0) from (1,1,1), so callers pass ``JournalEntry``/view-model chip counts via
    /// `hasAtLeastOneInEachChipSection`.
    static func evaluate(
        hasSeenPostSeedJourney: Bool,
        hasCompletedGuidedJournal: Bool,
        hasAtLeastOneInEachChipSection: Bool
    ) -> Outcome? {
        guard !hasSeenPostSeedJourney else { return nil }
        guard hasAtLeastOneInEachChipSection else { return nil }

        let skipsCongratulationsPage = hasCompletedGuidedJournal
        return Outcome(skipsCongratulationsPage: skipsCongratulationsPage)
    }
}

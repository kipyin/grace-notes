import Foundation

/// Pure policy for when the full-screen post-Seed orientation appears on Today (see `JournalScreen`).
enum PostSeedJourneyTrigger {
    struct Outcome {
        var skipsCongratulationsPage: Bool
    }

    /// - Returns: `nil` when the journey should not be presented.
    static func evaluate(
        hasSeenPostSeedJourney: Bool,
        hasCompletedGuidedJournal: Bool,
        todayCompletionLevel: JournalCompletionLevel
    ) -> Outcome? {
        guard !hasSeenPostSeedJourney else { return nil }

        let startedRank = JournalCompletionLevel.started.tutorialCompletionRank
        guard todayCompletionLevel.tutorialCompletionRank >= startedRank else { return nil }

        let skipsCongratulationsPage = hasCompletedGuidedJournal
        return Outcome(skipsCongratulationsPage: skipsCongratulationsPage)
    }
}

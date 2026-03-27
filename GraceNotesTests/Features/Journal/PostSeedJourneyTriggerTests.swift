import XCTest
@testable import GraceNotes

final class PostSeedJourneyTriggerTests: XCTestCase {
    func test_evaluate_whenAlreadySeen_returnsNil() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: true,
            hasCompletedGuidedJournal: true,
            todayCompletionLevel: .started
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_atStarted_guidedIncomplete_showsWithCongratulations() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .started
        )
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_belowStarted_neverShows() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .empty
        )
        XCTAssertNil(outcome)
    }

    /// Version-free C: at or above Started with journey not yet seen presents regardless of “upgrade cohort.”
    func test_evaluate_atFull_notSeenPostSeed_showsJourney_documentsVersionFreeContract() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .full
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_atOrAboveStarted_guidedIncomplete_showsWithCongratulations() {
        for level in [JournalCompletionLevel.started, .growing, .balanced, .full] {
            let outcome = PostSeedJourneyTrigger.evaluate(
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: false,
                todayCompletionLevel: level
            )
            XCTAssertEqual(
                outcome?.skipsCongratulationsPage,
                false,
                "level \(level) should show congrats when guided incomplete"
            )
        }
    }

    func test_evaluate_atOrAboveStarted_guidedComplete_skipsCongratulations() {
        for level in [JournalCompletionLevel.started, .growing, .balanced, .full] {
            let outcome = PostSeedJourneyTrigger.evaluate(
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: true,
                todayCompletionLevel: level
            )
            XCTAssertEqual(
                outcome?.skipsCongratulationsPage,
                true,
                "level \(level) should skip congrats when guided complete"
            )
        }
    }
}

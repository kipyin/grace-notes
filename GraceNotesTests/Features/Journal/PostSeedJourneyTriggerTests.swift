import XCTest
@testable import GraceNotes

final class PostSeedJourneyTriggerTests: XCTestCase {
    func test_evaluate_whenAlreadySeen_returnsNil() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: true,
            hasCompletedGuidedJournal: true,
            todayCompletionLevel: .seed
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_atSeed_guidedIncomplete_showsWithCongratulations() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .seed
        )
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_belowSeed_neverShows() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .soil
        )
        XCTAssertNil(outcome)
    }

    /// Version-free C: at or above Seed with journey not yet seen presents regardless of “upgrade cohort.”
    func test_evaluate_atHarvest_notSeenPostSeed_showsJourney_documentsVersionFreeContract() {
        let outcome = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: false,
            todayCompletionLevel: .harvest
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_atOrAboveSeed_guidedIncomplete_showsWithCongratulations() {
        for level in [JournalCompletionLevel.seed, .ripening, .harvest, .abundance] {
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

    func test_evaluate_atOrAboveSeed_guidedComplete_skipsCongratulations() {
        for level in [JournalCompletionLevel.seed, .ripening, .harvest, .abundance] {
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

import XCTest
@testable import GraceNotes

final class AppTourTriggerTests: XCTestCase {
    func test_evaluate_whenAlreadySeen_returnsNil() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: true,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneEntryInEachSection: true
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_whenNotTripleOne_neverShows_evenIfLevelsWouldBeStartedOrHigher() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: false,
            hasAtLeastOneEntryInEachSection: false
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_whenTripleOne_notSeenPostSeed_showsJourneyWithCongratulations() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: false,
            hasAtLeastOneEntryInEachSection: true
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_whenTripleOne_guidedComplete_skipsCongratulations() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneEntryInEachSection: true
        )
        XCTAssertEqual(outcome?.skipsCongratulationsPage, true)
    }
}

import XCTest
@testable import GraceNotes

final class AppTourTriggerTests: XCTestCase {
    func test_evaluate_whenAlreadySeen_returnsNil() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: true,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneInEachChipSection: true
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_whenNotTripleOne_neverShows_evenIfLevelsWouldBeStartedOrHigher() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: false,
            hasAtLeastOneInEachChipSection: false
        )
        XCTAssertNil(outcome)
    }

    func test_evaluate_whenTripleOne_notSeenPostSeed_showsJourneyWithCongratulations() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: false,
            hasAtLeastOneInEachChipSection: true
        )
        XCTAssertNotNil(outcome)
        XCTAssertEqual(outcome?.skipsCongratulationsPage, false)
    }

    func test_evaluate_whenTripleOne_guidedComplete_skipsCongratulations() {
        let outcome = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneInEachChipSection: true
        )
        XCTAssertEqual(outcome?.skipsCongratulationsPage, true)
    }
}

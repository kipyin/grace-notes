import XCTest
@testable import GraceNotes

final class JournalTodayOrientationPolicyTests: XCTestCase {

    // MARK: - appTourOutcome

    func test_appTourOutcome_whenNotToday_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.appTourOutcome(
            for: .init(
                isTodayEntry: false,
                isRunningUITests: false,
                hasSeenAppTour: false,
                hasCompletedGuidedJournal: false,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertNil(outcome)
    }

    func test_appTourOutcome_whenUITests_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.appTourOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: true,
                hasSeenAppTour: false,
                hasCompletedGuidedJournal: false,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertNil(outcome)
    }

    func test_appTourOutcome_delegatesToPostSeedTrigger_whenTodayAndNotUITests() {
        let expected = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneInEachChipSection: true
        )
        let actual = JournalTodayOrientationPolicy.appTourOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenAppTour: false,
                hasCompletedGuidedJournal: true,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertEqual(actual?.skipsCongratulationsPage, expected?.skipsCongratulationsPage)
    }

    func test_appTourOutcome_whenNotTripleOne_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.appTourOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenAppTour: false,
                hasCompletedGuidedJournal: false,
                hasAtLeastOneInEachChipSection: false
            )
        )
        XCTAssertNil(outcome)
    }

    // MARK: - shouldSuppressSeedUnlockToast

    func test_shouldSuppressSeedUnlockToast_todayAtStarted_tripleOne_notSeenPostSeed_suppresses() {
        XCTAssertTrue(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_todayAtStarted_firstChipOnly_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: false
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_notToday_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: false,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_nonStartedLevel_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .twig,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_alreadySeenPostSeed_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: true,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_milestoneWithStarted_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .firstOneOneOne,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }
}

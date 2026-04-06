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
                hasAtLeastOneEntryInEachSection: true
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
                hasAtLeastOneEntryInEachSection: true
            )
        )
        XCTAssertNil(outcome)
    }

    func test_appTourOutcome_delegatesToPostSeedTrigger_whenTodayAndNotUITests() {
        let expected = AppTourTrigger.evaluate(
            hasSeenAppTour: false,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneEntryInEachSection: true
        )
        let actual = JournalTodayOrientationPolicy.appTourOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenAppTour: false,
                hasCompletedGuidedJournal: true,
                hasAtLeastOneEntryInEachSection: true
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
                hasAtLeastOneEntryInEachSection: false
            )
        )
        XCTAssertNil(outcome)
    }

    // MARK: - shouldSuppressSproutUnlockToast

    func test_shouldSuppressSproutUnlockToast_todayAtStarted_tripleOne_notSeenTour_suppresses() {
        XCTAssertTrue(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_todayAtStarted_firstEntryOnly_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneEntryInEachSection: false
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_notToday_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: false,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_nonSproutLevel_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .twig,
                hasSeenAppTour: false,
                milestoneHighlight: .none,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_alreadySeenTour_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: true,
                milestoneHighlight: .none,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_firstOneOneOne_tripleOne_notSeenTour_suppresses() {
        XCTAssertTrue(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .firstOneOneOne,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_firstOneOneOne_seenTour_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: true,
                milestoneHighlight: .firstOneOneOne,
                hasAtLeastOneEntryInEachSection: true
            )
        )
    }

    func test_shouldSuppressSproutUnlockToast_firstOneOneOne_firstEntryOnly_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
                isTodayEntry: true,
                newLevel: .sprout,
                hasSeenAppTour: false,
                milestoneHighlight: .firstOneOneOne,
                hasAtLeastOneEntryInEachSection: false
            )
        )
    }
}

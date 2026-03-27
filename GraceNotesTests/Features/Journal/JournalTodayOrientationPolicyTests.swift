import XCTest
@testable import GraceNotes

final class JournalTodayOrientationPolicyTests: XCTestCase {

    // MARK: - postSeedJourneyOutcome

    func test_postSeedJourneyOutcome_whenNotToday_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: .init(
                isTodayEntry: false,
                isRunningUITests: false,
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: false,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertNil(outcome)
    }

    func test_postSeedJourneyOutcome_whenUITests_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: true,
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: false,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertNil(outcome)
    }

    func test_postSeedJourneyOutcome_delegatesToPostSeedTrigger_whenTodayAndNotUITests() {
        let expected = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: true,
            hasAtLeastOneInEachChipSection: true
        )
        let actual = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: true,
                hasAtLeastOneInEachChipSection: true
            )
        )
        XCTAssertEqual(actual?.skipsCongratulationsPage, expected?.skipsCongratulationsPage)
    }

    func test_postSeedJourneyOutcome_whenNotTripleOne_returnsNil() {
        let outcome = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenPostSeedJourney: false,
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
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_todayAtStarted_firstChipOnly_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: false
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_notToday_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: false,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_nonStartedLevel_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .growing,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_alreadySeenPostSeed_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: true,
                milestoneHighlight: .none,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_milestoneWithStarted_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .firstOneOneOne,
                hasAtLeastOneInEachChipSection: true
            )
        )
    }
}

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
                completionLevel: .started
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
                completionLevel: .started
            )
        )
        XCTAssertNil(outcome)
    }

    func test_postSeedJourneyOutcome_delegatesToPostSeedTrigger_whenTodayAndNotUITests() {
        let expected = PostSeedJourneyTrigger.evaluate(
            hasSeenPostSeedJourney: false,
            hasCompletedGuidedJournal: true,
            todayCompletionLevel: .growing
        )
        let actual = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: .init(
                isTodayEntry: true,
                isRunningUITests: false,
                hasSeenPostSeedJourney: false,
                hasCompletedGuidedJournal: true,
                completionLevel: .growing
            )
        )
        XCTAssertEqual(actual?.skipsCongratulationsPage, expected?.skipsCongratulationsPage)
    }

    // MARK: - shouldSuppressSeedUnlockToast

    func test_shouldSuppressSeedUnlockToast_todayAtStarted_notSeenPostSeed_suppresses() {
        XCTAssertTrue(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_notToday_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: false,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_nonStartedLevel_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .growing,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .none
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_alreadySeenPostSeed_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: true,
                milestoneHighlight: .none
            )
        )
    }

    func test_shouldSuppressSeedUnlockToast_milestoneWithStarted_doesNotSuppress() {
        XCTAssertFalse(
            JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                isTodayEntry: true,
                newLevel: .started,
                hasSeenPostSeedJourney: false,
                milestoneHighlight: .firstOneOneOne
            )
        )
    }
}

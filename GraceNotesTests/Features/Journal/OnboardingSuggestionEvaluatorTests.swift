import XCTest
@testable import GraceNotes

final class OnboardingSuggestionEvaluatorTests: XCTestCase {
    func test_currentSuggestion_nonNilEntryDate_returnsNil() {
        let context = baseContext(entryDate: .now)

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_tripleOneCelebrated_reminderEligible_returnsReminders() {
        var context = baseContext(entryDate: nil)
        context.hasCelebratedFirstTripleOne = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .reminders)
    }

    func test_currentSuggestion_remindersAndFullMet_remindersWins() {
        var context = baseContext(entryDate: nil)
        context.hasCelebratedFirstTripleOne = true
        context.hasCelebratedFirstBloom = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .reminders)
    }

    func test_currentSuggestion_remindersSatisfied_iCloudEligible_returnsICloudSync() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCompletedGuidedJournal = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .iCloudSync)
    }

    func test_currentSuggestion_iCloudEligibleButSyncOn_returnsNil() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCompletedGuidedJournal = true
        context.isICloudSyncEnabled = true

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_guidanceActive_returnsNilEvenWhenRemindersEligible() {
        var context = baseContext(entryDate: nil)
        context.hasCelebratedFirstTripleOne = true
        context.isGuidanceActive = true

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_guidanceActive_returnsNilEvenWhenICloudEligible() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCompletedGuidedJournal = true
        context.isGuidanceActive = true

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_afterAppTourCompletionDismissals_returnsNilOnToday() {
        let context = JournalOnboardingSuggestionContext(
            entryDate: nil,
            hasCelebratedFirstTripleOne: true,
            hasCelebratedFirstBloom: true,
            dismissedRemindersSuggestion: true,
            openedRemindersSuggestion: false,
            hasConfiguredReminderTime: false,
            hasCompletedGuidedJournal: true,
            dismissedICloudSuggestion: true,
            openedICloudSuggestion: false,
            isICloudSyncEnabled: false,
            isGuidanceActive: false
        )

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    private func baseContext(entryDate: Date?) -> JournalOnboardingSuggestionContext {
        JournalOnboardingSuggestionContext(
            entryDate: entryDate,
            hasCelebratedFirstTripleOne: false,
            hasCelebratedFirstBloom: false,
            dismissedRemindersSuggestion: false,
            openedRemindersSuggestion: false,
            hasConfiguredReminderTime: false,
            hasCompletedGuidedJournal: false,
            dismissedICloudSuggestion: false,
            openedICloudSuggestion: false,
            isICloudSyncEnabled: false,
            isGuidanceActive: false
        )
    }
}

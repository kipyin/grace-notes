import XCTest
@testable import GraceNotes

final class OnboardingSuggestionEvaluatorTests: XCTestCase {
    func test_currentSuggestion_nonNilEntryDate_returnsNil() {
        let context = baseContext(entryDate: .now)

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_seedCelebrated_reminderEligible_returnsReminders() {
        var context = baseContext(entryDate: nil)
        context.hasCelebratedFirstSeed = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .reminders)
    }

    func test_currentSuggestion_remindersAndHarvestMet_remindersWins() {
        var context = baseContext(entryDate: nil)
        context.hasCelebratedFirstSeed = true
        context.hasCelebratedFirstHarvest = true
        context.isCloudApiKeyConfigured = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .reminders)
    }

    func test_currentSuggestion_remindersSatisfied_aiEligible_returnsAIFeatures() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCelebratedFirstHarvest = true
        context.isCloudApiKeyConfigured = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .aiFeatures)
    }

    func test_currentSuggestion_aiSatisfied_iCloudEligible_returnsICloudSync() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.dismissedAISuggestion = true
        context.hasCompletedGuidedJournal = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .iCloudSync)
    }

    func test_currentSuggestion_iCloudEligibleButSyncOn_returnsNil() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.dismissedAISuggestion = true
        context.hasCompletedGuidedJournal = true
        context.isICloudSyncEnabled = true

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    private func baseContext(entryDate: Date?) -> JournalOnboardingSuggestionContext {
        JournalOnboardingSuggestionContext(
            entryDate: entryDate,
            hasCelebratedFirstSeed: false,
            hasCelebratedFirstHarvest: false,
            dismissedRemindersSuggestion: false,
            openedRemindersSuggestion: false,
            hasConfiguredReminderTime: false,
            dismissedAISuggestion: false,
            openedAISuggestion: false,
            aiFeaturesEnabled: false,
            isCloudApiKeyConfigured: false,
            hasCompletedGuidedJournal: false,
            dismissedICloudSuggestion: false,
            openedICloudSuggestion: false,
            isICloudSyncEnabled: false
        )
    }
}

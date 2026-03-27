import XCTest
@testable import GraceNotes

final class OnboardingSuggestionEvaluatorTests: XCTestCase {
    private var originalCloudAIUserFacingEnabled: Bool!

    override func setUp() {
        super.setUp()
        originalCloudAIUserFacingEnabled = AppFeatureFlags.cloudAIUserFacingEnabled
        AppFeatureFlags.cloudAIUserFacingEnabled = false
    }

    override func tearDown() {
        AppFeatureFlags.cloudAIUserFacingEnabled = originalCloudAIUserFacingEnabled
        originalCloudAIUserFacingEnabled = nil
        super.tearDown()
    }

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
        context.hasCelebratedFirstFull = true
        context.isCloudApiKeyConfigured = true

        XCTAssertEqual(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context), .reminders)
    }

    func test_currentSuggestion_remindersSatisfied_aiEligible_returnsNilWhenFeatureFlagOff() {
        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCelebratedFirstFull = true
        context.isCloudApiKeyConfigured = true

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    func test_currentSuggestion_remindersSatisfied_aiEligible_returnsAIFeaturesWhenFeatureFlagOn() {
        AppFeatureFlags.cloudAIUserFacingEnabled = true

        var context = baseContext(entryDate: nil)
        context.hasConfiguredReminderTime = true
        context.hasCelebratedFirstFull = true
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

    func test_currentSuggestion_afterAppTourCompletionDismissals_returnsNilOnToday() {
        let context = JournalOnboardingSuggestionContext(
            entryDate: nil,
            hasCelebratedFirstTripleOne: true,
            hasCelebratedFirstFull: true,
            dismissedRemindersSuggestion: true,
            openedRemindersSuggestion: false,
            hasConfiguredReminderTime: false,
            dismissedAISuggestion: true,
            openedAISuggestion: false,
            aiFeaturesEnabled: false,
            isCloudApiKeyConfigured: true,
            hasCompletedGuidedJournal: true,
            dismissedICloudSuggestion: true,
            openedICloudSuggestion: false,
            isICloudSyncEnabled: false
        )

        XCTAssertNil(JournalOnboardingSuggestionEvaluator.currentSuggestion(context: context))
    }

    private func baseContext(entryDate: Date?) -> JournalOnboardingSuggestionContext {
        JournalOnboardingSuggestionContext(
            entryDate: entryDate,
            hasCelebratedFirstTripleOne: false,
            hasCelebratedFirstFull: false,
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

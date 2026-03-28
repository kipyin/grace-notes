import Foundation

/// Inputs needed to decide which milestone Settings suggestion (if any) applies on Today.
struct JournalOnboardingSuggestionContext: Equatable {
    var entryDate: Date?
    var hasCelebratedFirstTripleOne: Bool
    var hasCelebratedFirstFull: Bool
    var dismissedRemindersSuggestion: Bool
    var openedRemindersSuggestion: Bool
    var hasConfiguredReminderTime: Bool
    var hasCompletedGuidedJournal: Bool
    var dismissedICloudSuggestion: Bool
    var openedICloudSuggestion: Bool
    var isICloudSyncEnabled: Bool
}

enum JournalOnboardingSuggestionEvaluator {
    /// Single source of truth for milestone suggestion priority (Reminders → AI → iCloud).
    static func currentSuggestion(context: JournalOnboardingSuggestionContext) -> JournalOnboardingSuggestion? {
        guard context.entryDate == nil else { return nil }

        if context.hasCelebratedFirstTripleOne,
           !context.dismissedRemindersSuggestion,
           !context.openedRemindersSuggestion,
           !context.hasConfiguredReminderTime {
            return .reminders
        }

        if context.hasCompletedGuidedJournal,
           !context.dismissedICloudSuggestion,
           !context.openedICloudSuggestion,
           !context.isICloudSyncEnabled {
            return .iCloudSync
        }

        return nil
    }
}

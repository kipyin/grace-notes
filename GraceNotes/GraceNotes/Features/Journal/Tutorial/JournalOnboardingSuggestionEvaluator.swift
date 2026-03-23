import Foundation

/// Inputs needed to decide which milestone Settings suggestion (if any) applies on Today.
struct JournalOnboardingSuggestionContext: Equatable {
    var entryDate: Date?
    var hasCelebratedFirstSeed: Bool
    var hasCelebratedFirstHarvest: Bool
    var dismissedRemindersSuggestion: Bool
    var openedRemindersSuggestion: Bool
    var hasConfiguredReminderTime: Bool
    var dismissedAISuggestion: Bool
    var openedAISuggestion: Bool
    var aiFeaturesEnabled: Bool
    var isCloudApiKeyConfigured: Bool
    var hasCompletedGuidedJournal: Bool
    var dismissedICloudSuggestion: Bool
    var openedICloudSuggestion: Bool
    var isICloudSyncEnabled: Bool
}

enum JournalOnboardingSuggestionEvaluator {
    /// Single source of truth for milestone suggestion priority (Reminders → AI → iCloud).
    static func currentSuggestion(context: JournalOnboardingSuggestionContext) -> JournalOnboardingSuggestion? {
        guard context.entryDate == nil else { return nil }

        if context.hasCelebratedFirstSeed,
           !context.dismissedRemindersSuggestion,
           !context.openedRemindersSuggestion,
           !context.hasConfiguredReminderTime {
            return .reminders
        }

        if context.hasCelebratedFirstHarvest,
           !context.dismissedAISuggestion,
           !context.openedAISuggestion,
           !context.aiFeaturesEnabled,
           context.isCloudApiKeyConfigured {
            return .aiFeatures
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

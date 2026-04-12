import Foundation
import SwiftData

enum ReminderNotificationBodyBuilder {
    /// Builds the notification body for the repeating daily reminder at ``reminderTime``.
    static func localizedBody(
        modelContext: ModelContext,
        reminderTime: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> String {
        let repository = JournalRepository(calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        let entries = try repository.fetchAllEntries(context: modelContext)
        let gapDays = ReminderNotificationBodySelector.calendarDayGapSinceLastMeaningfulEntry(
            entries: entries,
            todayStart: todayStart,
            calendar: calendar
        )
        let isLapse = ReminderNotificationBodySelector.isLapse(gapDays: gapDays)

        let timeBucket = ReminderNotificationBodySelector.timeBucket(
            forReminderTime: reminderTime,
            calendar: calendar
        )

        if isLapse {
            // `completion` / `streakBucket` are unused when `isLapse` is true (`localizationKey` returns early).
            let key = ReminderNotificationBodySelector.localizationKey(
                isLapse: true,
                completion: .empty,
                timeBucket: timeBucket,
                streakBucket: .none
            )
            return String(localized: String.LocalizationValue(key))
        }

        let calculator = StreakCalculator(calendar: calendar)
        let todayEntry = try repository.fetchEntry(for: now, context: modelContext)
        let completion = ReminderNotificationBodySelector.completionFamily(for: todayEntry)

        let summary = JournalStreakSummaryRefresher.loadSummary(
            calculator: calculator,
            entries: entries,
            now: now
        )
        let streakBucket: ReminderNotificationBodySelector.StreakBucket
        switch completion {
        case .empty, .inProgress:
            streakBucket = ReminderNotificationBodySelector.streakBucketBasic(
                streakLength: summary.basicCurrent
            )
        case .complete:
            streakBucket = ReminderNotificationBodySelector.streakBucketPerfect(
                streakLength: summary.perfectCurrent
            )
        }

        let key = ReminderNotificationBodySelector.localizationKey(
            isLapse: false,
            completion: completion,
            timeBucket: timeBucket,
            streakBucket: streakBucket
        )
        return String(localized: String.LocalizationValue(key))
    }
}

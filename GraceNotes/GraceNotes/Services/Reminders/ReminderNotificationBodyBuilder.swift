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
            let key = ReminderNotificationBodySelector.localizationKey(
                isLapse: true,
                completion: .empty,
                timeBucket: timeBucket,
                streakBucket: .none
            )
            return String(localized: String.LocalizationValue(key))
        }

        return nonLapseLocalizedBody(
            entries: entries,
            todayStart: todayStart,
            timeBucket: timeBucket,
            now: now,
            calendar: calendar
        )
    }

    private static func nonLapseLocalizedBody(
        entries: [Journal],
        todayStart: Date,
        timeBucket: ReminderNotificationBodySelector.TimeBucket,
        now: Date,
        calendar: Calendar
    ) -> String {
        let calculator = StreakCalculator(calendar: calendar)
        let completion = completionFamilyForToday(
            entries: entries,
            todayStart: todayStart,
            calendar: calendar
        )

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

    /// Aggregates completion across every journal row for ``todayStart`` so copy matches
    /// the per-day OR semantics in ``StreakCalculator``. A single canonical row from
    /// ``JournalRepository/fetchEntry`` can disagree when multiple rows exist for one calendar day.
    private static func completionFamilyForToday(
        entries: [Journal],
        todayStart: Date,
        calendar: Calendar
    ) -> ReminderNotificationBodySelector.CompletionFamily {
        let todayJournals = entries.filter { calendar.startOfDay(for: $0.entryDate) == todayStart }
        if todayJournals.contains(where: { $0.hasReachedBloom }) {
            return .complete
        }
        if todayJournals.contains(where: { $0.hasMeaningfulContent }) {
            return .inProgress
        }
        return .empty
    }
}

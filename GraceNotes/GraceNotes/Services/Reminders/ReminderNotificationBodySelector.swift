import Foundation

/// Chooses a localized string table key for the daily journal reminder body.
/// Pure logic — keep testable without SwiftData or UserNotifications.
enum ReminderNotificationBodySelector {
    enum CompletionFamily: Equatable {
        case empty
        case inProgress
        case complete
    }

    enum TimeBucket: Equatable {
        case morning
        case afternoon
        case evening
    }

    enum StreakBucket: Equatable {
        case none
        case some
        case steady
    }

    static func localizationKey(
        isLapse: Bool,
        completion: CompletionFamily,
        timeBucket: TimeBucket,
        streakBucket: StreakBucket
    ) -> String {
        if isLapse {
            return lapseKey(timeBucket: timeBucket)
        }

        let streakSuffix = streakBucket.rawSuffix
        switch completion {
        case .empty:
            return "notifications.reminder.body.empty.\(timeBucket.rawSegment).\(streakSuffix)"
        case .inProgress:
            return "notifications.reminder.body.inProgress.\(timeBucket.rawSegment).\(streakSuffix)"
        case .complete:
            return "notifications.reminder.body.complete.\(timeBucket.rawSegment).\(streakSuffix)"
        }
    }

    static func timeBucket(forReminderTime reminderTime: Date, calendar: Calendar) -> TimeBucket {
        let hour = calendar.component(.hour, from: reminderTime)
        switch hour {
        case 5..<12:
            return .morning
        case 12..<17:
            return .afternoon
        default:
            return .evening
        }
    }

    /// Streak used for ``empty`` and ``inProgress`` families (`basicCurrent`).
    static func streakBucketBasic(streakLength: Int) -> StreakBucket {
        switch streakLength {
        case ...0:
            return .none
        case 1...6:
            return .some
        default:
            return .steady
        }
    }

    /// Streak used for ``complete`` family (`perfectCurrent`).
    static func streakBucketPerfect(streakLength: Int) -> StreakBucket {
        streakBucketBasic(streakLength: streakLength)
    }

    /// Calendar-day gap from the last meaningful journal day to ``todayStart``.
    /// Returns `nil` when there was never meaningful content.
    /// The result is always non-negative: future-dated entries (``lastDay`` after ``todayStart``)
    /// yield `0` instead of a negative component.
    static func calendarDayGapSinceLastMeaningfulEntry(
        entries: [Journal],
        todayStart: Date,
        calendar: Calendar
    ) -> Int? {
        var latestMeaningfulDay: Date?
        for entry in entries where entry.hasMeaningfulContent {
            let day = calendar.startOfDay(for: entry.entryDate)
            if latestMeaningfulDay.map({ day > $0 }) ?? true {
                latestMeaningfulDay = day
            }
        }
        guard let lastDay = latestMeaningfulDay else { return nil }
        let rawDay = calendar.dateComponents([.day], from: lastDay, to: todayStart).day ?? 0
        return max(0, rawDay)
    }

    /// True when we should use welcoming-back copy (requires a prior meaningful day and
    /// a gap of at least ``minimumGapDays`` calendar days).
    ///
    /// Non-positive ``minimumGapDays`` is invalid configuration and never yields a lapse
    /// (avoids treating `gapDays == 0` as a lapse when the threshold is zero).
    static func isLapse(
        gapDays: Int?,
        minimumGapDays: Int = 3
    ) -> Bool {
        guard let gapDays else { return false }
        guard minimumGapDays > 0 else { return false }
        return gapDays >= minimumGapDays
    }

    static func completionFamily(for entry: Journal?) -> CompletionFamily {
        guard let entry else { return .empty }
        if entry.hasReachedBloom {
            return .complete
        }
        if entry.hasMeaningfulContent {
            return .inProgress
        }
        return .empty
    }

    private static func lapseKey(timeBucket: TimeBucket) -> String {
        "notifications.reminder.body.lapse.\(timeBucket.rawSegment)"
    }
}

private extension ReminderNotificationBodySelector.StreakBucket {
    var rawSuffix: String {
        switch self {
        case .none: "none"
        case .some: "some"
        case .steady: "steady"
        }
    }
}

private extension ReminderNotificationBodySelector.TimeBucket {
    var rawSegment: String {
        switch self {
        case .morning: "morning"
        case .afternoon: "afternoon"
        case .evening: "evening"
        }
    }
}

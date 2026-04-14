import Foundation

extension ReviewInsights {
    /// Sample payload for the App Tour so ``ReviewDaysYouWrotePanel`` matches the live Past tab layout.
    static func appTourTutorialPreview(
        calendar: Calendar = ReviewWeekBoundaryPreference.defaultValue.configuredCalendar(),
        referenceDate: Date = .now
    ) -> ReviewInsights {
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let weekStats = appTourTutorialWeekStats(calendar: calendar, reviewWeek: period)
        let weeklyInsight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: String(localized: "tutorial.appTour.sampleInsights.row1.observation"),
            action: String(localized: "tutorial.appTour.sampleInsights.row1.action"),
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: nil
        )
        return ReviewInsights(
            source: .deterministic,
            presentationMode: .insight,
            generatedAt: referenceDate,
            weekStart: period.lowerBound,
            weekEnd: period.upperBound,
            weeklyInsights: [weeklyInsight],
            recurringGratitudes: [],
            recurringNeeds: [],
            recurringPeople: [],
            resurfacingMessage: "",
            continuityPrompt: "",
            narrativeSummary: nil,
            weekStats: weekStats
        )
    }

    /// Uses the same seven-day window as ``ReviewInsightsPeriod/currentPeriod(containing:calendar:)`` so sample
    /// rhythm columns align with ``weekStart``/``weekEnd`` and with live ``WeeklyReviewAggregatesBuilder`` output.
    private static func appTourTutorialWeekStats(calendar: Calendar, reviewWeek: Range<Date>) -> ReviewWeekStats {
        let levels: [JournalCompletionLevel] = [.sprout, .twig, .leaf, .bloom, .soil, .sprout, .twig]
        var days: [ReviewDayActivity] = []
        var dayStart = calendar.startOfDay(for: reviewWeek.lowerBound)
        var offset = 0
        while dayStart < reviewWeek.upperBound, offset < levels.count {
            let level = levels[offset]
            days.append(
                ReviewDayActivity(
                    date: dayStart,
                    hasReflectiveActivity: true,
                    strongestCompletionLevel: level == .soil ? nil : level,
                    hasPersistedEntry: true
                )
            )
            offset += 1
            guard let nextRaw = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = calendar.startOfDay(for: nextRaw)
        }
        let mix = ReviewWeekCompletionMix(
            soilDayCount: 1,
            sproutDayCount: 2,
            twigDayCount: 2,
            leafDayCount: 1,
            bloomDayCount: 1
        )
        let sectionTotals = ReviewWeekSectionTotals(gratitudeMentions: 3, needMentions: 2, peopleMentions: 2)
        return ReviewWeekStats(
            reflectionDays: 7,
            meaningfulEntryCount: 7,
            completionMix: mix,
            activity: days,
            rhythmHistory: days,
            sectionTotals: sectionTotals,
            historySectionTotals: sectionTotals,
            historyCompletionMix: mix
        )
    }
}

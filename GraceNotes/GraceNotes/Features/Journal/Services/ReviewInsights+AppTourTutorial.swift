import Foundation

extension ReviewInsights {
    /// Sample payload for the App Tour so ``ReviewDaysYouWrotePanel`` matches the live Past tab layout.
    static func appTourTutorialPreview(
        calendar: Calendar = ReviewWeekBoundaryPreference.defaultValue.configuredCalendar(),
        referenceDate: Date = .now
    ) -> ReviewInsights {
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let weekStats = appTourTutorialWeekStats(calendar: calendar, referenceDate: referenceDate)
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

    private static func appTourTutorialWeekStats(calendar: Calendar, referenceDate: Date) -> ReviewWeekStats {
        let refStart = calendar.startOfDay(for: referenceDate)
        let windowLower = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: -6, to: refStart) ?? refStart
        )
        let levels: [JournalCompletionLevel] = [.sprout, .twig, .leaf, .bloom, .soil, .sprout, .twig]
        let days: [ReviewDayActivity] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: windowLower) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let level = levels[offset]
            return ReviewDayActivity(
                date: dayStart,
                hasReflectiveActivity: true,
                strongestCompletionLevel: level == .soil ? nil : level,
                hasPersistedEntry: true
            )
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
            reflectionDays: 5,
            meaningfulEntryCount: 5,
            completionMix: mix,
            activity: days,
            rhythmHistory: days,
            sectionTotals: sectionTotals,
            historySectionTotals: sectionTotals,
            historyCompletionMix: mix
        )
    }
}

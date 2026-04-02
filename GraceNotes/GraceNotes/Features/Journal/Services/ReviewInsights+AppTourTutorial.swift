import Foundation

extension ReviewInsights {
    /// Sample payload for the App Tour so ``ReviewDaysYouWrotePanel`` matches the live Past tab layout.
    static func appTourTutorialPreview(
        calendar: Calendar = ReviewWeekBoundaryPreference.defaultValue.configuredCalendar(),
        referenceDate: Date = .now
    ) -> ReviewInsights {
        let period = ReviewInsightsPeriod.currentPeriod(containing: referenceDate, calendar: calendar)
        let levels: [JournalCompletionLevel] = [.sprout, .twig, .leaf, .bloom, .soil, .sprout, .twig]
        let days: [ReviewDayActivity] = (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: period.lowerBound) else { return nil }
            let dayStart = calendar.startOfDay(for: date)
            let level = levels[offset]
            return ReviewDayActivity(
                date: dayStart,
                hasReflectiveActivity: level != .soil,
                strongestCompletionLevel: level == .soil ? nil : level,
                hasPersistedEntry: false
            )
        }
        let mix = ReviewWeekCompletionMix(emptyDays: 1, startedDays: 2, growingDays: 2, balancedDays: 1, fullDays: 1)
        let sectionTotals = ReviewWeekSectionTotals(gratitudeMentions: 3, needMentions: 2, peopleMentions: 2)
        let weekStats = ReviewWeekStats(
            reflectionDays: 5,
            meaningfulEntryCount: 5,
            completionMix: mix,
            activity: days,
            rhythmHistory: days,
            sectionTotals: sectionTotals,
            historySectionTotals: sectionTotals,
            historyCompletionMix: mix
        )
        let weeklyInsight = ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: String(localized: "AppTour.sampleInsights.row1.observation"),
            action: String(localized: "AppTour.sampleInsights.row1.action"),
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
}

import Foundation

extension WeeklyInsightCandidateBuilder {
    func fullCompletionCandidate(
        entries: [Journal],
        calendar: Calendar
    ) -> InsightCandidate? {
        guard !entries.isEmpty else { return nil }

        var completionByDay: [Date: Bool] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            completionByDay[day] = (completionByDay[day] ?? false) || entry.hasReachedBloom
        }

        guard completionByDay.count == 7 else { return nil }
        guard completionByDay.values.allSatisfy({ $0 }) else { return nil }

        let insight = ReviewWeeklyInsight(
            pattern: .fullCompletion,
            observation: String(
                localized: "review.insights.steadyRhythm15"
            ),
            action: String(
                localized: "review.prompts.steadyCarry"
            ),
            primaryTheme: nil,
            mentionCount: 7,
            dayCount: 7
        )
        return InsightCandidate(score: 120, insight: insight)
    }

    func recurringPeopleCandidate(from people: [ThemeSummary]) -> InsightCandidate? {
        guard let topPerson = people.first(where: { $0.dayCount >= 2 || $0.mentionCount >= 2 }) else {
            return nil
        }

        let insight = ReviewWeeklyInsight(
            pattern: .recurringPeople,
            observation: renderLocalizedDayCountTemplate(
                "review.insights.recurringPeople.observation",
                dayCount: topPerson.dayCount,
                replacements: [
                    ("%1$@", topPerson.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "review.insights.recurringPeople.action",
                replacements: [
                    ("%@", topPerson.displayLabel),
                    ("%1$@", topPerson.displayLabel)
                ]
            ),
            primaryTheme: topPerson.displayLabel,
            mentionCount: topPerson.mentionCount,
            dayCount: topPerson.dayCount
        )
        let score = topPerson.dayCount * 7 + topPerson.mentionCount * 2
        return InsightCandidate(score: score, insight: insight)
    }

    func recurringThemeCandidate(
        needs: [ThemeSummary],
        gratitudes: [ThemeSummary]
    ) -> InsightCandidate? {
        let topNeed = needs.first(where: { $0.dayCount >= 2 || $0.mentionCount >= 2 })
        let topGratitude = gratitudes.first(where: { $0.dayCount >= 2 || $0.mentionCount >= 2 })

        guard let chosen = strongerTheme(need: topNeed, gratitude: topGratitude) else {
            return nil
        }

        if chosen.isNeed {
            return recurringThemeNeedInsightCandidate(theme: chosen.theme)
        }
        return recurringThemeGratitudeInsightCandidate(theme: chosen.theme)
    }

    private func recurringThemeNeedInsightCandidate(theme: ThemeSummary) -> InsightCandidate {
        let insight = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: renderLocalizedDayCountTemplate(
                "review.insights.recurringTheme.need.observation",
                dayCount: theme.dayCount,
                replacements: [
                    ("%1$@", theme.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "review.insights.recurringTheme.need.action",
                replacements: [
                    ("%@", theme.displayLabel),
                    ("%1$@", theme.displayLabel)
                ]
            ),
            primaryTheme: theme.displayLabel,
            mentionCount: theme.mentionCount,
            dayCount: theme.dayCount
        )
        let score = theme.dayCount * 6 + theme.mentionCount * 2
        return InsightCandidate(score: score, insight: insight)
    }

    private func recurringThemeGratitudeInsightCandidate(theme: ThemeSummary) -> InsightCandidate {
        let insight = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: renderLocalizedDayCountTemplate(
                "review.insights.recurringTheme.gratitude.observation",
                dayCount: theme.dayCount,
                replacements: [
                    ("%1$@", theme.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "review.insights.recurringTheme.gratitude.action",
                replacements: [
                    ("%@", theme.displayLabel),
                    ("%1$@", theme.displayLabel)
                ]
            ),
            primaryTheme: theme.displayLabel,
            mentionCount: theme.mentionCount,
            dayCount: theme.dayCount
        )
        let score = theme.dayCount * 6 + theme.mentionCount
        return InsightCandidate(score: score, insight: insight)
    }

    func needsGratitudeGapCandidate(
        needs: [ThemeSummary],
        gratitudes: [ThemeSummary]
    ) -> InsightCandidate? {
        let gratitudeKeys = Set(gratitudes.map(\.normalizedLabel))
        guard let topNeedWithoutMatch = needs.first(where: {
            ($0.dayCount >= 2 || $0.mentionCount >= 2) &&
                !textNormalizer.themesMatch($0.normalizedLabel, against: gratitudeKeys)
        }) else {
            return nil
        }

        let insight = ReviewWeeklyInsight(
            pattern: .needsGratitudeGap,
            observation: renderLocalizedTemplate(
                "review.insights.needsGratitudeGap.observation",
                replacements: [
                    ("%@", topNeedWithoutMatch.displayLabel),
                    ("%1$@", topNeedWithoutMatch.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "review.insights.needsGratitudeGap.action",
                replacements: [
                    ("%@", topNeedWithoutMatch.displayLabel),
                    ("%1$@", topNeedWithoutMatch.displayLabel)
                ]
            ),
            primaryTheme: topNeedWithoutMatch.displayLabel,
            mentionCount: topNeedWithoutMatch.mentionCount,
            dayCount: topNeedWithoutMatch.dayCount
        )
        let score = topNeedWithoutMatch.dayCount * 8 + topNeedWithoutMatch.mentionCount * 3 + 6
        return InsightCandidate(score: score, insight: insight)
    }

    func continuityShiftCandidate(
        currentThemes: [ThemeSummary],
        previousThemes: [ThemeSummary]
    ) -> InsightCandidate? {
        guard let currentTop = currentThemes.first else { return nil }
        guard let previousTop = previousThemes.first else { return nil }
        guard currentTop.weightedScore >= 8, previousTop.weightedScore >= 6 else { return nil }
        guard currentTop.normalizedLabel != previousTop.normalizedLabel else { return nil }

        let insight = ReviewWeeklyInsight(
            pattern: .continuityShift,
            observation: renderLocalizedTemplate(
                "review.insights.continuityShift.observation",
                replacements: [
                    ("%1$@", previousTop.displayLabel),
                    ("%2$@", currentTop.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "review.insights.continuityShift.action",
                replacements: [
                    ("%@", currentTop.displayLabel),
                    ("%1$@", currentTop.displayLabel)
                ]
            ),
            primaryTheme: currentTop.displayLabel,
            mentionCount: currentTop.mentionCount,
            dayCount: currentTop.dayCount
        )
        let score = currentTop.weightedScore + previousTop.weightedScore + 8
        return InsightCandidate(score: score, insight: insight)
    }

    func strongerTheme(
        need: ThemeSummary?,
        gratitude: ThemeSummary?
    ) -> (theme: ThemeSummary, isNeed: Bool)? {
        switch (need, gratitude) {
        case (.none, .none):
            return nil
        case let (.some(need), .none):
            return (need, true)
        case let (.none, .some(gratitude)):
            return (gratitude, false)
        case let (.some(need), .some(gratitude)):
            if need.dayCount != gratitude.dayCount {
                return need.dayCount > gratitude.dayCount ? (need, true) : (gratitude, false)
            }
            if need.mentionCount != gratitude.mentionCount {
                return need.mentionCount > gratitude.mentionCount ? (need, true) : (gratitude, false)
            }
            let ordering = need.displayLabel.localizedCaseInsensitiveCompare(gratitude.displayLabel)
            return ordering != .orderedDescending ? (need, true) : (gratitude, false)
        }
    }

    func compareCandidates(_ lhs: InsightCandidate, _ rhs: InsightCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }

        let lhsPriority = patternPriority(lhs.insight.pattern)
        let rhsPriority = patternPriority(rhs.insight.pattern)
        if lhsPriority != rhsPriority {
            return lhsPriority > rhsPriority
        }

        let lhsTheme = lhs.insight.primaryTheme ?? ""
        let rhsTheme = rhs.insight.primaryTheme ?? ""
        let themeOrdering = lhsTheme.localizedCaseInsensitiveCompare(rhsTheme)
        if themeOrdering != .orderedSame {
            return themeOrdering == .orderedAscending
        }

        return lhs.insight.observation.localizedCaseInsensitiveCompare(rhs.insight.observation) == .orderedAscending
    }

    func patternPriority(_ pattern: ReviewWeeklyInsightPattern) -> Int {
        switch pattern {
        case .needsGratitudeGap:
            return 6
        case .continuityShift:
            return 5
        case .recurringPeople:
            return 4
        case .recurringTheme:
            return 3
        case .fullCompletion:
            return 2
        case .sparseFallback:
            return 1
        }
    }

    func shouldSkip(
        _ candidate: ReviewWeeklyInsight,
        becauseOf selected: [ReviewWeeklyInsight]
    ) -> Bool {
        guard let theme = candidate.primaryTheme?.lowercased() else { return false }
        return selected.contains { selectedInsight in
            let selectedTheme = selectedInsight.primaryTheme?.lowercased()
            return selectedTheme == theme &&
                selectedInsight.pattern != .fullCompletion &&
                candidate.pattern != .fullCompletion
        }
    }

    func isSparseWeek(entries: [Journal], reflectionDayCount: Int) -> Bool {
        guard !entries.isEmpty else { return true }
        if reflectionDayCount >= 2 {
            return false
        }

        let totalChips = entries.reduce(0) { partialResult, entry in
            partialResult + (entry.gratitudes ?? []).count + (entry.needs ?? []).count + (entry.people ?? []).count
        }
        let totalLongText = entries.reduce(0) { partialResult, entry in
            partialResult
                + textNormalizer.trimmed(entry.readingNotes).count
                + textNormalizer.trimmed(entry.reflections).count
        }

        return totalChips <= 2 && totalLongText < 40
    }

    func renderLocalizedTemplate(
        _ key: String,
        replacements: [(token: String, value: String)]
    ) -> String {
        var message = String(localized: String.LocalizationValue(key))
        for replacement in replacements {
            message = message.replacingOccurrences(of: replacement.token, with: replacement.value)
        }
        return message
    }

    func renderLocalizedDayCountTemplate(
        _ key: String,
        dayCount: Int,
        replacements: [(token: String, value: String)] = []
    ) -> String {
        var updatedReplacements = replacements
        let dayCountText = dayCount.formatted()
        updatedReplacements.append(("%lld", dayCountText))
        updatedReplacements.append(("%2$lld", dayCountText))

        var message = renderLocalizedTemplate(key, replacements: updatedReplacements)
        let dayUnit = dayCount == 1
            ? String(localized: "common.timeUnit.day")
            : String(localized: "common.timeUnit.days")
        message = message.replacingOccurrences(of: "day(s)", with: dayUnit)
        return message
    }
}

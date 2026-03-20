import Foundation

// swiftlint:disable file_length function_body_length
struct WeeklyInsightCandidateBuilder {
    let defaultContinuityPrompt = String(
        localized: "What feels most important to carry into next week?"
    )

    private let maxInsights = 2
    private let textNormalizer: WeeklyInsightTextNormalizer

    init(textNormalizer: WeeklyInsightTextNormalizer) {
        self.textNormalizer = textNormalizer
    }

    func buildCandidates(inputs: CandidateInputs) -> [InsightCandidate] {
        var candidates: [InsightCandidate] = []

        if let fullCompletion = fullCompletionCandidate(
            entries: inputs.entries,
            calendar: inputs.calendar
        ) {
            candidates.append(fullCompletion)
        }
        if let recurringPeople = recurringPeopleCandidate(from: inputs.people) {
            candidates.append(recurringPeople)
        }
        if let recurringTheme = recurringThemeCandidate(needs: inputs.needs, gratitudes: inputs.gratitudes) {
            candidates.append(recurringTheme)
        }
        if let gap = needsGratitudeGapCandidate(needs: inputs.needs, gratitudes: inputs.gratitudes) {
            candidates.append(gap)
        }
        if let shift = continuityShiftCandidate(
            currentThemes: inputs.currentContinuity,
            previousThemes: inputs.previousContinuity
        ) {
            candidates.append(shift)
        }

        if isSparseWeek(entries: inputs.entries, reflectionDayCount: inputs.currentDayCount) {
            return []
        }
        return candidates
    }

    func selectInsights(
        from candidates: [InsightCandidate],
        fallback: ReviewWeeklyInsight
    ) -> [ReviewWeeklyInsight] {
        let sorted = candidates.sorted(by: compareCandidates)
        var selected: [ReviewWeeklyInsight] = []

        for candidate in sorted {
            guard selected.count < maxInsights else { break }
            if shouldSkip(candidate.insight, becauseOf: selected) {
                continue
            }
            selected.append(candidate.insight)
        }

        if selected.isEmpty {
            return [fallback]
        }

        return selected
    }

    func fallbackInsight(
        reflectionDayCount: Int
    ) -> ReviewWeeklyInsight {
        if reflectionDayCount == 0 {
            return ReviewWeeklyInsight(
                pattern: .sparseFallback,
                observation: String(
                    localized: "Start with one reflection today to build your weekly review."
                ),
                action: defaultContinuityPrompt,
                primaryTheme: nil,
                mentionCount: nil,
                dayCount: 0
            )
        }

        return ReviewWeeklyInsight(
            pattern: .sparseFallback,
            observation: renderLocalizedDayCountTemplate(
                "You showed up for reflection on %lld day(s) this week.",
                dayCount: reflectionDayCount
            ),
            action: String(localized: "What would make tomorrow's check-in easy to start?"),
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: reflectionDayCount
        )
    }

    func narrativeSummary(from insights: [ReviewWeeklyInsight]) -> String? {
        guard !insights.isEmpty else { return nil }
        return insights.map(\.observation).joined(separator: " ")
    }
}

private extension WeeklyInsightCandidateBuilder {
    func fullCompletionCandidate(
        entries: [JournalEntry],
        calendar: Calendar
    ) -> InsightCandidate? {
        guard !entries.isEmpty else { return nil }

        var completionByDay: [Date: Bool] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            completionByDay[day] = (completionByDay[day] ?? false) || entry.isComplete
        }

        guard completionByDay.count == 7 else { return nil }
        guard completionByDay.values.allSatisfy({ $0 }) else { return nil }

        let insight = ReviewWeeklyInsight(
            pattern: .fullCompletion,
            observation: String(
                localized: "You kept a steady daily rhythm and completed all 15 each day this week."
            ),
            action: String(
                localized: "What helped you stay this steady so you can carry it into next week?"
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
                "You kept %1$@ in mind on %2$lld day(s) this week.",
                dayCount: topPerson.dayCount,
                replacements: [
                    ("%1$@", topPerson.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "Would a short check-in with %@ feel supportive this week?",
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
            let insight = ReviewWeeklyInsight(
                pattern: .recurringTheme,
                observation: renderLocalizedDayCountTemplate(
                    "A need kept resurfacing: %1$@ on %2$lld day(s) this week.",
                    dayCount: chosen.theme.dayCount,
                    replacements: [
                        ("%1$@", chosen.theme.displayLabel)
                    ]
                ),
                action: renderLocalizedTemplate(
                    "What is one small step that could support %@ tomorrow?",
                    replacements: [
                        ("%@", chosen.theme.displayLabel),
                        ("%1$@", chosen.theme.displayLabel)
                    ]
                ),
                primaryTheme: chosen.theme.displayLabel,
                mentionCount: chosen.theme.mentionCount,
                dayCount: chosen.theme.dayCount
            )
            let score = chosen.theme.dayCount * 6 + chosen.theme.mentionCount * 2
            return InsightCandidate(score: score, insight: insight)
        }

        let insight = ReviewWeeklyInsight(
            pattern: .recurringTheme,
            observation: renderLocalizedDayCountTemplate(
                "You kept noticing %1$@ on %2$lld day(s) this week.",
                dayCount: chosen.theme.dayCount,
                replacements: [
                    ("%1$@", chosen.theme.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "How could you make space for %@ again next week?",
                replacements: [
                    ("%@", chosen.theme.displayLabel),
                    ("%1$@", chosen.theme.displayLabel)
                ]
            ),
            primaryTheme: chosen.theme.displayLabel,
            mentionCount: chosen.theme.mentionCount,
            dayCount: chosen.theme.dayCount
        )
        let score = chosen.theme.dayCount * 6 + chosen.theme.mentionCount
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
                "You often named %@ as a need, but it did not appear in your gratitudes yet.",
                replacements: [
                    ("%@", topNeedWithoutMatch.displayLabel),
                    ("%1$@", topNeedWithoutMatch.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "What is one tiny way to turn %@ into a gratitude this week?",
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
                "Your focus shifted from %1$@ last week to %2$@ this week.",
                replacements: [
                    ("%1$@", previousTop.displayLabel),
                    ("%2$@", currentTop.displayLabel)
                ]
            ),
            action: renderLocalizedTemplate(
                "Is this shift toward %@ something you want to keep building?",
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

    func isSparseWeek(entries: [JournalEntry], reflectionDayCount: Int) -> Bool {
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
        var message = NSLocalizedString(key, comment: "")
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
            ? String(localized: "day")
            : String(localized: "days")
        message = message.replacingOccurrences(of: "day(s)", with: dayUnit)
        return message
    }
}

struct ThemeSummary {
    let normalizedLabel: String
    let displayLabel: String
    let mentionCount: Int
    let dayCount: Int
    let weightedScore: Int
    let firstSeenOrder: Int
}

struct InsightCandidate {
    let score: Int
    let insight: ReviewWeeklyInsight
}

struct CandidateInputs {
    let entries: [JournalEntry]
    let currentDayCount: Int
    let needs: [ThemeSummary]
    let gratitudes: [ThemeSummary]
    let people: [ThemeSummary]
    let currentContinuity: [ThemeSummary]
    let previousContinuity: [ThemeSummary]
    let calendar: Calendar
}
// swiftlint:enable file_length function_body_length

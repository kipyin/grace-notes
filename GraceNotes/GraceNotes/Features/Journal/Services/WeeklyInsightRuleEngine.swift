import Foundation

struct WeeklyInsightAnalysis {
    let weeklyInsights: [ReviewWeeklyInsight]
    let recurringGratitudes: [ReviewInsightTheme]
    let recurringNeeds: [ReviewInsightTheme]
    let recurringPeople: [ReviewInsightTheme]
    let narrativeSummary: String?
    let resurfacingMessage: String
    let continuityPrompt: String
}

struct WeeklyInsightRuleEngine {
    private let maxThemesPerSection = 3
    private let maxInsights = 2
    private let chipWeight = 3
    private let textWeight = 1
    private let textNormalizer = WeeklyInsightTextNormalizer()
    private let defaultContinuityPrompt = String(
        localized: "What feels most important to carry into next week?"
    )

    func analyze(
        currentWeekEntries: [JournalEntry],
        previousWeekEntries: [JournalEntry],
        calendar: Calendar
    ) -> WeeklyInsightAnalysis {
        let prepared = prepareAnalysisInputs(
            currentWeekEntries: currentWeekEntries,
            previousWeekEntries: previousWeekEntries,
            calendar: calendar
        )

        let candidates = buildCandidates(inputs: prepared.candidateInputs)

        let selectedInsights = selectInsights(
            from: candidates,
            fallback: fallbackInsight(
                for: prepared.candidateInputs.entries,
                reflectionDayCount: prepared.candidateInputs.currentDayCount
            )
        )

        let narrativeSummary = narrativeSummary(from: selectedInsights)
        let resurfacingMessage = selectedInsights.first?.observation
            ?? String(localized: "Start with one reflection today to build your weekly review.")
        let continuityPrompt = selectedInsights.compactMap(\.action).first ?? defaultContinuityPrompt

        return WeeklyInsightAnalysis(
            weeklyInsights: selectedInsights,
            recurringGratitudes: prepared.recurringGratitudes,
            recurringNeeds: prepared.recurringNeeds,
            recurringPeople: prepared.recurringPeople,
            narrativeSummary: narrativeSummary,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt
        )
    }
}

private extension WeeklyInsightRuleEngine {
    private func prepareAnalysisInputs(
        currentWeekEntries: [JournalEntry],
        previousWeekEntries: [JournalEntry],
        calendar: Calendar
    ) -> PreparedInputs {
        let sortedCurrentEntries = sortedEntries(currentWeekEntries)
        let sortedPreviousEntries = sortedEntries(previousWeekEntries)
        let currentDayCount = reflectionDayCount(from: sortedCurrentEntries, calendar: calendar)

        let gratitudeStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.gratitudes },
            calendar: calendar
        )
        let needStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.needs },
            calendar: calendar
        )
        let peopleStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.people },
            calendar: calendar
        )

        let candidateInputs = CandidateInputs(
            entries: sortedCurrentEntries,
            currentDayCount: currentDayCount,
            needs: needStats,
            gratitudes: gratitudeStats,
            people: peopleStats,
            currentContinuity: buildContinuityStats(from: sortedCurrentEntries, calendar: calendar),
            previousContinuity: buildContinuityStats(from: sortedPreviousEntries, calendar: calendar),
            calendar: calendar
        )

        return PreparedInputs(
            candidateInputs: candidateInputs,
            recurringGratitudes: topThemes(from: gratitudeStats),
            recurringNeeds: topThemes(from: needStats),
            recurringPeople: topThemes(from: peopleStats)
        )
    }

    private func buildCandidates(inputs: CandidateInputs) -> [InsightCandidate] {
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

    private func fullCompletionCandidate(
        entries: [JournalEntry],
        calendar: Calendar
    ) -> InsightCandidate? {
        guard !entries.isEmpty else { return nil }

        var completionByDay: [Date: Bool] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            completionByDay[day] = (completionByDay[day] ?? false) || entry.completionLevel == .fullFiveCubed
        }

        guard completionByDay.count == 7 else { return nil }
        guard completionByDay.values.allSatisfy({ $0 }) else { return nil }

        let insight = ReviewWeeklyInsight(
            pattern: .fullCompletion,
            observation: String(
                localized: "You completed your full 5³ rhythm every day this week."
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

    private func recurringPeopleCandidate(from people: [ThemeSummary]) -> InsightCandidate? {
        guard let topPerson = people.first(where: { $0.dayCount >= 2 || $0.mentionCount >= 2 }) else {
            return nil
        }

        let insight = ReviewWeeklyInsight(
            pattern: .recurringPeople,
            observation: String(
                format: String(localized: "You kept %1$@ in mind on %2$lld day(s) this week."),
                topPerson.displayLabel,
                topPerson.dayCount
            ),
            action: String(
                format: String(localized: "Would a short check-in with %@ feel supportive this week?"),
                topPerson.displayLabel
            ),
            primaryTheme: topPerson.displayLabel,
            mentionCount: topPerson.mentionCount,
            dayCount: topPerson.dayCount
        )
        let score = topPerson.dayCount * 7 + topPerson.mentionCount * 2
        return InsightCandidate(score: score, insight: insight)
    }

    private func recurringThemeCandidate(
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
                observation: String(
                    format: String(localized: "A need kept resurfacing: %1$@ on %2$lld day(s) this week."),
                    chosen.theme.displayLabel,
                    chosen.theme.dayCount
                ),
                action: String(
                    format: String(localized: "What is one small step that could support %@ tomorrow?"),
                    chosen.theme.displayLabel
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
            observation: String(
                format: String(localized: "You kept noticing %1$@ on %2$lld day(s) this week."),
                chosen.theme.displayLabel,
                chosen.theme.dayCount
            ),
            action: String(
                format: String(localized: "How could you make space for %@ again next week?"),
                chosen.theme.displayLabel
            ),
            primaryTheme: chosen.theme.displayLabel,
            mentionCount: chosen.theme.mentionCount,
            dayCount: chosen.theme.dayCount
        )
        let score = chosen.theme.dayCount * 6 + chosen.theme.mentionCount
        return InsightCandidate(score: score, insight: insight)
    }

    private func needsGratitudeGapCandidate(
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
            observation: String(
                format: String(
                    localized: "You often named %@ as a need, but it did not appear in your gratitudes yet."
                ),
                topNeedWithoutMatch.displayLabel
            ),
            action: String(
                format: String(localized: "What is one tiny way to turn %@ into a gratitude this week?"),
                topNeedWithoutMatch.displayLabel
            ),
            primaryTheme: topNeedWithoutMatch.displayLabel,
            mentionCount: topNeedWithoutMatch.mentionCount,
            dayCount: topNeedWithoutMatch.dayCount
        )
        let score = topNeedWithoutMatch.dayCount * 8 + topNeedWithoutMatch.mentionCount * 3 + 6
        return InsightCandidate(score: score, insight: insight)
    }

    private func continuityShiftCandidate(
        currentThemes: [ThemeSummary],
        previousThemes: [ThemeSummary]
    ) -> InsightCandidate? {
        guard let currentTop = currentThemes.first else { return nil }
        guard let previousTop = previousThemes.first else { return nil }
        guard currentTop.weightedScore >= 8, previousTop.weightedScore >= 6 else { return nil }
        guard currentTop.normalizedLabel != previousTop.normalizedLabel else { return nil }

        let insight = ReviewWeeklyInsight(
            pattern: .continuityShift,
            observation: String(
                format: String(localized: "Your focus shifted from %1$@ last week to %2$@ this week."),
                previousTop.displayLabel,
                currentTop.displayLabel
            ),
            action: String(
                format: String(localized: "Is this shift toward %@ something you want to keep building?"),
                currentTop.displayLabel
            ),
            primaryTheme: currentTop.displayLabel,
            mentionCount: currentTop.mentionCount,
            dayCount: currentTop.dayCount
        )
        let score = currentTop.weightedScore + previousTop.weightedScore + 8
        return InsightCandidate(score: score, insight: insight)
    }

    private func strongerTheme(
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

    private func sortedEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        entries.sorted {
            if $0.entryDate != $1.entryDate {
                return $0.entryDate < $1.entryDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func reflectionDayCount(from entries: [JournalEntry], calendar: Calendar) -> Int {
        Set(entries.filter(\.hasMeaningfulContent).map { calendar.startOfDay(for: $0.entryDate) }).count
    }

    private func buildChipStats(
        from entries: [JournalEntry],
        itemsExtractor: (JournalEntry) -> [JournalItem],
        calendar: Calendar
    ) -> [ThemeSummary] {
        var themeMap: [String: ThemeAccumulator] = [:]
        var sequence = 0

        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            for item in itemsExtractor(entry) {
                let label = preferredItemLabel(item)
                accumulateTheme(
                    label: label,
                    day: day,
                    weight: chipWeight,
                    sequence: sequence,
                    map: &themeMap
                )
                sequence += 1
            }
        }

        return sortedThemeSummaries(from: themeMap)
    }

    private func buildContinuityStats(
        from entries: [JournalEntry],
        calendar: Calendar
    ) -> [ThemeSummary] {
        var themeMap: [String: ThemeAccumulator] = [:]
        var sequence = 0

        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            for item in entry.gratitudes + entry.needs {
                accumulateTheme(
                    label: preferredItemLabel(item),
                    day: day,
                    weight: chipWeight,
                    sequence: sequence,
                    map: &themeMap
                )
                sequence += 1
            }

            for textTheme in textNormalizer.extractThemesFromText(entry.readingNotes + " " + entry.reflections) {
                accumulateTheme(
                    label: textTheme,
                    day: day,
                    weight: textWeight,
                    sequence: sequence,
                    map: &themeMap
                )
                sequence += 1
            }
        }

        return sortedThemeSummaries(from: themeMap)
    }

    private func topThemes(from summaries: [ThemeSummary]) -> [ReviewInsightTheme] {
        summaries
            .sorted {
                if $0.mentionCount != $1.mentionCount {
                    return $0.mentionCount > $1.mentionCount
                }
                if $0.dayCount != $1.dayCount {
                    return $0.dayCount > $1.dayCount
                }
                return $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
            }
            .prefix(maxThemesPerSection)
            .map { ReviewInsightTheme(label: $0.displayLabel, count: $0.mentionCount) }
    }

    private func selectInsights(
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

    private func compareCandidates(_ lhs: InsightCandidate, _ rhs: InsightCandidate) -> Bool {
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

    private func patternPriority(_ pattern: ReviewWeeklyInsightPattern) -> Int {
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

    private func shouldSkip(
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

    private func fallbackInsight(
        for entries: [JournalEntry],
        reflectionDayCount: Int
    ) -> ReviewWeeklyInsight {
        if entries.isEmpty {
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
            observation: String(
                format: String(localized: "You showed up for reflection on %lld day(s) this week."),
                reflectionDayCount
            ),
            action: String(localized: "What would make tomorrow's check-in easy to start?"),
            primaryTheme: nil,
            mentionCount: nil,
            dayCount: reflectionDayCount
        )
    }

    private func narrativeSummary(from insights: [ReviewWeeklyInsight]) -> String? {
        guard !insights.isEmpty else { return nil }
        return insights.map(\.observation).joined(separator: " ")
    }

    private func isSparseWeek(entries: [JournalEntry], reflectionDayCount: Int) -> Bool {
        guard !entries.isEmpty else { return true }
        if reflectionDayCount >= 2 {
            return false
        }

        let totalChips = entries.reduce(0) { partialResult, entry in
            partialResult + entry.gratitudes.count + entry.needs.count + entry.people.count
        }
        let totalLongText = entries.reduce(0) { partialResult, entry in
            partialResult
                + textNormalizer.trimmed(entry.readingNotes).count
                + textNormalizer.trimmed(entry.reflections).count
        }

        return totalChips <= 2 && totalLongText < 40
    }

    private func preferredItemLabel(_ item: JournalItem) -> String {
        let label = textNormalizer.trimmed(item.displayLabel)
        if !label.isEmpty {
            return label
        }
        return textNormalizer.trimmed(item.fullText)
    }

    private func accumulateTheme(
        label: String,
        day: Date,
        weight: Int,
        sequence: Int,
        map: inout [String: ThemeAccumulator]
    ) {
        let trimmedLabel = textNormalizer.trimmed(label)
        guard !trimmedLabel.isEmpty else { return }

        let normalized = textNormalizer.normalizeThemeLabel(trimmedLabel)
        guard !normalized.isEmpty else { return }

        if map[normalized] == nil {
            map[normalized] = ThemeAccumulator(
                normalizedLabel: normalized,
                displayLabel: trimmedLabel,
                mentionCount: 1,
                weightedScore: weight,
                days: [day],
                firstSeenOrder: sequence
            )
            return
        }

        map[normalized]?.mentionCount += 1
        map[normalized]?.weightedScore += weight
        map[normalized]?.days.insert(day)
    }

    private func sortedThemeSummaries(from map: [String: ThemeAccumulator]) -> [ThemeSummary] {
        map.values
            .map {
                ThemeSummary(
                    normalizedLabel: $0.normalizedLabel,
                    displayLabel: $0.displayLabel,
                    mentionCount: $0.mentionCount,
                    dayCount: $0.days.count,
                    weightedScore: $0.weightedScore,
                    firstSeenOrder: $0.firstSeenOrder
                )
            }
            .sorted {
                if $0.weightedScore != $1.weightedScore {
                    return $0.weightedScore > $1.weightedScore
                }
                if $0.dayCount != $1.dayCount {
                    return $0.dayCount > $1.dayCount
                }
                if $0.mentionCount != $1.mentionCount {
                    return $0.mentionCount > $1.mentionCount
                }
                if $0.firstSeenOrder != $1.firstSeenOrder {
                    return $0.firstSeenOrder < $1.firstSeenOrder
                }
                return $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
            }
    }

}

private struct ThemeAccumulator {
    let normalizedLabel: String
    let displayLabel: String
    var mentionCount: Int
    var weightedScore: Int
    var days: Set<Date>
    let firstSeenOrder: Int
}

private struct ThemeSummary {
    let normalizedLabel: String
    let displayLabel: String
    let mentionCount: Int
    let dayCount: Int
    let weightedScore: Int
    let firstSeenOrder: Int
}

private struct InsightCandidate {
    let score: Int
    let insight: ReviewWeeklyInsight
}

private struct CandidateInputs {
    let entries: [JournalEntry]
    let currentDayCount: Int
    let needs: [ThemeSummary]
    let gratitudes: [ThemeSummary]
    let people: [ThemeSummary]
    let currentContinuity: [ThemeSummary]
    let previousContinuity: [ThemeSummary]
    let calendar: Calendar
}

private struct PreparedInputs {
    let candidateInputs: CandidateInputs
    let recurringGratitudes: [ReviewInsightTheme]
    let recurringNeeds: [ReviewInsightTheme]
    let recurringPeople: [ReviewInsightTheme]
}

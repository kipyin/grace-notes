import Foundation
import NaturalLanguage

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
    private let defaultContinuityPrompt = String(
        localized: "What feels most important to carry into next week?"
    )

    func analyze(
        currentWeekEntries: [JournalEntry],
        previousWeekEntries: [JournalEntry],
        calendar: Calendar
    ) -> WeeklyInsightAnalysis {
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

        let recurringGratitudes = topThemes(from: gratitudeStats)
        let recurringNeeds = topThemes(from: needStats)
        let recurringPeople = topThemes(from: peopleStats)

        let currentContinuityStats = buildContinuityStats(from: sortedCurrentEntries, calendar: calendar)
        let previousContinuityStats = buildContinuityStats(from: sortedPreviousEntries, calendar: calendar)

        let candidates = buildCandidates(
            entries: sortedCurrentEntries,
            currentDayCount: currentDayCount,
            needs: needStats,
            gratitudes: gratitudeStats,
            people: peopleStats,
            currentContinuity: currentContinuityStats,
            previousContinuity: previousContinuityStats,
            calendar: calendar
        )

        let selectedInsights = selectInsights(
            from: candidates,
            fallback: fallbackInsight(for: sortedCurrentEntries, reflectionDayCount: currentDayCount)
        )

        let narrativeSummary = narrativeSummary(from: selectedInsights)
        let resurfacingMessage = selectedInsights.first?.observation
            ?? String(localized: "Start with one reflection today to build your weekly review.")
        let continuityPrompt = selectedInsights.compactMap(\.action).first ?? defaultContinuityPrompt

        return WeeklyInsightAnalysis(
            weeklyInsights: selectedInsights,
            recurringGratitudes: recurringGratitudes,
            recurringNeeds: recurringNeeds,
            recurringPeople: recurringPeople,
            narrativeSummary: narrativeSummary,
            resurfacingMessage: resurfacingMessage,
            continuityPrompt: continuityPrompt
        )
    }
}

private extension WeeklyInsightRuleEngine {
    private func buildCandidates(
        entries: [JournalEntry],
        currentDayCount: Int,
        needs: [ThemeSummary],
        gratitudes: [ThemeSummary],
        people: [ThemeSummary],
        currentContinuity: [ThemeSummary],
        previousContinuity: [ThemeSummary],
        calendar: Calendar
    ) -> [InsightCandidate] {
        var candidates: [InsightCandidate] = []

        if let fullCompletion = fullCompletionCandidate(entries: entries, calendar: calendar) {
            candidates.append(fullCompletion)
        }
        if let recurringPeople = recurringPeopleCandidate(from: people) {
            candidates.append(recurringPeople)
        }
        if let recurringTheme = recurringThemeCandidate(needs: needs, gratitudes: gratitudes) {
            candidates.append(recurringTheme)
        }
        if let gap = needsGratitudeGapCandidate(needs: needs, gratitudes: gratitudes) {
            candidates.append(gap)
        }
        if let shift = continuityShiftCandidate(
            currentThemes: currentContinuity,
            previousThemes: previousContinuity
        ) {
            candidates.append(shift)
        }

        if isSparseWeek(entries: entries, reflectionDayCount: currentDayCount) {
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
                !matchesExistingTheme($0.normalizedLabel, against: gratitudeKeys)
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

            for textTheme in extractThemesFromText(entry.readingNotes + " " + entry.reflections) {
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
            partialResult + trimmed(entry.readingNotes).count + trimmed(entry.reflections).count
        }

        return totalChips <= 2 && totalLongText < 40
    }

    private func preferredItemLabel(_ item: JournalItem) -> String {
        let label = trimmed(item.displayLabel)
        if !label.isEmpty {
            return label
        }
        return trimmed(item.fullText)
    }

    private func accumulateTheme(
        label: String,
        day: Date,
        weight: Int,
        sequence: Int,
        map: inout [String: ThemeAccumulator]
    ) {
        let trimmedLabel = trimmed(label)
        guard !trimmedLabel.isEmpty else { return }

        let normalized = normalizeThemeLabel(trimmedLabel)
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

    private func extractThemesFromText(_ text: String) -> [String] {
        let source = trimmed(text)
        guard !source.isEmpty else { return [] }

        let textRange = source.startIndex..<source.endIndex
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = source
        if let language = NLLanguageRecognizer.dominantLanguage(for: source) {
            tagger.setLanguage(language, range: textRange)
        }

        var extracted: [String: Int] = [:]
        var displayLabels: [String: String] = [:]
        var sequence = 0
        var firstSeenOrder: [String: Int] = [:]

        let options: NLTagger.Options = [.joinNames, .omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(
            in: textRange,
            unit: .word,
            scheme: .nameTypeOrLexicalClass,
            options: options
        ) { tag, tokenRange in
            let token = String(source[tokenRange])
            guard shouldIncludeTextToken(token, tag: tag) else { return true }
            let normalized = normalizeThemeLabel(token)
            guard !normalized.isEmpty else { return true }
            guard !isStopWord(normalized) else { return true }

            extracted[normalized, default: 0] += 1
            if displayLabels[normalized] == nil {
                displayLabels[normalized] = trimmed(token)
            }
            if firstSeenOrder[normalized] == nil {
                firstSeenOrder[normalized] = sequence
            }
            sequence += 1
            return true
        }

        return extracted
            .sorted {
                if $0.value != $1.value {
                    return $0.value > $1.value
                }
                let lhsOrder = firstSeenOrder[$0.key] ?? .max
                let rhsOrder = firstSeenOrder[$1.key] ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return $0.key < $1.key
            }
            .prefix(3)
            .compactMap { displayLabels[$0.key] }
    }

    private func shouldIncludeTextToken(_ token: String, tag: NLTag?) -> Bool {
        let clean = trimmed(token)
        guard !clean.isEmpty else { return false }

        let hasHan = containsHanCharacters(clean)
        let minimumLength = hasHan ? 1 : 3
        guard clean.count >= minimumLength else { return false }

        guard let tag else { return false }
        switch tag {
        case .personalName, .placeName, .organizationName, .noun:
            return true
        default:
            return false
        }
    }

    private func containsHanCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xF900...0xFAFF,
                 0x20000...0x2A6DF,
                 0x2A700...0x2B73F,
                 0x2B740...0x2B81F,
                 0x2B820...0x2CEAF,
                 0x2CEB0...0x2EBEF,
                 0x2F800...0x2FA1F:
                return true
            default:
                return false
            }
        }
    }

    private func isStopWord(_ normalizedToken: String) -> Bool {
        let englishStopWords: Set<String> = [
            "with", "from", "that", "this", "your", "have", "will", "about", "into",
            "today", "week", "really", "just", "very", "more", "need", "needs", "gratitude",
            "grateful", "thankful"
        ]
        let chineseStopWords: Set<String> = [
            "今天", "这个", "那个", "我们", "你们", "他们", "自己", "需要", "感恩", "感谢"
        ]
        return englishStopWords.contains(normalizedToken) || chineseStopWords.contains(normalizedToken)
    }

    private func matchesExistingTheme(_ needKey: String, against gratitudeKeys: Set<String>) -> Bool {
        if gratitudeKeys.contains(needKey) {
            return true
        }

        for gratitudeKey in gratitudeKeys {
            if overlapScore(between: needKey, and: gratitudeKey) >= 1 {
                return true
            }
        }
        return false
    }

    private func overlapScore(between lhs: String, and rhs: String) -> Int {
        let lhsTokens = Set(lhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let rhsTokens = Set(rhs.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        if lhsTokens.isEmpty || rhsTokens.isEmpty {
            return 0
        }
        return lhsTokens.intersection(rhsTokens).count
    }

    private func normalizeThemeLabel(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
        let withoutSymbols = folded.replacingOccurrences(
            of: "[\\p{P}\\p{S}]+",
            with: " ",
            options: .regularExpression
        )
        let collapsedSpaces = withoutSymbols.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return trimmed(collapsedSpaces)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
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

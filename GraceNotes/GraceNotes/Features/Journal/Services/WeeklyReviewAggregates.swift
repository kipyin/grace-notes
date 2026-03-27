import Foundation

struct ThemeSummary {
    let normalizedLabel: String
    let displayLabel: String
    let mentionCount: Int
    let dayCount: Int
    let weightedScore: Int
    let firstSeenOrder: Int
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

struct WeeklyReviewAggregates {
    let candidateInputs: CandidateInputs
    let recurringGratitudes: [ReviewInsightTheme]
    let recurringNeeds: [ReviewInsightTheme]
    let recurringPeople: [ReviewInsightTheme]
    let stats: ReviewWeekStats

    var supportsInsightNarrative: Bool {
        guard stats.reflectionDays >= 2 else {
            return false
        }
        if stats.completionMix.highCompletionDays >= 4 {
            return true
        }
        if hasRepeatedTheme(in: candidateInputs.needs)
            || hasRepeatedTheme(in: candidateInputs.gratitudes)
            || hasRepeatedTheme(in: candidateInputs.people) {
            return true
        }
        return hasContinuityShiftSignal
    }

    private var hasContinuityShiftSignal: Bool {
        guard let currentTop = candidateInputs.currentContinuity.first,
              let previousTop = candidateInputs.previousContinuity.first else {
            return false
        }
        return currentTop.weightedScore >= 8
            && previousTop.weightedScore >= 6
            && currentTop.normalizedLabel != previousTop.normalizedLabel
    }

    private func hasRepeatedTheme(in summaries: [ThemeSummary]) -> Bool {
        summaries.contains { $0.dayCount >= 2 || $0.mentionCount >= 2 }
    }
}

struct WeeklyReviewAggregatesBuilder {
    private let maxThemesPerSection = 3
    private let chipWeight = 3
    private let textWeight = 1
    private let textNormalizer = WeeklyInsightTextNormalizer()

    func build(
        currentPeriod: Range<Date>,
        currentWeekEntries: [JournalEntry],
        previousWeekEntries: [JournalEntry],
        calendar: Calendar
    ) -> WeeklyReviewAggregates {
        let sortedCurrentEntries = sortedEntries(currentWeekEntries)
        let sortedPreviousEntries = sortedEntries(previousWeekEntries)
        let reflectionDays = reflectionDayCount(from: sortedCurrentEntries, calendar: calendar)

        let gratitudeStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.gratitudes ?? [] },
            calendar: calendar
        )
        let needStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.needs ?? [] },
            calendar: calendar
        )
        let peopleStats = buildChipStats(
            from: sortedCurrentEntries,
            itemsExtractor: { $0.people ?? [] },
            calendar: calendar
        )

        let candidateInputs = CandidateInputs(
            entries: sortedCurrentEntries,
            currentDayCount: reflectionDays,
            needs: needStats,
            gratitudes: gratitudeStats,
            people: peopleStats,
            currentContinuity: buildContinuityStats(from: sortedCurrentEntries, calendar: calendar),
            previousContinuity: buildContinuityStats(from: sortedPreviousEntries, calendar: calendar),
            calendar: calendar
        )

        return WeeklyReviewAggregates(
            candidateInputs: candidateInputs,
            recurringGratitudes: topThemes(from: gratitudeStats),
            recurringNeeds: topThemes(from: needStats),
            recurringPeople: topThemes(from: peopleStats),
            stats: buildWeekStats(
                currentPeriod: currentPeriod,
                entries: sortedCurrentEntries,
                reflectionDays: reflectionDays,
                calendar: calendar
            )
        )
    }
}

private extension WeeklyReviewAggregatesBuilder {
    private func sortedEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        entries.sorted {
            if $0.entryDate != $1.entryDate {
                return $0.entryDate < $1.entryDate
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    private func reflectionDayCount(from entries: [JournalEntry], calendar: Calendar) -> Int {
        Set(
            entries
                .filter { $0.hasMeaningfulContent || hasReflectionSurfaceText($0) }
                .map { calendar.startOfDay(for: $0.entryDate) }
        ).count
    }

    private func meaningfulEntryCount(from entries: [JournalEntry]) -> Int {
        entries.filter(\.hasMeaningfulContent).count
    }

    private func hasReflectionSurfaceText(_ entry: JournalEntry) -> Bool {
        !textNormalizer.trimmed(entry.readingNotes).isEmpty
            || !textNormalizer.trimmed(entry.reflections).isEmpty
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
            for item in (entry.gratitudes ?? []) + (entry.needs ?? []) {
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

    private func buildWeekStats(
        currentPeriod: Range<Date>,
        entries: [JournalEntry],
        reflectionDays: Int,
        calendar: Calendar
    ) -> ReviewWeekStats {
        let meaningfulEntryCount = meaningfulEntryCount(from: entries)
        let strongestCompletionByDay = strongestCompletionByDay(from: entries, calendar: calendar)
        let completionMix = buildCompletionMix(from: strongestCompletionByDay)
        let activity = buildDayActivity(
            currentPeriod: currentPeriod,
            entries: entries,
            strongestCompletionByDay: strongestCompletionByDay,
            calendar: calendar
        )
        let sectionTotals = ReviewWeekSectionTotals(
            gratitudeMentions: entries.reduce(0) { $0 + ($1.gratitudes ?? []).count },
            needMentions: entries.reduce(0) { $0 + ($1.needs ?? []).count },
            peopleMentions: entries.reduce(0) { $0 + ($1.people ?? []).count }
        )
        return ReviewWeekStats(
            reflectionDays: reflectionDays,
            meaningfulEntryCount: meaningfulEntryCount,
            completionMix: completionMix,
            activity: activity,
            sectionTotals: sectionTotals
        )
    }

    private func strongestCompletionByDay(
        from entries: [JournalEntry],
        calendar: Calendar
    ) -> [Date: JournalCompletionLevel] {
        var strongestByDay: [Date: JournalCompletionLevel] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            let current = strongestByDay[day]
            if let current, completionRank(current) >= completionRank(entry.completionLevel) {
                continue
            }
            strongestByDay[day] = entry.completionLevel
        }
        return strongestByDay
    }

    private func buildCompletionMix(from strongestByDay: [Date: JournalCompletionLevel]) -> ReviewWeekCompletionMix {
        var emptyDays = 0
        var startedDays = 0
        var growingDays = 0
        var balancedDays = 0
        var fullDays = 0
        for completion in strongestByDay.values {
            switch completion {
            case .empty:
                emptyDays += 1
            case .started:
                startedDays += 1
            case .growing:
                growingDays += 1
            case .balanced:
                balancedDays += 1
            case .full:
                fullDays += 1
            }
        }
        return ReviewWeekCompletionMix(
            emptyDays: emptyDays,
            startedDays: startedDays,
            growingDays: growingDays,
            balancedDays: balancedDays,
            fullDays: fullDays
        )
    }

    private func buildDayActivity(
        currentPeriod: Range<Date>,
        entries: [JournalEntry],
        strongestCompletionByDay: [Date: JournalCompletionLevel],
        calendar: Calendar
    ) -> [ReviewDayActivity] {
        let activeDays = Set(
            entries
                .filter { $0.hasMeaningfulContent || hasReflectionSurfaceText($0) }
                .map { calendar.startOfDay(for: $0.entryDate) }
        )
        var activity: [ReviewDayActivity] = []
        var day = currentPeriod.lowerBound
        while day < currentPeriod.upperBound {
            activity.append(
                ReviewDayActivity(
                    date: day,
                    hasReflectiveActivity: activeDays.contains(calendar.startOfDay(for: day)),
                    strongestCompletionLevel: activeDays.contains(calendar.startOfDay(for: day))
                        ? strongestCompletionByDay[calendar.startOfDay(for: day)]
                        : nil
                )
            )
            day = calendar.date(byAdding: .day, value: 1, to: day) ?? currentPeriod.upperBound
        }
        return activity
    }

    private func completionRank(_ level: JournalCompletionLevel) -> Int {
        level.tutorialCompletionRank
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

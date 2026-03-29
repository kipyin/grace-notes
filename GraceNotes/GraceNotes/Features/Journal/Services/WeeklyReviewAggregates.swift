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
        allEntries: [JournalEntry],
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
                allEntries: allEntries,
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
        allEntries: [JournalEntry],
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
        let rhythmHistory = buildRhythmHistory(
            allEntries: allEntries,
            currentPeriod: currentPeriod,
            calendar: calendar
        )
        let sectionTotals = ReviewWeekSectionTotals(
            gratitudeMentions: entries.reduce(0) { $0 + ($1.gratitudes ?? []).count },
            needMentions: entries.reduce(0) { $0 + ($1.needs ?? []).count },
            peopleMentions: entries.reduce(0) { $0 + ($1.people ?? []).count }
        )
        let mostRecurringThemes = buildMostRecurringThemes(
            from: sortedEntries(allEntries),
            currentPeriod: currentPeriod,
            calendar: calendar
        )
        return ReviewWeekStats(
            reflectionDays: reflectionDays,
            meaningfulEntryCount: meaningfulEntryCount,
            completionMix: completionMix,
            activity: activity,
            rhythmHistory: rhythmHistory,
            sectionTotals: sectionTotals,
            mostRecurringThemes: mostRecurringThemes
        )
    }

    private func buildMostRecurringThemes(
        from entries: [JournalEntry],
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> [ReviewMostRecurringTheme] {
        guard !entries.isEmpty else { return [] }
        let trendRanges = trendWeekRanges(currentPeriod: currentPeriod, calendar: calendar)
        var map: [String: MostRecurringAccumulator] = [:]
        var sequence = 0

        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            accumulateMostRecurring(
                from: entry,
                day: day,
                trendRanges: trendRanges,
                sequence: &sequence,
                map: &map
            )
        }

        return map.values
            .map { value in
                let trend = themeTrend(
                    currentWeekCount: value.currentWeekCount,
                    previousWeekCount: value.previousWeekCount
                )
                let evidence = value.evidenceByDay
                    .map { date, sources in
                        ReviewThemeEvidence(
                            date: date,
                            sources: sources.sorted { $0.rawValue < $1.rawValue }
                        )
                    }
                    .sorted { $0.date > $1.date }
                return ReviewMostRecurringTheme(
                    label: value.displayLabel,
                    totalCount: value.totalCount,
                    dayCount: value.days.count,
                    currentWeekCount: value.currentWeekCount,
                    previousWeekCount: value.previousWeekCount,
                    trend: trend,
                    evidence: evidence
                )
            }
            .sorted {
                if $0.totalCount != $1.totalCount {
                    return $0.totalCount > $1.totalCount
                }
                if $0.dayCount != $1.dayCount {
                    return $0.dayCount > $1.dayCount
                }
                let lhsOrder =
                    map[textNormalizer.normalizeThemeLabel($0.label)]?.firstSeenOrder ?? .max
                let rhsOrder =
                    map[textNormalizer.normalizeThemeLabel($1.label)]?.firstSeenOrder ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }
    }

    private func trendWeekRanges(
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> (current: Range<Date>, previous: Range<Date>) {
        let referenceDay =
            calendar.date(byAdding: .day, value: -1, to: currentPeriod.upperBound) ?? currentPeriod.lowerBound
        let fallbackCurrent = currentPeriod
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDay),
              let previousWeekAnchor = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeek.start),
              let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousWeekAnchor) else {
            return (fallbackCurrent, fallbackCurrent)
        }
        return (
            currentWeek.start..<currentWeek.end,
            previousWeek.start..<previousWeek.end
        )
    }

    private func themeTrend(currentWeekCount: Int, previousWeekCount: Int) -> ReviewThemeTrend {
        if previousWeekCount == 0, currentWeekCount > 0 {
            return .new
        }
        if currentWeekCount > previousWeekCount {
            return .rising
        }
        if currentWeekCount < previousWeekCount {
            return .down
        }
        return .stable
    }

    private func accumulateMostRecurring(
        from entry: JournalEntry,
        day: Date,
        trendRanges: (current: Range<Date>, previous: Range<Date>),
        sequence: inout Int,
        map: inout [String: MostRecurringAccumulator]
    ) {
        let groupedLabels: [(labels: [String], source: ReviewThemeSourceCategory)] = [
            ((entry.gratitudes ?? []).map(preferredItemLabel), .gratitudes),
            ((entry.needs ?? []).map(preferredItemLabel), .needs),
            ((entry.people ?? []).map(preferredItemLabel), .people),
            (textNormalizer.extractThemesFromText(entry.readingNotes), .readingNotes),
            (textNormalizer.extractThemesFromText(entry.reflections), .reflections)
        ]

        for group in groupedLabels {
            for label in group.labels {
                accumulateMostRecurring(
                    label: label,
                    day: day,
                    source: group.source,
                    trendRanges: trendRanges,
                    sequence: sequence,
                    map: &map
                )
                sequence += 1
            }
        }
    }

    private func accumulateMostRecurring(
        label: String,
        day: Date,
        source: ReviewThemeSourceCategory,
        trendRanges: (current: Range<Date>, previous: Range<Date>),
        sequence: Int,
        map: inout [String: MostRecurringAccumulator]
    ) {
        let trimmedLabel = textNormalizer.trimmed(label)
        guard !trimmedLabel.isEmpty else { return }
        let normalized = textNormalizer.normalizeThemeLabel(trimmedLabel)
        guard !normalized.isEmpty else { return }

        var value = map[normalized] ?? MostRecurringAccumulator(
            normalizedLabel: normalized,
            displayLabel: trimmedLabel,
            totalCount: 0,
            days: [],
            evidenceByDay: [:],
            currentWeekCount: 0,
            previousWeekCount: 0,
            firstSeenOrder: sequence
        )
        value.totalCount += 1
        value.days.insert(day)
        var sources = value.evidenceByDay[day, default: []]
        sources.insert(source)
        value.evidenceByDay[day] = sources
        if trendRanges.current.contains(day) {
            value.currentWeekCount += 1
        } else if trendRanges.previous.contains(day) {
            value.previousWeekCount += 1
        }
        map[normalized] = value
    }

    /// Builds a longer oldest-to-newest activity sequence ending on the last day of `currentPeriod`,
    /// capped for performance.
    private func buildRhythmHistory(
        allEntries: [JournalEntry],
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> [ReviewDayActivity]? {
        guard !allEntries.isEmpty else { return nil }

        let strongestCompletionByDay = strongestCompletionByDay(from: allEntries, calendar: calendar)
        let endDayInclusive = calendar.date(byAdding: .day, value: -1, to: currentPeriod.upperBound)
            ?? currentPeriod.lowerBound
        let entryMin = allEntries.map { calendar.startOfDay(for: $0.entryDate) }.min()
        let capBack = calendar.date(byAdding: .day, value: -179, to: endDayInclusive) ?? endDayInclusive
        let startDay = max(capBack, entryMin ?? capBack)
        guard startDay <= endDayInclusive else { return nil }

        let rangeEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDayInclusive) ?? currentPeriod.upperBound
        let history = buildDayActivity(
            currentPeriod: startDay..<rangeEndExclusive,
            entries: allEntries,
            strongestCompletionByDay: strongestCompletionByDay,
            calendar: calendar
        )
        return history.isEmpty ? nil : history
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
            let dayStart = calendar.startOfDay(for: day)
            let hasPersistedEntry = strongestCompletionByDay[dayStart] != nil
            activity.append(
                ReviewDayActivity(
                    date: day,
                    hasReflectiveActivity: activeDays.contains(dayStart),
                    strongestCompletionLevel: activeDays.contains(dayStart)
                        ? strongestCompletionByDay[dayStart]
                        : nil,
                    hasPersistedEntry: hasPersistedEntry
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

private struct MostRecurringAccumulator {
    let normalizedLabel: String
    let displayLabel: String
    var totalCount: Int
    var days: Set<Date>
    var evidenceByDay: [Date: Set<ReviewThemeSourceCategory>]
    var currentWeekCount: Int
    var previousWeekCount: Int
    let firstSeenOrder: Int
}

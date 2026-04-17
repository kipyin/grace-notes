import Foundation

/// Caps how far back ``WeeklyReviewAggregatesBuilder/buildRhythmHistory`` materializes
/// calendar-day rows so multi-year journals cannot allocate unbounded ``ReviewDayActivity`` arrays.
/// Custom Past statistics windows already clip via ``PastStatisticsIntervalSelection/resolvedHistoryRange``.
private enum RhythmHistoryLimits {
    /// Maximum inclusive number of local calendar days in the rhythm strip (about two years).
    static let maxInclusiveCalendarDays = 731
}

struct ThemeSummary {
    let normalizedLabel: String
    let displayLabel: String
    let mentionCount: Int
    let dayCount: Int
    let weightedScore: Int
    let firstSeenOrder: Int
}

struct CandidateInputs {
    let entries: [Journal]
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
    let maxThemesPerSection = 3
    let chipWeight = 3
    let textWeight = 1
    let minimumMostRecurringSignalCount = 2
    let textNormalizer = WeeklyInsightTextNormalizer()
    var themeJournalLanguageResolver: any ReviewJournalThemeLanguageResolving = ReviewJournalThemeLanguageResolver()

    // swiftlint:disable:next function_parameter_count
    func build(
        currentPeriod: Range<Date>,
        currentWeekEntries: [Journal],
        previousWeekEntries: [Journal],
        allEntries: [Journal],
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection = .default
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
                calendar: calendar,
                referenceDate: referenceDate,
                pastStatisticsInterval: pastStatisticsInterval
            )
        )
    }
}

private extension WeeklyReviewAggregatesBuilder {
    func sortedEntries(_ entries: [Journal]) -> [Journal] {
        ReviewHistoryWindowing.sortedEntries(entries)
    }

    func reflectionDayCount(from entries: [Journal], calendar: Calendar) -> Int {
        Set(
            entries
                .filter(\.hasMeaningfulContent)
                .map { calendar.startOfDay(for: $0.entryDate) }
        ).count
    }

    func meaningfulEntryCount(from entries: [Journal]) -> Int {
        entries.filter(\.hasMeaningfulContent).count
    }

    /// Joins non-empty trimmed notes and reflections without a stray lone space when both are empty.
    func reflectionCorpusForContinuity(_ entry: Journal) -> String {
        [entry.readingNotes, entry.reflections]
            .map { textNormalizer.trimmed($0) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func buildChipStats(
        from entries: [Journal],
        itemsExtractor: (Journal) -> [Entry],
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

    func buildContinuityStats(
        from entries: [Journal],
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

            for textTheme in textNormalizer.extractThemesFromText(reflectionCorpusForContinuity(entry)) {
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

    /// Recurring chips sort by mention/day; further ties use scan order (`firstSeenOrder`) before label,
    /// matching ``sortedThemeSummaries`` for chip-only aggregates (narrative paths can still differ when text
    /// themes mix in).
    func topThemes(from summaries: [ThemeSummary]) -> [ReviewInsightTheme] {
        summaries
            .sorted {
                if $0.mentionCount != $1.mentionCount {
                    return $0.mentionCount > $1.mentionCount
                }
                if $0.dayCount != $1.dayCount {
                    return $0.dayCount > $1.dayCount
                }
                if $0.firstSeenOrder != $1.firstSeenOrder {
                    return $0.firstSeenOrder < $1.firstSeenOrder
                }
                return $0.displayLabel.localizedCaseInsensitiveCompare($1.displayLabel) == .orderedAscending
            }
            .prefix(maxThemesPerSection)
            .map { ReviewInsightTheme(label: $0.displayLabel, count: $0.mentionCount) }
    }

    func preferredItemLabel(_ item: Entry) -> String {
        textNormalizer.trimmed(item.fullText)
    }

    func accumulateTheme(
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

        let isNew = map[normalized] == nil
        var accumulator = map[normalized] ?? ThemeAccumulator(
            normalizedLabel: normalized,
            displayLabel: trimmedLabel,
            mentionCount: 0,
            weightedScore: 0,
            days: [],
            firstSeenOrder: sequence
        )
        if isNew {
            accumulator.mentionCount = 1
            accumulator.weightedScore = weight
            accumulator.days = [day]
        } else {
            accumulator.mentionCount += 1
            accumulator.weightedScore += weight
            accumulator.days.insert(day)
        }
        map[normalized] = accumulator
    }

    func sortedThemeSummaries(from map: [String: ThemeAccumulator]) -> [ThemeSummary] {
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

    // swiftlint:disable:next function_body_length function_parameter_count
    func buildWeekStats(
        currentPeriod: Range<Date>,
        entries: [Journal],
        allEntries: [Journal],
        reflectionDays: Int,
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsInterval: PastStatisticsIntervalSelection
    ) -> ReviewWeekStats {
        let meaningfulEntryCount = meaningfulEntryCount(from: entries)
        let weekStrongestByDay = ReviewHistoryWindowing.strongestCompletionByDay(from: entries, calendar: calendar)
        let completionMix = buildCompletionMix(from: weekStrongestByDay)
        let activity = buildDayActivity(
            currentPeriod: currentPeriod,
            entries: entries,
            strongestCompletionByDay: weekStrongestByDay,
            calendar: calendar
        )
        let historyRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: allEntries
        )
        let rhythmHistory = buildRhythmHistory(
            allEntries: allEntries,
            currentPeriod: currentPeriod,
            calendar: calendar,
            referenceDate: referenceDate,
            pastStatisticsHistoryLowerBound: historyRange.lowerBound
        )
        let sectionTotals = ReviewWeekSectionTotals(
            gratitudeMentions: entries.reduce(0) { $0 + ($1.gratitudes ?? []).count },
            needMentions: entries.reduce(0) { $0 + ($1.needs ?? []).count },
            peopleMentions: entries.reduce(0) { $0 + ($1.people ?? []).count }
        )
        let entriesInHistoryRange = ReviewHistoryWindowing.entriesInValidatedHistoryWindow(
            allEntries: allEntries,
            referenceDate: referenceDate,
            calendar: calendar,
            pastStatisticsInterval: pastStatisticsInterval
        )
        let historyStrongestByDay = ReviewHistoryWindowing.strongestCompletionByDay(
            from: entriesInHistoryRange,
            calendar: calendar
        )
        // Same invariant as week ``completionMix``: bucket totals sum to calendar days with ≥1 persisted
        // entry in the entry set used for the per-day strongest level (here, entries in the past-stats window).
        let historyCompletionMix = buildCompletionMix(from: historyStrongestByDay)
        let historySectionTotals = ReviewWeekSectionTotals(
            gratitudeMentions: entriesInHistoryRange.reduce(0) { $0 + ($1.gratitudes ?? []).count },
            needMentions: entriesInHistoryRange.reduce(0) { $0 + ($1.needs ?? []).count },
            peopleMentions: entriesInHistoryRange.reduce(0) { $0 + ($1.people ?? []).count }
        )
        let sections = buildThemeSections(
            from: sortedEntries(allEntries),
            currentPeriod: currentPeriod,
            calendar: calendar,
            referenceDate: referenceDate,
            mostRecurringWindow: historyRange
        )
        return ReviewWeekStats(
            reflectionDays: reflectionDays,
            meaningfulEntryCount: meaningfulEntryCount,
            completionMix: completionMix,
            activity: activity,
            rhythmHistory: rhythmHistory,
            sectionTotals: sectionTotals,
            historySectionTotals: historySectionTotals,
            historyCompletionMix: historyCompletionMix,
            mostRecurringThemes: sections.mostRecurring,
            trendingBuckets: sections.trending
        )
    }

    /// Builds a dense oldest-to-newest activity sequence through ``min(lastDayOfReviewWeek, startOfReferenceDay)``
    /// (one row per calendar day, including hollow days). Starts no earlier than the Past statistics window
    /// (``pastStatisticsHistoryLowerBound``) and applies ``RhythmHistoryLimits`` so multi-year journals cannot
    /// allocate an unbounded number of rows.
    func buildRhythmHistory(
        allEntries: [Journal],
        currentPeriod: Range<Date>,
        calendar: Calendar,
        referenceDate: Date,
        pastStatisticsHistoryLowerBound: Date
    ) -> [ReviewDayActivity]? {
        guard !allEntries.isEmpty else { return nil }

        let strongestCompletionByDay = ReviewHistoryWindowing.strongestCompletionByDay(
            from: allEntries,
            calendar: calendar
        )
        guard let weekLastInclusive = calendar.date(byAdding: .day, value: -1, to: currentPeriod.upperBound) else {
            return nil
        }
        let weekLastStart = calendar.startOfDay(for: weekLastInclusive)
        let referenceDayStart = calendar.startOfDay(for: referenceDate)
        let endDayInclusive = min(weekLastStart, referenceDayStart)
        guard let entryMinRaw = allEntries.lazy.map({ calendar.startOfDay(for: $0.entryDate) }).min() else {
            return nil
        }
        let pastWindowStart = calendar.startOfDay(for: pastStatisticsHistoryLowerBound)
        let windowClampedStart = max(entryMinRaw, pastWindowStart)
        let horizonCappedStart: Date = {
            guard
                let capped = calendar.date(
                    byAdding: .day,
                    value: -(RhythmHistoryLimits.maxInclusiveCalendarDays - 1),
                    to: endDayInclusive
                )
            else {
                return windowClampedStart
            }
            return max(windowClampedStart, calendar.startOfDay(for: capped))
        }()
        let startDay = horizonCappedStart
        guard startDay <= endDayInclusive else { return nil }

        guard let rangeEndExclusive = calendar.date(byAdding: .day, value: 1, to: endDayInclusive) else {
            return nil
        }
        let history = buildDayActivity(
            currentPeriod: startDay..<rangeEndExclusive,
            entries: allEntries,
            strongestCompletionByDay: strongestCompletionByDay,
            calendar: calendar
        )
        return history.isEmpty ? nil : history
    }

    func buildCompletionMix(from strongestByDay: [Date: JournalCompletionLevel]) -> ReviewWeekCompletionMix {
        var soilDayCount = 0
        var sproutDayCount = 0
        var twigDayCount = 0
        var leafDayCount = 0
        var bloomDayCount = 0
        for completion in strongestByDay.values {
            switch completion {
            case .soil:
                soilDayCount += 1
            case .sprout:
                sproutDayCount += 1
            case .twig:
                twigDayCount += 1
            case .leaf:
                leafDayCount += 1
            case .bloom:
                bloomDayCount += 1
            }
        }
        return ReviewWeekCompletionMix(
            soilDayCount: soilDayCount,
            sproutDayCount: sproutDayCount,
            twigDayCount: twigDayCount,
            leafDayCount: leafDayCount,
            bloomDayCount: bloomDayCount
        )
    }

    func buildDayActivity(
        currentPeriod: Range<Date>,
        entries: [Journal],
        strongestCompletionByDay: [Date: JournalCompletionLevel],
        calendar: Calendar
    ) -> [ReviewDayActivity] {
        let activeDays = Set(
            entries
                .filter(\.hasMeaningfulContent)
                .map { calendar.startOfDay(for: $0.entryDate) }
        )
        var activity: [ReviewDayActivity] = []
        var dayStart = calendar.startOfDay(for: currentPeriod.lowerBound)
        while dayStart < currentPeriod.upperBound {
            let hasPersistedEntry = strongestCompletionByDay[dayStart] != nil
            activity.append(
                ReviewDayActivity(
                    date: dayStart,
                    hasReflectiveActivity: activeDays.contains(dayStart),
                    strongestCompletionLevel: activeDays.contains(dayStart)
                        ? strongestCompletionByDay[dayStart]
                        : nil,
                    hasPersistedEntry: hasPersistedEntry
                )
            )
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                break
            }
            dayStart = calendar.startOfDay(for: nextDayStart)
        }
        return activity
    }
}

struct ThemeAccumulator {
    let normalizedLabel: String
    let displayLabel: String
    var mentionCount: Int
    var weightedScore: Int
    var days: Set<Date>
    let firstSeenOrder: Int
}

struct ThemeSurface {
    let source: ReviewThemeSourceCategory
    let content: String
}

struct DistilledThemeAccumulator {
    let canonicalConcept: String
    var displayLabel: String
    var totalCount: Int
    var days: Set<Date>
    var evidence: [ReviewThemeSurfaceEvidence]
    var evidenceIds: Set<String>
    var currentWeekCount: Int
    var previousWeekCount: Int
    let firstSeenOrder: Int

    mutating func addEvidence(_ row: ReviewThemeSurfaceEvidence) {
        guard !row.content.isEmpty else { return }
        if evidenceIds.contains(row.id) {
            return
        }
        evidence.append(row)
        evidenceIds.insert(row.id)
    }
}

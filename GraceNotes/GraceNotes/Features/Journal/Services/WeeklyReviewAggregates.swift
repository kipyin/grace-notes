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
    private let minimumMostRecurringSignalCount = 2
    private let textNormalizer = WeeklyInsightTextNormalizer()

    // swiftlint:disable:next function_parameter_count
    func build(
        currentPeriod: Range<Date>,
        currentWeekEntries: [JournalEntry],
        previousWeekEntries: [JournalEntry],
        allEntries: [JournalEntry],
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
    private func sortedEntries(_ entries: [JournalEntry]) -> [JournalEntry] {
        ReviewHistoryWindowing.sortedEntries(entries)
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
        let label = textNormalizer.trimmed(item.fullText)
        if !label.isEmpty {
            return label
        }
        return textNormalizer.trimmed(item.displayLabel)
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

    // swiftlint:disable:next function_parameter_count
    private func buildWeekStats(
        currentPeriod: Range<Date>,
        entries: [JournalEntry],
        allEntries: [JournalEntry],
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
        let historyRange = pastStatisticsInterval.validated.resolvedHistoryRange(
            referenceDate: referenceDate,
            calendar: calendar,
            allEntries: allEntries
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func buildThemeSections(
        from entries: [JournalEntry],
        currentPeriod: Range<Date>,
        calendar: Calendar,
        referenceDate: Date,
        mostRecurringWindow: Range<Date>
    ) -> (mostRecurring: [ReviewMostRecurringTheme], trending: ReviewTrendingBuckets) {
        let isWarmUpPhase = ReviewWeekTrendPolicy.isWarmUpPhase(
            currentPeriod: currentPeriod,
            referenceDate: referenceDate,
            calendar: calendar
        )
        guard !entries.isEmpty else {
            return ([], ReviewTrendingBuckets(newThemes: [], upThemes: [], downThemes: []))
        }
        let trendRanges = calendarWeekComparisonPeriods(currentPeriod: currentPeriod, calendar: calendar)
        var map: [String: DistilledThemeAccumulator] = [:]
        var sequence = 0

        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            guard mostRecurringWindow.contains(day)
                || trendRanges.current.contains(day)
                || trendRanges.previous.contains(day) else {
                continue
            }

            for surface in structuredSurfaces(for: entry) {
                let concepts = textNormalizer.distillConcepts(
                    from: surface.content,
                    source: surface.source,
                    maximumCount: 3,
                    highConfidenceOnly: true
                )
                let uniqueConcepts = Dictionary(grouping: concepts, by: \.canonicalConcept)
                    .compactMap { _, candidates in candidates.max(by: { $0.score < $1.score }) }

                for concept in uniqueConcepts {
                    var accumulator = map[concept.canonicalConcept] ?? DistilledThemeAccumulator(
                        canonicalConcept: concept.canonicalConcept,
                        displayLabel: concept.displayLabel,
                        totalCount: 0,
                        days: [],
                        evidence: [],
                        evidenceIds: [],
                        currentWeekCount: 0,
                        previousWeekCount: 0,
                        firstSeenOrder: sequence
                    )
                    if mostRecurringWindow.contains(day) {
                        accumulator.totalCount += 1
                        accumulator.days.insert(day)
                    }
                    if trendRanges.current.contains(day) {
                        accumulator.currentWeekCount += 1
                    } else if trendRanges.previous.contains(day) {
                        accumulator.previousWeekCount += 1
                    }
                    accumulator.addEvidence(
                        ReviewThemeSurfaceEvidence(
                            entryDate: day,
                            source: surface.source,
                            content: surface.content
                        )
                    )
                    map[concept.canonicalConcept] = accumulator
                }
                sequence += 1
            }
        }

        appendSupportingEvidence(
            into: &map,
            entries: entries,
            mostRecurringWindow: mostRecurringWindow,
            calendar: calendar
        )

        let mostRecurring = map.values
            .filter { $0.totalCount >= minimumMostRecurringSignalCount }
            .map { value in
                ReviewMostRecurringTheme(
                    label: value.displayLabel,
                    totalCount: value.totalCount,
                    dayCount: value.days.count,
                    currentWeekCount: value.currentWeekCount,
                    previousWeekCount: value.previousWeekCount,
                    evidence: sortedEvidence(value.evidence)
                )
            }
            .sorted {
                if $0.totalCount != $1.totalCount {
                    return $0.totalCount > $1.totalCount
                }
                if $0.dayCount != $1.dayCount {
                    return $0.dayCount > $1.dayCount
                }
                let lhsOrder = map[textNormalizer.normalizeThemeLabel($0.label)]?.firstSeenOrder ?? .max
                let rhsOrder = map[textNormalizer.normalizeThemeLabel($1.label)]?.firstSeenOrder ?? .max
                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }
                return $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
            }

        let movementCandidates = map.values
            .compactMap { value -> ReviewMovementTheme? in
                let trend = ReviewWeekTrendPolicy.trendingSurfacingTrend(
                    current: value.currentWeekCount,
                    previous: value.previousWeekCount,
                    isWarmUpPhase: isWarmUpPhase
                )
                guard trend != .stable else { return nil }
                guard value.currentWeekCount > 0 || value.previousWeekCount > 0 else { return nil }
                return ReviewMovementTheme(
                    label: value.displayLabel,
                    currentWeekCount: value.currentWeekCount,
                    previousWeekCount: value.previousWeekCount,
                    trend: trend,
                    totalCount: value.totalCount,
                    evidence: sortedEvidence(value.evidence)
                )
            }
        let trending = ReviewTrendingBuckets(
            newThemes: movementCandidates.filter { $0.trend == .new }.sorted(by: ReviewMovementTheme.trendingSort),
            upThemes: movementCandidates.filter { $0.trend == .rising }.sorted(by: ReviewMovementTheme.trendingSort),
            downThemes: movementCandidates.filter { $0.trend == .down }.sorted(by: ReviewMovementTheme.trendingSort)
        )

        return (mostRecurring, trending)
    }

    private func appendSupportingEvidence(
        into map: inout [String: DistilledThemeAccumulator],
        entries: [JournalEntry],
        mostRecurringWindow: Range<Date>,
        calendar: Calendar
    ) {
        let topLevelThemes = Array(map.keys)
        guard !topLevelThemes.isEmpty else { return }

        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            guard mostRecurringWindow.contains(day) else { continue }

            for surface in supportSurfaces(for: entry) {
                let supportConcepts = Set(
                    textNormalizer.distillConcepts(
                        from: surface.content,
                        source: surface.source,
                        maximumCount: 4,
                        highConfidenceOnly: false
                    ).map(\.canonicalConcept)
                )
                guard !supportConcepts.isEmpty else { continue }

                for theme in topLevelThemes {
                    guard var accumulator = map[theme] else { continue }
                    let matches = supportConcepts.contains(theme)
                        || textNormalizer.themesMatch(theme, against: supportConcepts)
                        || moderateSurfaceSemanticMatch(themeConcept: theme, supportText: surface.content)
                    guard matches else { continue }
                    accumulator.addEvidence(
                        ReviewThemeSurfaceEvidence(
                            entryDate: day,
                            source: surface.source,
                            content: surface.content
                        )
                    )
                    map[theme] = accumulator
                }
            }
        }
    }

    /// The current calendar week vs the immediately preceding calendar week (``ReviewInsightsPeriod``).
    private func calendarWeekComparisonPeriods(
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> (current: Range<Date>, previous: Range<Date>) {
        let previous = ReviewInsightsPeriod.previousPeriod(before: currentPeriod, calendar: calendar)
        return (currentPeriod, previous)
    }

    private func structuredSurfaces(for entry: JournalEntry) -> [ThemeSurface] {
        var surfaces: [ThemeSurface] = []

        for item in entry.gratitudes ?? [] {
            let content = textNormalizer.trimmed(item.fullText)
            if !content.isEmpty {
                surfaces.append(ThemeSurface(source: .gratitudes, content: content))
            }
        }
        for item in entry.needs ?? [] {
            let content = textNormalizer.trimmed(item.fullText)
            if !content.isEmpty {
                surfaces.append(ThemeSurface(source: .needs, content: content))
            }
        }
        for item in entry.people ?? [] {
            let content = textNormalizer.trimmed(item.fullText)
            if !content.isEmpty {
                surfaces.append(ThemeSurface(source: .people, content: content))
            }
        }

        return surfaces
    }

    private func supportSurfaces(for entry: JournalEntry) -> [ThemeSurface] {
        var surfaces: [ThemeSurface] = []
        let notes = textNormalizer.trimmed(entry.readingNotes)
        if !notes.isEmpty {
            surfaces.append(ThemeSurface(source: .readingNotes, content: notes))
        }
        let reflections = textNormalizer.trimmed(entry.reflections)
        if !reflections.isEmpty {
            surfaces.append(ThemeSurface(source: .reflections, content: reflections))
        }
        return surfaces
    }

    private func moderateSurfaceSemanticMatch(themeConcept: String, supportText: String) -> Bool {
        let normalizedSupport = textNormalizer.normalizeThemeLabel(supportText)
        guard !normalizedSupport.isEmpty else { return false }
        if normalizedSupport.contains(themeConcept) || themeConcept.contains(normalizedSupport) {
            return true
        }
        if containsHanCharacters(themeConcept) {
            return normalizedSupport.contains(themeConcept)
        }
        let themeTokens = Set(themeConcept.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let supportTokens = Set(normalizedSupport.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        if themeTokens.isEmpty || supportTokens.isEmpty {
            return false
        }
        return !themeTokens.isDisjoint(with: supportTokens)
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

    private func sortedEvidence(_ evidence: [ReviewThemeSurfaceEvidence]) -> [ReviewThemeSurfaceEvidence] {
        evidence.sorted { lhs, rhs in
            if lhs.entryDate != rhs.entryDate {
                return lhs.entryDate > rhs.entryDate
            }
            if lhs.source != rhs.source {
                return lhs.source.rawValue < rhs.source.rawValue
            }
            return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
        }
    }

    /// Builds a longer oldest-to-newest activity sequence ending on the last day of `currentPeriod`,
    /// capped for performance.
    private func buildRhythmHistory(
        allEntries: [JournalEntry],
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> [ReviewDayActivity]? {
        guard !allEntries.isEmpty else { return nil }

        let strongestCompletionByDay = ReviewHistoryWindowing.strongestCompletionByDay(
            from: allEntries,
            calendar: calendar
        )
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
}

private struct ThemeAccumulator {
    let normalizedLabel: String
    let displayLabel: String
    var mentionCount: Int
    var weightedScore: Int
    var days: Set<Date>
    let firstSeenOrder: Int
}

private struct ThemeSurface {
    let source: ReviewThemeSourceCategory
    let content: String
}

private struct DistilledThemeAccumulator {
    let canonicalConcept: String
    let displayLabel: String
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

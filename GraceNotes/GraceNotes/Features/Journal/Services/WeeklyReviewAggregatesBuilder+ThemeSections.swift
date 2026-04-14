import Foundation

extension WeeklyReviewAggregatesBuilder {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func buildThemeSections(
        from entries: [Journal],
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
        let journalCorpus = themeJournalCorpus(
            entries: entries,
            mostRecurringWindow: mostRecurringWindow,
            trendRanges: trendRanges,
            calendar: calendar
        )
        let journalThemeDisplayLocale = themeJournalLanguageResolver.resolvedDisplayLocale(
            forJournalCorpus: journalCorpus
        )
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
                // Chip lines are user-authored section text; do not require the stricter NL threshold (`true`),
                // or short labels (e.g. "rest") miss noun tagging and fail the recurring floors on some OSes.
                let concepts = textNormalizer.distillConcepts(
                    from: surface.content,
                    source: surface.source,
                    maximumCount: 3,
                    highConfidenceOnly: false,
                    journalThemeDisplayLocale: journalThemeDisplayLocale
                )
                let uniqueConcepts = Dictionary(grouping: concepts, by: \.canonicalConcept)
                    .compactMap { _, candidates in candidates.max(by: { $0.score < $1.score }) }

                for concept in uniqueConcepts {
                    let isFirstAppearance = map[concept.canonicalConcept] == nil
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
                    if isFirstAppearance {
                        sequence += 1
                    }
                }
            }
        }

        appendSupportingEvidence(
            into: &map,
            entries: entries,
            mostRecurringWindow: mostRecurringWindow,
            calendar: calendar,
            journalThemeDisplayLocale: journalThemeDisplayLocale
        )

        for canonical in Array(map.keys) {
            guard var accumulator = map[canonical] else { continue }
            let source: ReviewThemeSourceCategory =
                canonical == "mom" || canonical == "dad" ? .people : .gratitudes
            accumulator.displayLabel = textNormalizer.displayLabel(
                for: accumulator.canonicalConcept,
                source: source,
                journalThemeDisplayLocale: journalThemeDisplayLocale
            )
            map[canonical] = accumulator
        }

        let mostRecurringSorted = map.values
            .filter { $0.totalCount >= minimumMostRecurringSignalCount }
            .sorted {
                if $0.totalCount != $1.totalCount {
                    return $0.totalCount > $1.totalCount
                }
                if $0.days.count != $1.days.count {
                    return $0.days.count > $1.days.count
                }
                if $0.firstSeenOrder != $1.firstSeenOrder {
                    return $0.firstSeenOrder < $1.firstSeenOrder
                }
                return $0.canonicalConcept.localizedCaseInsensitiveCompare($1.canonicalConcept) == .orderedAscending
            }
        let mostRecurring = mostRecurringSorted.map { value in
            ReviewMostRecurringTheme(
                label: value.displayLabel,
                totalCount: value.totalCount,
                dayCount: value.days.count,
                currentWeekCount: value.currentWeekCount,
                previousWeekCount: value.previousWeekCount,
                evidence: sortedEvidence(value.evidence)
            )
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

    func appendSupportingEvidence(
        into map: inout [String: DistilledThemeAccumulator],
        entries: [Journal],
        mostRecurringWindow: Range<Date>,
        calendar: Calendar,
        journalThemeDisplayLocale: Locale
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
                        highConfidenceOnly: false,
                        journalThemeDisplayLocale: journalThemeDisplayLocale
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
    func calendarWeekComparisonPeriods(
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> (current: Range<Date>, previous: Range<Date>) {
        let previous = ReviewInsightsPeriod.previousPeriod(before: currentPeriod, calendar: calendar)
        return (currentPeriod, previous)
    }

    func themeJournalCorpus(
        entries: [Journal],
        mostRecurringWindow: Range<Date>,
        trendRanges: (current: Range<Date>, previous: Range<Date>),
        calendar: Calendar
    ) -> String {
        var parts: [String] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.entryDate)
            guard mostRecurringWindow.contains(day)
                || trendRanges.current.contains(day)
                || trendRanges.previous.contains(day) else {
                continue
            }
            for surface in structuredSurfaces(for: entry) {
                let content = textNormalizer.trimmed(surface.content)
                if !content.isEmpty {
                    parts.append(content)
                }
            }
        }
        return parts.joined(separator: "\n")
    }

    func structuredSurfaces(for entry: Journal) -> [ThemeSurface] {
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

    func supportSurfaces(for entry: Journal) -> [ThemeSurface] {
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

    func moderateSurfaceSemanticMatch(themeConcept: String, supportText: String) -> Bool {
        let normalizedSupport = textNormalizer.normalizeThemeLabel(supportText)
        let normalizedTheme = textNormalizer.normalizeThemeLabel(themeConcept)
        guard !normalizedSupport.isEmpty, !normalizedTheme.isEmpty else { return false }
        if containsHanCharacters(themeConcept) {
            return normalizedSupport.contains(normalizedTheme) || normalizedTheme.contains(normalizedSupport)
        }
        // Latin: naive `contains` matches inside other words (e.g. "rest" in "forest"); require word boundaries.
        if latinPhraseHasWordBoundaryMatch(haystack: normalizedSupport, needle: normalizedTheme)
            || latinPhraseHasWordBoundaryMatch(haystack: normalizedTheme, needle: normalizedSupport) {
            return true
        }
        let themeTokens = Set(normalizedTheme.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        let supportTokens = Set(normalizedSupport.split(separator: " ").map(String.init).filter { $0.count >= 3 })
        if themeTokens.isEmpty || supportTokens.isEmpty {
            return false
        }
        return !themeTokens.isDisjoint(with: supportTokens)
    }

    /// Whole-phrase / whole-word match for Latin script; avoids substring hits like "rest" inside "forest".
    private func latinPhraseHasWordBoundaryMatch(haystack: String, needle: String) -> Bool {
        guard needle.count <= haystack.count else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        let pattern = "\\b\(escaped)\\b"
        return haystack.range(of: pattern, options: .regularExpression) != nil
    }

    func containsHanCharacters(_ text: String) -> Bool {
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

    func sortedEvidence(_ evidence: [ReviewThemeSurfaceEvidence]) -> [ReviewThemeSurfaceEvidence] {
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
}

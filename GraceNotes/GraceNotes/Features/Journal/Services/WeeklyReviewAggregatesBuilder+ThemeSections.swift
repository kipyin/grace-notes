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

    func appendSupportingEvidence(
        into map: inout [String: DistilledThemeAccumulator],
        entries: [Journal],
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
    func calendarWeekComparisonPeriods(
        currentPeriod: Range<Date>,
        calendar: Calendar
    ) -> (current: Range<Date>, previous: Range<Date>) {
        let previous = ReviewInsightsPeriod.previousPeriod(before: currentPeriod, calendar: calendar)
        return (currentPeriod, previous)
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

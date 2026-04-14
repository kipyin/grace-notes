import Foundation

/// Inputs for ``ThemeDrilldownLineThemeResolver.distilledConceptsForLine(_:)``.
struct ThemeDrilldownLineDistillationInput: Sendable {
    let evidence: ReviewThemeSurfaceEvidence
    let journalThemeDisplayLocale: Locale
    let themeOverridePolicy: ThemeOverridePolicy
    let surfaceThemePolicy: SurfaceThemeAdjustmentPolicy
    let substitutionRules: [ThemeSubstitutionRule]
    let textNormalizer: WeeklyInsightTextNormalizer
}

/// Parameters for ``ThemeDrilldownLineThemeResolver.ensureDrilldownChipIfMissing(chips:fallback:)``.
struct ThemeDrilldownFallbackParams: Sendable {
    let drilldownCanonical: String
    let drilldownDefaultLabel: String
    let surfaceKey: String
    let themeOverridePolicy: ThemeOverridePolicy
    let surfaceThemePolicy: SurfaceThemeAdjustmentPolicy
}

/// Builds the theme chips for one journal line in Past theme drilldown, aligned with
/// ``WeeklyReviewAggregatesBuilder`` structured-surface distillation (substitution rules, per-line
/// exclusions/adds, global theme overrides).
enum ThemeDrilldownLineThemeResolver {
    /// Matches ``WeeklyReviewAggregatesBuilder+ThemeSections`` / ``appendSupportingEvidence`` caps.
    static func maximumConceptCount(for source: ReviewThemeSourceCategory) -> Int {
        switch source {
        case .readingNotes, .reflections:
            return 4
        case .gratitudes, .needs, .people:
            return 3
        }
    }

    /// Distilled + adjusted concepts for this evidence row, before ensuring the drilldown theme is present.
    static func distilledConceptsForLine(
        _ input: ThemeDrilldownLineDistillationInput
    ) -> [(concept: ReviewDistilledConcept, isManualAdd: Bool)] {
        let trimmed = input.textNormalizer.trimmed(input.evidence.content)
        guard !trimmed.isEmpty else { return [] }

        let surfaceKey = input.evidence.surfaceLineKey?.storageKey ?? ""
        let merged = mergedConceptsIncludingManualAdds(
            trimmed: trimmed,
            surfaceKey: surfaceKey,
            input: input
        )
        return applyGlobalOverrides(mergedConcepts: merged, input: input)
    }

    private static func mergedConceptsIncludingManualAdds(
        trimmed: String,
        surfaceKey: String,
        input: ThemeDrilldownLineDistillationInput
    ) -> (concepts: [ReviewDistilledConcept], manualLower: Set<String>) {
        let afterSubstitution = substitutionAndDedupe(trimmed: trimmed, input: input)
        let filtered: [ReviewDistilledConcept]
        if surfaceKey.isEmpty {
            filtered = afterSubstitution
        } else {
            filtered = afterSubstitution.filter {
                !input.surfaceThemePolicy.shouldDropConcept(
                    surfaceKey: surfaceKey,
                    canonicalConcept: $0.canonicalConcept
                )
            }
        }
        return appendManualAdds(filtered: filtered, surfaceKey: surfaceKey, input: input)
    }

    private static func substitutionAndDedupe(
        trimmed: String,
        input: ThemeDrilldownLineDistillationInput
    ) -> [ReviewDistilledConcept] {
        let maxCount = maximumConceptCount(for: input.evidence.source)
        let raw = input.textNormalizer.distillConcepts(
            from: trimmed,
            source: input.evidence.source,
            maximumCount: maxCount,
            highConfidenceOnly: false,
            journalThemeDisplayLocale: input.journalThemeDisplayLocale
        )
        let unique = Dictionary(grouping: raw, by: \.canonicalConcept)
            .compactMap { _, candidates in candidates.max(by: { $0.score < $1.score }) }
        let substituted = unique.map {
            ThemeSubstitutionRulesApplier.apply(
                to: $0,
                surfaceText: trimmed,
                rules: input.substitutionRules,
                textNormalizer: input.textNormalizer,
                source: input.evidence.source,
                journalThemeDisplayLocale: input.journalThemeDisplayLocale
            )
        }
        return Dictionary(grouping: substituted, by: \.canonicalConcept)
            .compactMap { _, candidates in candidates.max(by: { $0.score < $1.score }) }
    }

    private static func appendManualAdds(
        filtered: [ReviewDistilledConcept],
        surfaceKey: String,
        input: ThemeDrilldownLineDistillationInput
    ) -> (concepts: [ReviewDistilledConcept], manualLower: Set<String>) {
        var mergedConcepts = filtered
        var manualLower = Set<String>()
        guard !surfaceKey.isEmpty else {
            return (mergedConcepts, manualLower)
        }
        for added in input.surfaceThemePolicy.addedConcepts(for: surfaceKey) {
            let normalized = added.lowercased()
            guard !mergedConcepts.contains(where: { $0.canonicalConcept.lowercased() == normalized }) else {
                continue
            }
            mergedConcepts.append(
                ReviewDistilledConcept(
                    canonicalConcept: normalized,
                    displayLabel: input.textNormalizer.displayLabel(
                        for: normalized,
                        source: input.evidence.source,
                        journalThemeDisplayLocale: input.journalThemeDisplayLocale
                    ),
                    score: 5
                )
            )
            manualLower.insert(normalized)
        }
        return (mergedConcepts, manualLower)
    }

    private static func applyGlobalOverrides(
        mergedConcepts: (concepts: [ReviewDistilledConcept], manualLower: Set<String>),
        input: ThemeDrilldownLineDistillationInput
    ) -> [(concept: ReviewDistilledConcept, isManualAdd: Bool)] {
        var result: [(concept: ReviewDistilledConcept, isManualAdd: Bool)] = []
        for concept in mergedConcepts.concepts {
            guard let resolved = input.themeOverridePolicy.apply(concept) else { continue }
            let visible = input.themeOverridePolicy.displayLabel(
                for: resolved.canonicalConcept,
                default: resolved.displayLabel
            )
            let tagged = ReviewDistilledConcept(
                canonicalConcept: resolved.canonicalConcept,
                displayLabel: visible,
                score: resolved.score
            )
            let isManual = mergedConcepts.manualLower.contains(concept.canonicalConcept.lowercased())
            result.append((concept: tagged, isManualAdd: isManual))
        }
        return result
    }

    /// If the drilldown theme is not already present (e.g. line matched via supporting evidence only), add it.
    static func ensureDrilldownChipIfMissing(
        chips: [(concept: ReviewDistilledConcept, isManualAdd: Bool)],
        fallback: ThemeDrilldownFallbackParams
    ) -> [(concept: ReviewDistilledConcept, isManualAdd: Bool)] {
        let drilldownKey = fallback.drilldownCanonical.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !drilldownKey.isEmpty else { return chips }

        let drillLower = drilldownKey.lowercased()
        if chips.contains(where: { $0.concept.canonicalConcept.lowercased() == drillLower }) {
            return chips
        }

        let defaultLabel = fallback.themeOverridePolicy.displayLabel(
            for: drilldownKey,
            default: fallback.drilldownDefaultLabel
        )
        let synthetic = ReviewDistilledConcept(
            canonicalConcept: drilldownKey,
            displayLabel: defaultLabel,
            score: 0
        )
        guard let resolved = fallback.themeOverridePolicy.apply(synthetic) else {
            return chips
        }
        let visible = fallback.themeOverridePolicy.displayLabel(
            for: resolved.canonicalConcept,
            default: resolved.displayLabel
        )
        let tagged = ReviewDistilledConcept(
            canonicalConcept: resolved.canonicalConcept,
            displayLabel: visible,
            score: resolved.score
        )
        let dropped = !fallback.surfaceKey.isEmpty
            && fallback.surfaceThemePolicy.shouldDropConcept(
                surfaceKey: fallback.surfaceKey,
                canonicalConcept: tagged.canonicalConcept
            )
        if dropped {
            return chips
        }
        var out = chips
        out.insert((concept: tagged, isManualAdd: false), at: 0)
        return out
    }

    static func sortChipsDrilldownFirst(
        chips: [(concept: ReviewDistilledConcept, isManualAdd: Bool)],
        drilldownCanonical: String
    ) -> [(concept: ReviewDistilledConcept, isManualAdd: Bool)] {
        let drillLower = drilldownCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !drillLower.isEmpty else {
            return chips.sorted {
                $0.concept.displayLabel.localizedCaseInsensitiveCompare($1.concept.displayLabel) == .orderedAscending
            }
        }
        return chips.sorted { lhs, rhs in
            let lMatch = lhs.concept.canonicalConcept.lowercased() == drillLower
            let rMatch = rhs.concept.canonicalConcept.lowercased() == drillLower
            if lMatch != rMatch {
                return lMatch
            }
            let cmp = lhs.concept.displayLabel.localizedCaseInsensitiveCompare(rhs.concept.displayLabel)
            return cmp == .orderedAscending
        }
    }
}

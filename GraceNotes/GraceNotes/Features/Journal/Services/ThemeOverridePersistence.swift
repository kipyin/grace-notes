import Foundation

/// Local-only user adjustments for Past tab distilled themes (issue #153).
///
/// **Precedence** when applying a distilled concept:
/// 1. **Hidden** — drop the canonical concept entirely.
/// 2. **Canonical remap** — replace with another canonical before counting.
/// 3. **Display label override** — applied after aggregation when resolving visible labels.
struct ThemeOverridePolicy: Equatable, Sendable {
    let hiddenCanonicalConcepts: Set<String>
    let canonicalRemap: [String: String]
    let displayLabelOverrides: [String: String]

    static let empty = ThemeOverridePolicy(
        hiddenCanonicalConcepts: [],
        canonicalRemap: [:],
        displayLabelOverrides: [:]
    )

    /// Returns `nil` when the user chose to hide this theme.
    func apply(_ concept: ReviewDistilledConcept) -> ReviewDistilledConcept? {
        var canonical = concept.canonicalConcept
        if hiddenCanonicalConcepts.contains(canonical) {
            return nil
        }
        if let mapped = canonicalRemap[canonical] {
            canonical = mapped
        }
        if hiddenCanonicalConcepts.contains(canonical) {
            return nil
        }
        return ReviewDistilledConcept(
            canonicalConcept: canonical,
            displayLabel: concept.displayLabel,
            score: concept.score
        )
    }

    func displayLabel(for canonical: String, default resolved: String) -> String {
        let trimmedCustom = displayLabelOverrides[canonical]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedCustom.isEmpty {
            return trimmedCustom
        }
        return resolved
    }
}

struct ThemeOverridePayload: Codable, Equatable {
    var schemaVersion: Int
    var hiddenCanonicalConcepts: [String]
    var canonicalRemap: [String: String]
    var displayLabelOverrides: [String: String]

    static let empty = ThemeOverridePayload(
        schemaVersion: 1,
        hiddenCanonicalConcepts: [],
        canonicalRemap: [:],
        displayLabelOverrides: [:]
    )

    func asPolicy() -> ThemeOverridePolicy {
        ThemeOverridePolicy(
            hiddenCanonicalConcepts: Set(hiddenCanonicalConcepts),
            canonicalRemap: canonicalRemap,
            displayLabelOverrides: displayLabelOverrides
        )
    }
}

/// Thread-safe reads/writes for ``ThemeOverridePolicy`` (UserDefaults). Used from aggregation and UI.
enum ThemeOverridePersistence {
    private static let payloadKey = "GraceNotes.themeOverridePayload.v1"
    private static let revisionKey = "GraceNotes.themeOverrideRevision.v1"

    static func loadPolicy(defaults: UserDefaults = .standard) -> ThemeOverridePolicy {
        loadPayload(defaults: defaults).asPolicy()
    }

    static func currentRevision(defaults: UserDefaults = .standard) -> UInt64 {
        UInt64(defaults.integer(forKey: revisionKey))
    }

    @discardableResult
    static func save(_ payload: ThemeOverridePayload, defaults: UserDefaults = .standard) -> UInt64 {
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: payloadKey)
        } else {
            defaults.removeObject(forKey: payloadKey)
        }
        let next = UInt64(defaults.integer(forKey: revisionKey)) + 1
        defaults.set(Int(next), forKey: revisionKey)
        return next
    }

    static func loadPayload(defaults: UserDefaults = .standard) -> ThemeOverridePayload {
        guard let data = defaults.data(forKey: payloadKey) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(ThemeOverridePayload.self, from: data)
        } catch {
            defaults.removeObject(forKey: payloadKey)
            return .empty
        }
    }

    static func clearAll(defaults: UserDefaults = .standard) {
        save(.empty, defaults: defaults)
    }
}

/// Builds alternative theme labels for Past theme drilldown (issue #153).
enum ThemeDrilldownAlternativesBuilder {
    static func resolvedLocale(for evidence: [ReviewThemeSurfaceEvidence]) -> Locale {
        let corpus = evidence.map(\.content).joined(separator: "\n")
        return ReviewJournalThemeLanguageResolver().resolvedDisplayLocale(forJournalCorpus: corpus)
    }

    static func alternativeLabels(
        for primaryCanonical: String,
        evidence: [ReviewThemeSurfaceEvidence],
        locale: Locale,
        normalizer: WeeklyInsightTextNormalizer = WeeklyInsightTextNormalizer(),
        maxEvidenceLines: Int = 24,
        maxAlternatives: Int = 8
    ) -> [String] {
        var seen: Set<String> = [primaryCanonical]
        var labels: [String] = []
        for evidenceRow in evidence.prefix(maxEvidenceLines) {
            let concepts = normalizer.distillConcepts(
                from: evidenceRow.content,
                source: evidenceRow.source,
                maximumCount: 6,
                highConfidenceOnly: false,
                journalThemeDisplayLocale: locale
            )
            for concept in concepts {
                if concept.canonicalConcept != primaryCanonical, !seen.contains(concept.canonicalConcept) {
                    seen.insert(concept.canonicalConcept)
                    labels.append(concept.displayLabel)
                    if labels.count >= maxAlternatives {
                        return labels
                    }
                }
            }
        }
        return labels
    }
}

import Foundation

/// When line text contains `surfaceTextMustContain` **and** NLP emits `fromCanonical`, treat the theme as `toCanonical`.
/// First matching rule wins (order preserved in persisted array).
struct ThemeSubstitutionRule: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var isEnabled: Bool
    var surfaceTextMustContain: String
    var fromCanonical: String
    var toCanonical: String

    init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        surfaceTextMustContain: String,
        fromCanonical: String,
        toCanonical: String
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.surfaceTextMustContain = surfaceTextMustContain
        self.fromCanonical = fromCanonical
        self.toCanonical = toCanonical
    }
}

struct ThemeSubstitutionRulesPayload: Codable, Equatable {
    var schemaVersion: Int
    var rules: [ThemeSubstitutionRule]

    static let empty = ThemeSubstitutionRulesPayload(schemaVersion: 1, rules: [])
}

enum ThemeSubstitutionRulesPersistence {
    private static let payloadKey = "GraceNotes.themeSubstitutionRules.v1"
    private static let revisionKey = "GraceNotes.themeSubstitutionRulesRevision.v1"

    static func loadRules(defaults: UserDefaults = .standard) -> [ThemeSubstitutionRule] {
        loadPayload(defaults: defaults).rules.filter(\.isEnabled)
    }

    static func loadAllRules(defaults: UserDefaults = .standard) -> [ThemeSubstitutionRule] {
        loadPayload(defaults: defaults).rules
    }

    static func currentRevision(defaults: UserDefaults = .standard) -> UInt64 {
        UInt64(defaults.integer(forKey: revisionKey))
    }

    @discardableResult
    static func save(_ payload: ThemeSubstitutionRulesPayload, defaults: UserDefaults = .standard) -> UInt64 {
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: payloadKey)
        } else {
            defaults.removeObject(forKey: payloadKey)
        }
        let next = UInt64(defaults.integer(forKey: revisionKey)) + 1
        defaults.set(Int(next), forKey: revisionKey)
        return next
    }

    static func loadPayload(defaults: UserDefaults = .standard) -> ThemeSubstitutionRulesPayload {
        guard let data = defaults.data(forKey: payloadKey) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(ThemeSubstitutionRulesPayload.self, from: data)
        } catch {
            defaults.removeObject(forKey: payloadKey)
            return .empty
        }
    }

    static func clearAll(defaults: UserDefaults = .standard) {
        save(.empty, defaults: defaults)
    }
}

enum ThemeSubstitutionRulesApplier {
    /// After distillation and per-canonical de-duplication; before surface exclude/add and global overrides.
    static func apply(
        to concept: ReviewDistilledConcept,
        surfaceText: String,
        rules: [ThemeSubstitutionRule],
        textNormalizer: WeeklyInsightTextNormalizer,
        source: ReviewThemeSourceCategory,
        journalThemeDisplayLocale: Locale
    ) -> ReviewDistilledConcept {
        let normalizedContent = textNormalizer.trimmed(surfaceText)
        let fromKey = concept.canonicalConcept.lowercased()
        for rule in rules where rule.isEnabled {
            let trigger = rule.surfaceTextMustContain.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trigger.isEmpty, normalizedContent.contains(trigger) else { continue }
            guard rule.fromCanonical.lowercased() == fromKey else { continue }
            let toKey = rule.toCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !toKey.isEmpty else { continue }
            return ReviewDistilledConcept(
                canonicalConcept: toKey,
                displayLabel: textNormalizer.displayLabel(
                    for: toKey,
                    source: source,
                    journalThemeDisplayLocale: journalThemeDisplayLocale
                ),
                score: concept.score
            )
        }
        return concept
    }
}

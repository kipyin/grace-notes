import Foundation
import SwiftUI

/// Local-only user rules: when line text contains a trigger and NLP emits `from`, count as `to`.
@MainActor
final class ThemeSubstitutionRulesStore: ObservableObject {
    static let shared = ThemeSubstitutionRulesStore()

    private let defaults: UserDefaults

    @Published private(set) var revision: UInt64

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: "GraceNotes.themeSubstitutionRulesRevision.v1") == nil {
            defaults.set(0, forKey: "GraceNotes.themeSubstitutionRulesRevision.v1")
        }
        revision = ThemeSubstitutionRulesPersistence.currentRevision(defaults: defaults)
    }

    func allRules() -> [ThemeSubstitutionRule] {
        ThemeSubstitutionRulesPersistence.loadAllRules(defaults: defaults)
    }

    func upsert(_ rule: ThemeSubstitutionRule) {
        var payload = ThemeSubstitutionRulesPersistence.loadPayload(defaults: defaults)
        if let idx = payload.rules.firstIndex(where: { $0.id == rule.id }) {
            payload.rules[idx] = rule
        } else {
            payload.rules.append(rule)
        }
        revision = ThemeSubstitutionRulesPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func deleteRule(id: UUID) {
        var payload = ThemeSubstitutionRulesPersistence.loadPayload(defaults: defaults)
        payload.rules.removeAll { $0.id == id }
        revision = ThemeSubstitutionRulesPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func addRule(surfaceTextMustContain: String, fromCanonical: String, toCanonical: String) {
        let trigger = surfaceTextMustContain.trimmingCharacters(in: .whitespacesAndNewlines)
        let from = fromCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetCanonical = toCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trigger.isEmpty, !from.isEmpty, !targetCanonical.isEmpty else { return }
        let existing = allRules()
        if existing.contains(where: {
            $0.surfaceTextMustContain == trigger
                && $0.fromCanonical == from
                && $0.toCanonical == targetCanonical
        }) {
            return
        }
        upsert(
            ThemeSubstitutionRule(
                surfaceTextMustContain: trigger,
                fromCanonical: from,
                toCanonical: targetCanonical
            )
        )
    }

    /// User designates a substring of a journal line to count as another Past theme; persists a substitution rule.
    @discardableResult
    func addTokenDesignationRule(
        lineText: String,
        token: String,
        countAsPhrase: String,
        source: ReviewThemeSourceCategory,
        journalThemeDisplayLocale: Locale
    ) -> Bool {
        let line = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
        let tok = token.trimmingCharacters(in: .whitespacesAndNewlines)
        let phrase = countAsPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, !tok.isEmpty, !phrase.isEmpty else { return false }
        guard line.contains(tok) else { return false }

        let normalizer = WeeklyInsightTextNormalizer()
        let fromConcepts = normalizer.distillConcepts(
            from: tok,
            source: source,
            maximumCount: 1,
            highConfidenceOnly: false,
            journalThemeDisplayLocale: journalThemeDisplayLocale
        )
        let fromRaw = fromConcepts.first?.canonicalConcept ?? tok
        let from = fromRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let toConcepts = normalizer.distillConcepts(
            from: phrase,
            source: source,
            maximumCount: 1,
            highConfidenceOnly: false,
            journalThemeDisplayLocale: journalThemeDisplayLocale
        )
        guard let toFirst = toConcepts.first else { return false }
        let targetCanonical = toFirst.canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !from.isEmpty, !targetCanonical.isEmpty, from != targetCanonical else { return false }

        addRule(surfaceTextMustContain: tok, fromCanonical: from, toCanonical: targetCanonical)
        return true
    }

    func clearAll() {
        revision = ThemeSubstitutionRulesPersistence.save(.empty, defaults: defaults)
        objectWillChange.send()
    }

    func setRevisionForTesting(_ value: UInt64) {
        defaults.set(Int(value), forKey: "GraceNotes.themeSubstitutionRulesRevision.v1")
        revision = value
    }
}

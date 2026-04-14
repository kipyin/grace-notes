import Foundation

/// Derives a line-text trigger for ``ThemeSubstitutionRule`` when the user merges themes from drilldown.
enum ThemeSubstitutionMergeTrigger {
    /// Picks a short substring of `line` that should appear in future similar sentences.
    static func derive(line: String, fromCanonical: String, toCanonical: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let from = fromCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetCanonical = toCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, !targetCanonical.isEmpty else { return nil }

        let lowerLine = trimmed.lowercased()
        if targetCanonical.count >= 1, lowerLine.contains(targetCanonical) {
            return targetCanonical
        }
        if from.count >= 1, lowerLine.contains(from) {
            return from
        }
        if trimmed.count <= 24 {
            return trimmed
        }
        let prefix = trimmed.prefix(24)
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Records a substitution rule after a successful canonical merge from theme drilldown.
enum ThemeSubstitutionMergeRuleRecorder {
    @MainActor
    static func recordIfPossible(lineSample: String?, fromCanonical: String, toCanonicalRaw: String) {
        let from = fromCanonical.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let targetCanonical = toCanonicalRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !from.isEmpty, !targetCanonical.isEmpty, from != targetCanonical else { return }

        guard let line = lineSample?.trimmingCharacters(in: .whitespacesAndNewlines), !line.isEmpty else {
            return
        }
        guard let trigger = ThemeSubstitutionMergeTrigger.derive(
            line: line,
            fromCanonical: from,
            toCanonical: targetCanonical
        ) else {
            return
        }
        let trimmedTrigger = trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrigger.isEmpty else { return }
        ThemeSubstitutionRulesStore.shared.addRule(
            surfaceTextMustContain: trimmedTrigger,
            fromCanonical: from,
            toCanonical: targetCanonical
        )
    }
}

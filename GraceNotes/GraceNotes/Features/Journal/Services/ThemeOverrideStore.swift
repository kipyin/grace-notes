import Foundation
import SwiftUI

/// UI-facing store for Past theme corrections; persistence is ``ThemeOverridePersistence`` (issue #153).
@MainActor
final class ThemeOverrideStore: ObservableObject {
    static let shared = ThemeOverrideStore()

    private let defaults: UserDefaults

    /// Bumps whenever overrides change so Past insights refresh and the disk cache key rotates.
    @Published private(set) var revision: UInt64

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: "GraceNotes.themeOverrideRevision.v1") == nil {
            defaults.set(0, forKey: "GraceNotes.themeOverrideRevision.v1")
        }
        revision = ThemeOverridePersistence.currentRevision(defaults: defaults)
    }

    func currentPolicy() -> ThemeOverridePolicy {
        ThemeOverridePersistence.loadPolicy(defaults: defaults)
    }

    func hideTheme(canonicalConcept: String) {
        var payload = ThemeOverridePersistence.loadPayload(defaults: defaults)
        let trimmed = canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !payload.hiddenCanonicalConcepts.contains(trimmed) {
            payload.hiddenCanonicalConcepts.append(trimmed)
        }
        payload.canonicalRemap.removeValue(forKey: trimmed)
        payload.displayLabelOverrides.removeValue(forKey: trimmed)
        revision = ThemeOverridePersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func setDisplayLabelOverride(canonicalConcept: String, displayLabel: String) {
        var payload = ThemeOverridePersistence.loadPayload(defaults: defaults)
        let canonical = canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = displayLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonical.isEmpty, !label.isEmpty else { return }
        payload.displayLabelOverrides[canonical] = label
        revision = ThemeOverridePersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func setCanonicalRemap(from sourceCanonical: String, to targetCanonical: String) {
        var payload = ThemeOverridePersistence.loadPayload(defaults: defaults)
        let from = sourceCanonical.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let target = targetCanonical.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !from.isEmpty, !target.isEmpty else { return }
        if from == target {
            payload.canonicalRemap.removeValue(forKey: from)
        } else {
            payload.canonicalRemap[from] = target
        }
        revision = ThemeOverridePersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func clearAll() {
        revision = ThemeOverridePersistence.save(.empty, defaults: defaults)
        objectWillChange.send()
    }

    func setRevisionForTesting(_ value: UInt64) {
        defaults.set(Int(value), forKey: "GraceNotes.themeOverrideRevision.v1")
        revision = value
    }
}

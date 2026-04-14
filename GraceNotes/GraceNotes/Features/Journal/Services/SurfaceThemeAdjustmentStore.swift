import Foundation
import SwiftUI

/// Per-line Past theme adjustments; bumps revision so ``ReviewInsights`` and cache keys refresh.
@MainActor
final class SurfaceThemeAdjustmentStore: ObservableObject {
    static let shared = SurfaceThemeAdjustmentStore()

    private let defaults: UserDefaults

    @Published private(set) var revision: UInt64

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: "GraceNotes.surfaceThemeAdjustmentsRevision.v1") == nil {
            defaults.set(0, forKey: "GraceNotes.surfaceThemeAdjustmentsRevision.v1")
        }
        revision = SurfaceThemeAdjustmentPersistence.currentRevision(defaults: defaults)
    }

    func currentPolicy() -> SurfaceThemeAdjustmentPolicy {
        SurfaceThemeAdjustmentPersistence.loadPolicy(defaults: defaults)
    }

    /// Excludes a canonical theme from counts for this surface only (does not change global theme overrides).
    func excludeCanonical(_ canonicalConcept: String, surfaceKey: String) {
        let canonical = canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = surfaceKey
        guard !canonical.isEmpty, !key.isEmpty else { return }
        var payload = SurfaceThemeAdjustmentPersistence.loadPayload(defaults: defaults)
        var excluded = Set(payload.excludedCanonicalsBySurface[key, default: []].map { $0.lowercased() })
        excluded.insert(canonical)
        payload.excludedCanonicalsBySurface[key] = Array(excluded)
        revision = SurfaceThemeAdjustmentPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func removeExclusion(for canonicalConcept: String, surfaceKey: String) {
        let canonical = canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let key = surfaceKey
        guard !canonical.isEmpty, !key.isEmpty else { return }
        var payload = SurfaceThemeAdjustmentPersistence.loadPayload(defaults: defaults)
        var excluded = Set(payload.excludedCanonicalsBySurface[key, default: []].map { $0.lowercased() })
        excluded.remove(canonical)
        if excluded.isEmpty {
            payload.excludedCanonicalsBySurface.removeValue(forKey: key)
        } else {
            payload.excludedCanonicalsBySurface[key] = Array(excluded)
        }
        revision = SurfaceThemeAdjustmentPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    /// Resolves a short phrase through Past distillation and attaches the canonical theme to this line only.
    @discardableResult
    func addCanonicalFromUserPhrase(
        _ phrase: String,
        surfaceKey: String,
        source: ReviewThemeSourceCategory,
        journalThemeDisplayLocale: Locale
    ) -> Bool {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !surfaceKey.isEmpty else { return false }
        let normalizer = WeeklyInsightTextNormalizer()
        let concepts = normalizer.distillConcepts(
            from: trimmed,
            source: source,
            maximumCount: 3,
            highConfidenceOnly: false,
            journalThemeDisplayLocale: journalThemeDisplayLocale
        )
        guard let first = concepts.first else { return false }
        let canonical = first.canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !canonical.isEmpty else { return false }

        var payload = SurfaceThemeAdjustmentPersistence.loadPayload(defaults: defaults)
        var added = Set(payload.addedCanonicalsBySurface[surfaceKey, default: []].map { $0.lowercased() })
        added.insert(canonical)
        payload.addedCanonicalsBySurface[surfaceKey] = Array(added)

        var excluded = Set(payload.excludedCanonicalsBySurface[surfaceKey, default: []].map { $0.lowercased() })
        excluded.remove(canonical)
        if excluded.isEmpty {
            payload.excludedCanonicalsBySurface.removeValue(forKey: surfaceKey)
        } else {
            payload.excludedCanonicalsBySurface[surfaceKey] = Array(excluded)
        }

        revision = SurfaceThemeAdjustmentPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
        return true
    }

    func removeAddedCanonical(_ canonicalConcept: String, surfaceKey: String) {
        let canonical = canonicalConcept.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !canonical.isEmpty, !surfaceKey.isEmpty else { return }
        var payload = SurfaceThemeAdjustmentPersistence.loadPayload(defaults: defaults)
        var added = Set(payload.addedCanonicalsBySurface[surfaceKey, default: []].map { $0.lowercased() })
        added.remove(canonical)
        if added.isEmpty {
            payload.addedCanonicalsBySurface.removeValue(forKey: surfaceKey)
        } else {
            payload.addedCanonicalsBySurface[surfaceKey] = Array(added)
        }
        revision = SurfaceThemeAdjustmentPersistence.save(payload, defaults: defaults)
        objectWillChange.send()
    }

    func clearAll() {
        revision = SurfaceThemeAdjustmentPersistence.save(.empty, defaults: defaults)
        objectWillChange.send()
    }

    func setRevisionForTesting(_ value: UInt64) {
        defaults.set(Int(value), forKey: "GraceNotes.surfaceThemeAdjustmentsRevision.v1")
        revision = value
    }
}

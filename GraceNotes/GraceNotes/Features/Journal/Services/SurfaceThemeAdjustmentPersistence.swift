import Foundation

/// Per-line Past theme adjustments (issue #153 follow-up). Applied after distillation, before weekly aggregation.
///
/// **Precedence:** User exclusions for a surface win over automatic concepts for that line only.
struct SurfaceThemeAdjustmentPolicy: Equatable, Sendable {
    /// surfaceKey -> canonical concepts the user excluded from this line
    let excludedCanonicalsBySurface: [String: Set<String>]
    /// surfaceKey -> extra canonical concepts the user added for this line
    let addedCanonicalsBySurface: [String: Set<String>]

    static let empty = SurfaceThemeAdjustmentPolicy(
        excludedCanonicalsBySurface: [:],
        addedCanonicalsBySurface: [:]
    )

    func shouldDropConcept(surfaceKey: String, canonicalConcept: String) -> Bool {
        let normalized = canonicalConcept.lowercased()
        return excludedCanonicalsBySurface[surfaceKey]?.contains(normalized) ?? false
    }

    func addedConcepts(for surfaceKey: String) -> Set<String> {
        addedCanonicalsBySurface[surfaceKey] ?? []
    }
}

struct SurfaceThemeAdjustmentPayload: Codable, Equatable {
    var schemaVersion: Int
    var excludedCanonicalsBySurface: [String: [String]]
    var addedCanonicalsBySurface: [String: [String]]

    static let empty = SurfaceThemeAdjustmentPayload(
        schemaVersion: 1,
        excludedCanonicalsBySurface: [:],
        addedCanonicalsBySurface: [:]
    )

    func asPolicy() -> SurfaceThemeAdjustmentPolicy {
        SurfaceThemeAdjustmentPolicy(
            excludedCanonicalsBySurface: Dictionary(
                uniqueKeysWithValues: excludedCanonicalsBySurface.map { key, value in
                    (key, Set(value.map { $0.lowercased() }))
                }
            ),
            addedCanonicalsBySurface: Dictionary(
                uniqueKeysWithValues: addedCanonicalsBySurface.map { key, value in
                    (key, Set(value.map { $0.lowercased() }))
                }
            )
        )
    }
}

enum SurfaceThemeAdjustmentPersistence {
    private static let payloadKey = "GraceNotes.surfaceThemeAdjustments.v1"
    private static let revisionKey = "GraceNotes.surfaceThemeAdjustmentsRevision.v1"

    static func loadPolicy(defaults: UserDefaults = .standard) -> SurfaceThemeAdjustmentPolicy {
        loadPayload(defaults: defaults).asPolicy()
    }

    static func currentRevision(defaults: UserDefaults = .standard) -> UInt64 {
        UInt64(defaults.integer(forKey: revisionKey))
    }

    @discardableResult
    static func save(_ payload: SurfaceThemeAdjustmentPayload, defaults: UserDefaults = .standard) -> UInt64 {
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: payloadKey)
        } else {
            defaults.removeObject(forKey: payloadKey)
        }
        let next = UInt64(defaults.integer(forKey: revisionKey)) + 1
        defaults.set(Int(next), forKey: revisionKey)
        return next
    }

    static func loadPayload(defaults: UserDefaults = .standard) -> SurfaceThemeAdjustmentPayload {
        guard let data = defaults.data(forKey: payloadKey) else {
            return .empty
        }
        do {
            return try JSONDecoder().decode(SurfaceThemeAdjustmentPayload.self, from: data)
        } catch {
            defaults.removeObject(forKey: payloadKey)
            return .empty
        }
    }

    static func clearAll(defaults: UserDefaults = .standard) {
        save(.empty, defaults: defaults)
    }
}

import Foundation

/// Stable identity for one authored line or one notes block used in Past theme distillation.
enum SurfaceLineKey: Hashable, Sendable, Codable {
    /// A chip row in Gratitudes, Needs, or People in Mind.
    case chip(journalId: UUID, source: ReviewThemeSourceCategory, entryLineId: UUID)
    /// Whole reading notes or reflections text for a day (no per-line id).
    case noteBlock(journalId: UUID, source: ReviewThemeSourceCategory)

    /// Persisted lookup key for UserDefaults-backed adjustments.
    var storageKey: String {
        switch self {
        case .chip(let journalId, let source, let entryLineId):
            return "\(journalId.uuidString)|\(source.rawValue)|\(entryLineId.uuidString)"
        case .noteBlock(let journalId, let source):
            return "\(journalId.uuidString)|\(source.rawValue)|noteBlock"
        }
    }
}

extension ReviewThemeSurfaceEvidence {
    /// Stable key for per-line theme adjustments; `nil` for legacy rows without journal identity.
    var surfaceLineKey: SurfaceLineKey? {
        guard let journalId else { return nil }
        switch source {
        case .readingNotes, .reflections:
            return .noteBlock(journalId: journalId, source: source)
        case .gratitudes, .needs, .people:
            guard let entryLineId else { return nil }
            return .chip(journalId: journalId, source: source, entryLineId: entryLineId)
        }
    }
}

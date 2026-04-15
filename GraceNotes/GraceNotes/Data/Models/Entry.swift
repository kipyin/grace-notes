import Foundation

/// Chip line item. Persisted composite uses the type name ``JournalItem`` inside stored journal rows.
struct JournalItem: Codable {
    var id: UUID
    var fullText: String

    init(fullText: String, id: UUID = UUID()) {
        self.id = id
        self.fullText = fullText
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let entryLabel = try container.decodeIfPresent(String.self, forKey: .entryLabel)
        let chipLabel = try container.decodeIfPresent(String.self, forKey: .chipLabel)
        if let full = try container.decodeIfPresent(String.self, forKey: .fullText) {
            let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                fullText = trimmed
            } else {
                // Legacy rows may omit meaningful `fullText` but still carry `entryLabel` / `chipLabel` (see export import).
                fullText = Self.firstNonEmptyTrimmed(entryLabel, chipLabel)
            }
        } else {
            fullText = Self.firstNonEmptyTrimmed(entryLabel, chipLabel)
        }
        _ = try container.decodeIfPresent(Bool.self, forKey: .isTruncated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullText, forKey: .fullText)
    }

    /// First non-empty string after trimming; order matches legacy `JournalDataExportItem` preference (`entryLabel` then `chipLabel`).
    private static func firstNonEmptyTrimmed(_ entryLabel: String?, _ chipLabel: String?) -> String {
        for candidate in [entryLabel, chipLabel] {
            guard let candidate else { continue }
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return ""
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullText
        case entryLabel
        case chipLabel
        case isTruncated
    }
}

typealias Entry = JournalItem

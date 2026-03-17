import Foundation

struct JournalItem: Codable {
    var id: UUID
    var fullText: String
    var chipLabel: String?
    var isTruncated: Bool

    init(fullText: String, chipLabel: String? = nil, isTruncated: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.fullText = fullText
        self.chipLabel = chipLabel
        self.isTruncated = isTruncated
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fullText = try container.decode(String.self, forKey: .fullText)
        chipLabel = try container.decodeIfPresent(String.self, forKey: .chipLabel)
        isTruncated = try container.decodeIfPresent(Bool.self, forKey: .isTruncated) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullText, forKey: .fullText)
        try container.encodeIfPresent(chipLabel, forKey: .chipLabel)
        try container.encode(isTruncated, forKey: .isTruncated)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullText
        case chipLabel
        case isTruncated
    }

    var displayLabel: String {
        if let label = chipLabel, !label.isEmpty { return label }
        return fullText
    }
}

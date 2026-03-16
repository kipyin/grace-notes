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
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fullText = try c.decode(String.self, forKey: .fullText)
        chipLabel = try c.decodeIfPresent(String.self, forKey: .chipLabel)
        isTruncated = try c.decodeIfPresent(Bool.self, forKey: .isTruncated) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(fullText, forKey: .fullText)
        try c.encodeIfPresent(chipLabel, forKey: .chipLabel)
        try c.encode(isTruncated, forKey: .isTruncated)
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

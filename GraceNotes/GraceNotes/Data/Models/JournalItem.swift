import Foundation

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
        fullText = try container.decode(String.self, forKey: .fullText)
        _ = try container.decodeIfPresent(String.self, forKey: .chipLabel)
        _ = try container.decodeIfPresent(Bool.self, forKey: .isTruncated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fullText, forKey: .fullText)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fullText
        case chipLabel
        case isTruncated
    }
}

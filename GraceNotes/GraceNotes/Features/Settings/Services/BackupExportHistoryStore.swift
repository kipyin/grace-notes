import Foundation

struct BackupExportHistoryEntry: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case manualShare
        case manualFolder
        case scheduledFolder
    }

    let id: UUID
    let finishedAt: Date
    let success: Bool
    let kind: Kind
    let detail: String?
}

enum BackupExportHistoryStore {
    private static let userDefaultsKey = "BackupExportHistory.entries"
    private static let maxEntries = 40

    static func record(
        finishedAt: Date = .now,
        success: Bool,
        kind: BackupExportHistoryEntry.Kind,
        detail: String? = nil
    ) {
        var entries = load()
        entries.insert(
            BackupExportHistoryEntry(
                id: UUID(),
                finishedAt: finishedAt,
                success: success,
                kind: kind,
                detail: detail
            ),
            at: 0
        )
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }

    static func load() -> [BackupExportHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode([BackupExportHistoryEntry].self, from: data) else {
            return []
        }
        return decoded
    }
}

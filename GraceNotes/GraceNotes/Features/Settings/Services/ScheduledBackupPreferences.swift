import Foundation

enum ScheduledBackupInterval: String, CaseIterable, Codable {
    case off
    case daily
    case weekly
    case biweekly
    case monthly

    func isDue(lastRun: Date?, now: Date, calendar: Calendar = .current) -> Bool {
        guard self != .off else { return false }
        guard let lastRun else { return true }
        let startLast = calendar.startOfDay(for: lastRun)
        let startNow = calendar.startOfDay(for: now)
        let dayDelta = calendar.dateComponents([.day], from: startLast, to: startNow).day ?? 0
        switch self {
        case .off:
            return false
        case .daily:
            return dayDelta >= 1
        case .weekly:
            return dayDelta >= 7
        case .biweekly:
            return dayDelta >= 14
        case .monthly:
            return dayDelta >= 30
        }
    }
}

enum ScheduledBackupPreferences {
    private static let intervalKey = "ScheduledBackup.intervalRaw"
    private static let bookmarkKey = "ScheduledBackup.folderBookmark"
    private static let folderDisplayNameKey = "ScheduledBackup.folderDisplayName"
    private static let lastRunKey = "ScheduledBackup.lastRunAt"

    static var interval: ScheduledBackupInterval {
        get {
            guard let raw = UserDefaults.standard.string(forKey: intervalKey),
                  let value = ScheduledBackupInterval(rawValue: raw) else {
                return .off
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: intervalKey)
        }
    }

    static var folderBookmarkData: Data? {
        get { UserDefaults.standard.data(forKey: bookmarkKey) }
        set { UserDefaults.standard.set(newValue, forKey: bookmarkKey) }
    }

    /// Best-effort folder title from the last successful folder pick (`lastPathComponent`).
    static var folderDisplayName: String? {
        get {
            let value = UserDefaults.standard.string(forKey: folderDisplayNameKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            if let newValue, !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                UserDefaults.standard.set(newValue, forKey: folderDisplayNameKey)
            } else {
                UserDefaults.standard.removeObject(forKey: folderDisplayNameKey)
            }
        }
    }

    static var lastRunAt: Date? {
        get { UserDefaults.standard.object(forKey: lastRunKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastRunKey) }
    }

    static func storeFolderBookmark(for url: URL) throws {
        let data = try url.bookmarkData(
            options: [.minimalBookmark],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        folderBookmarkData = data
        let name = url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            folderDisplayName = name
        }
    }

    static func resolveFolderURL() throws -> URL {
        guard let bookmark = folderBookmarkData else {
            throw ScheduledBackupError.noFolderBookmark
        }
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: bookmark,
            options: [.withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale {
            throw ScheduledBackupError.staleBookmark
        }
        return url
    }

    static func isDue(now: Date = .now) -> Bool {
        interval.isDue(lastRun: lastRunAt, now: now)
    }
}

enum ScheduledBackupError: Error, Equatable {
    case noFolderBookmark
    case staleBookmark
    case exportFailed
}

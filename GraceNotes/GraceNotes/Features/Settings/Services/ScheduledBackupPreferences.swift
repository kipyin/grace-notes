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

/// How long JSON backups are kept in the scheduled backup folder before automatic age-based removal.
enum BackupRetentionPeriod: String, CaseIterable, Codable, Sendable {
    case days7
    case days30
    case days90
    case days365
    case forever

    /// Delete files with modification date before this instant; `nil` means no age-based pruning.
    func ageCutoff(from now: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .forever:
            return nil
        case .days7:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .days30:
            return calendar.date(byAdding: .day, value: -30, to: now)
        case .days90:
            return calendar.date(byAdding: .day, value: -90, to: now)
        case .days365:
            return calendar.date(byAdding: .day, value: -365, to: now)
        }
    }
}

/// Preset maximum total size for JSON files in the scheduled backup folder (`unlimited` → no size pruning).
enum BackupFolderSizeCap: String, CaseIterable, Codable, Sendable {
    case mb25
    case mb100
    case mb500
    case gb2
    case unlimited

    /// Upper bound on total JSON size; `nil` means no cap.
    var maxBytes: Int64? {
        switch self {
        case .mb25:
            return 25 * 1024 * 1024
        case .mb100:
            return 100 * 1024 * 1024
        case .mb500:
            return 500 * 1024 * 1024
        case .gb2:
            return 2 * 1024 * 1024 * 1024
        case .unlimited:
            return nil
        }
    }
}

enum ScheduledBackupPreferences {
    /// After a failed scheduled backup, wait this long before `isDue` returns true again.
    /// Export history still records each attempt.
    static let failureBackoff: TimeInterval = 60 * 60

    private static let intervalKey = "ScheduledBackup.intervalRaw"
    private static let bookmarkKey = "ScheduledBackup.folderBookmark"
    private static let folderDisplayNameKey = "ScheduledBackup.folderDisplayName"
    private static let lastRunKey = "ScheduledBackup.lastRunAt"
    private static let lastFailedAttemptKey = "ScheduledBackup.lastFailedAttemptAt"
    private static let retentionKey = "ScheduledBackup.retentionRaw"
    private static let sizeCapKey = "ScheduledBackup.sizeCapRaw"

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

    static var lastFailedAttemptAt: Date? {
        get { UserDefaults.standard.object(forKey: lastFailedAttemptKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: lastFailedAttemptKey) }
    }

    static var backupRetentionPeriod: BackupRetentionPeriod {
        get {
            guard let raw = UserDefaults.standard.string(forKey: retentionKey),
                  let value = BackupRetentionPeriod(rawValue: raw) else {
                return .days30
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: retentionKey)
        }
    }

    static var backupFolderSizeCap: BackupFolderSizeCap {
        get {
            guard let raw = UserDefaults.standard.string(forKey: sizeCapKey),
                  let value = BackupFolderSizeCap(rawValue: raw) else {
                return .mb500
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sizeCapKey)
        }
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
            try storeFolderBookmark(for: url)
        }
        return url
    }

    /// Whether `fileURL` lies inside the bookmarked backup folder (for security-scoped reads via the folder bookmark).
    static func fileURLIsUnderScheduledBackupFolder(_ fileURL: URL) -> Bool {
        guard let folderURL = try? resolveFolderURL() else { return false }
        let folderPath = folderURL.standardizedFileURL.path
        let path = fileURL.standardizedFileURL.path
        return path != folderPath && path.hasPrefix(folderPath + "/")
    }

    /// Runs `body` while the resolved backup folder holds an active security scope.
    static func withFolderSecurityScopedAccess<T>(_ body: (URL) throws -> T) throws -> T {
        let folderURL = try resolveFolderURL()
        guard folderURL.startAccessingSecurityScopedResource() else {
            throw ScheduledBackupError.securityScopeDenied
        }
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        return try body(folderURL)
    }

    static func isDue(now: Date = .now) -> Bool {
        guard interval != .off else { return false }
        if let lastFail = lastFailedAttemptAt,
           now.timeIntervalSince(lastFail) < failureBackoff {
            return false
        }
        return interval.isDue(lastRun: lastRunAt, now: now)
    }
}

enum ScheduledBackupError: Error, Equatable {
    case noFolderBookmark
    case staleBookmark
    case exportFailed
    case securityScopeDenied
}

import Foundation
import os
import SwiftData

private let scheduledBackupLogger = Logger(
    subsystem: "com.gracenotes.GraceNotes",
    category: "ScheduledBackup"
)

/// Prevents overlapping scheduled backup runs until `runIfDue` finishes, including MainActor
/// bookkeeping (`lastRunAt`, export history). Each `active` transition spawns a new `Task` in ``GraceNotesApp``.
private final class ScheduledBackupSingleFlight: @unchecked Sendable {
    private let lock = NSLock()
    private var inFlight = false

    func tryBegin() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !inFlight else { return false }
        inFlight = true
        return true
    }

    func end() {
        lock.lock()
        defer { lock.unlock() }
        inFlight = false
    }
}

private let scheduledBackupSingleFlight = ScheduledBackupSingleFlight()

enum ScheduledBackupRunner {
    /// Writes a JSON export into the user’s appointed folder when the schedule says it is time.
    static func runIfDue(modelContainer: ModelContainer) async {
        let interval = ScheduledBackupPreferences.interval
        guard interval != .off else { return }
        guard ScheduledBackupPreferences.isDue() else { return }

        do {
            _ = try ScheduledBackupPreferences.resolveFolderURL()
        } catch {
            await recordScheduledFailure(detail: String(localized: "settings.dataPrivacy.scheduledBackup.folderError"))
            return
        }

        guard scheduledBackupSingleFlight.tryBegin() else { return }
        defer { scheduledBackupSingleFlight.end() }

        let result = await Task.detached(priority: .utility) {
            Self.performScheduledExport(modelContainer: modelContainer)
        }.value

        switch result {
        case .success(let fileName):
            await MainActor.run {
                ScheduledBackupPreferences.lastRunAt = Date()
                ScheduledBackupPreferences.lastFailedAttemptAt = nil
                BackupExportHistoryStore.record(
                    success: true,
                    kind: .scheduledFolder,
                    detail: fileName
                )
            }
        case .exportFailed:
            await recordScheduledFailure(
                detail: String(localized: "settings.dataPrivacy.scheduledBackup.failureDetail")
            )
        case .copyFailed(let error):
            let detail = failureDetail(for: error)
            await recordScheduledFailure(detail: detail)
        }
    }

    private enum ScheduledExportResult {
        case success(String)
        case exportFailed
        case copyFailed(Error)
    }

    /// Export to a temp file, copy into the backup folder, then delete the temp file — all on the same background task.
    private static func performScheduledExport(modelContainer: ModelContainer) -> ScheduledExportResult {
        let exportDate = Date()
        let exportResult = exportToTemporaryFile(modelContainer: modelContainer, exportDate: exportDate)
        let tempFile: URL
        switch exportResult {
        case .success(let url):
            tempFile = url
        case .failure:
            return .exportFailed
        }
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }
        do {
            let fileName = try copyScheduledExportToFolder(tempFile: tempFile, exportDate: exportDate)
            return .success(fileName)
        } catch {
            return .copyFailed(error)
        }
    }

    private static func copyScheduledExportToFolder(tempFile: URL, exportDate: Date) throws -> String {
        try ScheduledBackupPreferences.withFolderSecurityScopedAccess { folderURL in
            let name = try copyTempExport(at: tempFile, to: folderURL, exportDate: exportDate)
            do {
                try BackupFolderLibrary.prune(
                    folderURL: folderURL,
                    now: exportDate,
                    retention: ScheduledBackupPreferences.backupRetentionPeriod,
                    maxTotalBytes: ScheduledBackupPreferences.backupFolderSizeCap.maxBytes
                )
            } catch {
                // Copy already succeeded; pruning is best-effort so the run still counts as success.
                let detail = String(describing: error)
                scheduledBackupLogger.error(
                    "Backup folder prune failed after successful copy. \(detail, privacy: .public)"
                )
            }
            return name
        }
    }

    private static func copyTempExport(at tempFile: URL, to folderURL: URL, exportDate: Date) throws -> String {
        let stamp = JournalDataExportService().exportFilenameTimestamp(for: exportDate)
        // UUID avoids same-second overwrites (copyTempFile replaces an existing destination name).
        let name = "grace-notes-scheduled-\(stamp)-\(UUID().uuidString).json"
        return try BackupFolderJSONExport.copyTempFile(
            tempFile,
            into: folderURL,
            destinationFileName: name,
            fileManager: .default
        )
    }

    private static func failureDetail(for error: Error) -> String {
        if let scheduled = error as? ScheduledBackupError {
            switch scheduled {
            case .noFolderBookmark, .securityScopeDenied:
                return String(localized: "settings.dataPrivacy.scheduledBackup.folderError")
            case .staleBookmark, .exportFailed:
                return String(localized: "settings.dataPrivacy.scheduledBackup.failureDetail")
            }
        }
        return String(localized: "settings.dataPrivacy.scheduledBackup.failureDetail")
    }

    private enum ExportToTempResult {
        case success(URL)
        case failure
    }

    private static func exportToTemporaryFile(modelContainer: ModelContainer, exportDate: Date) -> ExportToTempResult {
        do {
            let exportService = JournalDataExportService()
            let backgroundContext = ModelContext(modelContainer)
            let tempFile = try exportService.exportArchiveFile(context: backgroundContext, now: exportDate)
            return .success(tempFile)
        } catch {
            let detail = String(describing: error)
            scheduledBackupLogger.error(
                "Scheduled backup export to temp file failed. \(detail, privacy: .public)"
            )
            return .failure
        }
    }

    private static func recordScheduledFailure(detail: String) async {
        await MainActor.run {
            ScheduledBackupPreferences.lastFailedAttemptAt = Date()
            BackupExportHistoryStore.record(
                success: false,
                kind: .scheduledFolder,
                detail: detail
            )
        }
    }
}

struct BackupFolderFileMetadata: Equatable {
    let url: URL
    let modificationDate: Date
    let fileSize: Int64
}

enum BackupFolderLibrary {
    static func listExportFiles(in folder: URL, fileManager: FileManager = .default) throws -> [URL] {
        try listJSONMetadata(in: folder, fileManager: fileManager)
            .sorted { lhs, rhs in
                if lhs.modificationDate != rhs.modificationDate {
                    return lhs.modificationDate > rhs.modificationDate
                }
                let order = lhs.url.lastPathComponent.localizedStandardCompare(rhs.url.lastPathComponent)
                return order == .orderedDescending
            }
            .map(\.url)
    }

    /// Oldest files first (tie-breaker: path) for pruning and oldest-first deletion.
    static func listJSONMetadataOldestFirst(
        in folder: URL,
        fileManager: FileManager = .default
    ) throws -> [BackupFolderFileMetadata] {
        try listJSONMetadata(in: folder, fileManager: fileManager)
            .sorted { lhs, rhs in
                if lhs.modificationDate != rhs.modificationDate {
                    return lhs.modificationDate < rhs.modificationDate
                }
                let order = lhs.url.lastPathComponent.localizedStandardCompare(rhs.url.lastPathComponent)
                return order == .orderedAscending
            }
    }

    private static func listJSONMetadata(
        in folder: URL,
        fileManager: FileManager
    ) throws -> [BackupFolderFileMetadata] {
        let urls = try fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        let jsonURLs = urls.filter { $0.pathExtension.lowercased() == "json" }
        var result: [BackupFolderFileMetadata] = []
        result.reserveCapacity(jsonURLs.count)
        for url in jsonURLs {
            let date: Date
            let size: Int64
            do {
                let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                date = values.contentModificationDate ?? .distantPast
                size = Int64(values.fileSize ?? 0)
            } catch {
                date = .distantPast
                size = 0
            }
            result.append(BackupFolderFileMetadata(url: url, modificationDate: date, fileSize: size))
        }
        return result
    }

    static func deleteFiles(at urls: [URL], fileManager: FileManager = .default) throws {
        for url in urls {
            try fileManager.removeItem(at: url)
        }
    }

    /// Removes JSON backups outside the retention window (oldest first),
    /// then trims by total size (oldest first) if a cap is set.
    static func prune(
        folderURL: URL,
        now: Date,
        retention: BackupRetentionPeriod,
        maxTotalBytes: Int64?,
        calendar: Calendar = .current,
        fileManager: FileManager = .default
    ) throws {
        if let cutoff = retention.ageCutoff(from: now, calendar: calendar) {
            let meta = try listJSONMetadataOldestFirst(in: folderURL, fileManager: fileManager)
            for file in meta where file.modificationDate < cutoff {
                try fileManager.removeItem(at: file.url)
            }
        }

        guard let maxBytes = maxTotalBytes else { return }

        let remaining = try listJSONMetadataOldestFirst(in: folderURL, fileManager: fileManager)
        var total = remaining.reduce(Int64(0)) { $0 + $1.fileSize }
        var index = 0
        while total > maxBytes, index < remaining.count {
            let oldest = remaining[index]
            try fileManager.removeItem(at: oldest.url)
            total -= oldest.fileSize
            index += 1
        }
    }
}

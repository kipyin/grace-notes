import Foundation
import SwiftData

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
        let exportResult = exportToTemporaryFile(modelContainer: modelContainer)
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
            let fileName = try copyScheduledExportToFolder(tempFile: tempFile)
            return .success(fileName)
        } catch {
            return .copyFailed(error)
        }
    }

    private static func copyScheduledExportToFolder(tempFile: URL) throws -> String {
        try ScheduledBackupPreferences.withFolderSecurityScopedAccess { folderURL in
            try copyTempExport(at: tempFile, to: folderURL)
        }
    }

    private static func copyTempExport(at tempFile: URL, to folderURL: URL) throws -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        // UUID avoids same-second overwrites (copyTempFile replaces an existing destination name).
        let name = "grace-notes-scheduled-\(formatter.string(from: .now))-\(UUID().uuidString).json"
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

    private static func exportToTemporaryFile(modelContainer: ModelContainer) -> ExportToTempResult {
        do {
            let exportService = JournalDataExportService()
            let backgroundContext = ModelContext(modelContainer)
            let tempFile = try exportService.exportArchiveFile(context: backgroundContext)
            return .success(tempFile)
        } catch {
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

enum BackupFolderLibrary {
    static func listExportFiles(in folder: URL) throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let json = urls.filter { $0.pathExtension.lowercased() == "json" }
        return json.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                ?? .distantPast
            if left != right {
                return left > right
            }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedDescending
        }
    }
}

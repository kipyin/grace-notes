import Foundation
import SwiftData

enum ScheduledBackupRunner {
    /// Writes a JSON export into the user’s appointed folder when the schedule says it is time.
    static func runIfDue(modelContainer: ModelContainer) async {
        let interval = ScheduledBackupPreferences.interval
        guard interval != .off else { return }
        guard ScheduledBackupPreferences.isDue() else { return }

        let folderURL: URL
        do {
            folderURL = try ScheduledBackupPreferences.resolveFolderURL()
        } catch {
            await recordScheduledFailure(detail: String(localized: "settings.dataPrivacy.scheduledBackup.folderError"))
            return
        }

        guard folderURL.startAccessingSecurityScopedResource() else {
            await recordScheduledFailure(detail: String(localized: "settings.dataPrivacy.scheduledBackup.folderError"))
            return
        }
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }

        let exportResult = await Task.detached(priority: .utility) {
            Self.exportToTemporaryFile(modelContainer: modelContainer)
        }.value

        let tempFile: URL
        switch exportResult {
        case .success(let url):
            tempFile = url
        case .failure:
            await recordScheduledFailure(detail: String(localized: "settings.dataPrivacy.scheduledBackup.failureDetail"))
            return
        }
        defer {
            try? FileManager.default.removeItem(at: tempFile)
        }

        do {
            let fileName = try copyTempExport(at: tempFile, to: folderURL)
            await MainActor.run {
                ScheduledBackupPreferences.lastRunAt = Date()
                ScheduledBackupPreferences.lastFailedAttemptAt = nil
                BackupExportHistoryStore.record(
                    success: true,
                    kind: .scheduledFolder,
                    detail: fileName
                )
            }
        } catch {
            await recordScheduledFailure(detail: String(localized: "settings.dataPrivacy.scheduledBackup.failureDetail"))
        }
    }

    private static func copyTempExport(at tempFile: URL, to folderURL: URL) throws -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "grace-notes-scheduled-\(formatter.string(from: .now)).json"
        return try BackupFolderJSONExport.copyTempFile(
            tempFile,
            into: folderURL,
            destinationFileName: name,
            fileManager: .default
        )
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
            return left > right
        }
    }
}

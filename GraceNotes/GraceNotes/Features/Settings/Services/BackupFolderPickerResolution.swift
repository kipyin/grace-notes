import Foundation

enum BackupFolderPickerResolution {
    /// On-disk folder name (not localized—consistent across locales for iCloud Drive / Files).
    static let subfolderName = "Grace Notes Backup"

    enum ResolutionError: Error {
        /// A file (or other non-directory) already occupies the resolved path.
        case pathComponentIsNotDirectory(URL)
    }

    static func resolvedFolderURL(
        userPicked: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let standardized = userPicked.standardizedFileURL
        if standardized.lastPathComponent == subfolderName {
            return try ensureDirectoryExistsOrCreate(at: standardized, fileManager: fileManager)
        }
        try requireDirectoryIfExists(at: standardized, fileManager: fileManager)
        let child = standardized.appendingPathComponent(subfolderName, isDirectory: true)
        return try ensureDirectoryExistsOrCreate(at: child, fileManager: fileManager)
    }

    /// Returns without error when nothing exists at `url` (caller may create a path below it).
    private static func requireDirectoryIfExists(at url: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return }
        guard isDirectory.boolValue else {
            throw ResolutionError.pathComponentIsNotDirectory(url)
        }
    }

    private static func ensureDirectoryExistsOrCreate(at url: URL, fileManager: FileManager) throws -> URL {
        try requireDirectoryIfExists(at: url, fileManager: fileManager)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            return url
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

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
        let child = standardized.appendingPathComponent(subfolderName, isDirectory: true)
        return try ensureDirectoryExistsOrCreate(at: child, fileManager: fileManager)
    }

    private static func ensureDirectoryExistsOrCreate(at url: URL, fileManager: FileManager) throws -> URL {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue else {
                throw ResolutionError.pathComponentIsNotDirectory(url)
            }
            return url
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

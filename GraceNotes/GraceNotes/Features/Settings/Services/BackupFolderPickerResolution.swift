import Foundation

enum BackupFolderPickerResolution {
    /// On-disk folder name (not localized—consistent across locales for iCloud Drive / Files).
    static let subfolderName = "Grace Notes Backup"

    enum ResolutionError: Error {
        /// A file (or other non-directory) already occupies the resolved path.
        case pathComponentIsNotDirectory(URL)
    }

    private enum PathKind {
        case missing
        case directory
        case notDirectory
    }

    private static func pathKind(at url: URL, fileManager: FileManager) -> PathKind {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return .missing
        }
        return isDirectory.boolValue ? .directory : .notDirectory
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
        switch pathKind(at: url, fileManager: fileManager) {
        case .missing, .directory:
            return
        case .notDirectory:
            throw ResolutionError.pathComponentIsNotDirectory(url)
        }
    }

    private static func ensureDirectoryExistsOrCreate(at url: URL, fileManager: FileManager) throws -> URL {
        switch pathKind(at: url, fileManager: fileManager) {
        case .notDirectory:
            throw ResolutionError.pathComponentIsNotDirectory(url)
        case .directory:
            return url
        case .missing:
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                return url
            } catch {
                switch pathKind(at: url, fileManager: fileManager) {
                case .directory:
                    return url
                case .notDirectory:
                    throw ResolutionError.pathComponentIsNotDirectory(url)
                case .missing:
                    throw error
                }
            }
        }
    }
}

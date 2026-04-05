import Foundation

enum BackupFolderPickerResolution {
    /// On-disk folder name (not localized—consistent across locales for iCloud Drive / Files).
    static let subfolderName = "Grace Notes Backup"

    static func resolvedFolderURL(
        userPicked: URL,
        fileManager: FileManager = .default
    ) throws -> URL {
        let standardized = userPicked.standardizedFileURL
        if standardized.lastPathComponent == subfolderName {
            if !fileManager.fileExists(atPath: standardized.path) {
                try fileManager.createDirectory(at: standardized, withIntermediateDirectories: true)
            }
            return standardized
        }
        let child = standardized.appendingPathComponent(subfolderName, isDirectory: true)
        if !fileManager.fileExists(atPath: child.path) {
            try fileManager.createDirectory(at: child, withIntermediateDirectories: true)
        }
        return child
    }
}

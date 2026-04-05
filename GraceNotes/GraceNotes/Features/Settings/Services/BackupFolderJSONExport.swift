import Foundation

enum BackupFolderJSONExport {
    /// Copies a temp export into `folderURL` and returns the destination **file name** (not full path).
    static func copyTempFile(
        _ tempFileURL: URL,
        into folderURL: URL,
        destinationFileName: String,
        fileManager: FileManager = .default
    ) throws -> String {
        let destination = folderURL.appendingPathComponent(destinationFileName, isDirectory: false)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: tempFileURL, to: destination)
        return destination.lastPathComponent
    }
}

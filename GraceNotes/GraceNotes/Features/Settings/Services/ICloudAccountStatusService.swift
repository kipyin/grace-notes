import CloudKit
import Foundation
import os

private let iCloudAccountStatusLogger = Logger(
    subsystem: "com.gracenotes.GraceNotes",
    category: "ICloudAccountStatus"
)

/// Live `CKContainer.accountStatus()` bridge; `accountStatus()` suspends without blocking the caller.
final class ICloudAccountStatusService: ICloudAccountStatusProviding {
    private let containerIdentifier: String

    init(containerIdentifier: String = "iCloud.com.gracenotes.GraceNotes") {
        self.containerIdentifier = containerIdentifier
    }

    func fetchAccountBucket() async -> ICloudAccountBucket {
        let container = CKContainer(identifier: containerIdentifier)
        do {
            let status = try await container.accountStatus()
            return ICloudAccountBucket(status)
        } catch {
            if !isCancellationLike(error) {
                let detail = error.localizedDescription
                iCloudAccountStatusLogger.error(
                    "Failed to fetch iCloud account status. \(detail, privacy: .public)"
                )
            }
            return .couldNotDetermine
        }
    }
}

/// CloudKit may report cancellation as `CKError.operationCancelled`; URL loading as `URLError.cancelled`, not only
/// `CancellationError`.
private func isCancellationLike(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let ckError = error as? CKError, ckError.code == .operationCancelled { return true }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
}

extension ICloudAccountBucket {
    init(_ status: CKAccountStatus) {
        switch status {
        case .available:
            self = .available
        case .noAccount:
            self = .noAccount
        case .restricted:
            self = .restricted
        case .temporarilyUnavailable:
            self = .temporarilyUnavailable
        case .couldNotDetermine:
            self = .couldNotDetermine
        @unknown default:
            self = .couldNotDetermine
        }
    }
}

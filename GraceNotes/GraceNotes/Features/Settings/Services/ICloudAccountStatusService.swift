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
            if !(error is CancellationError) {
                let detail = error.localizedDescription
                iCloudAccountStatusLogger.error(
                    "Failed to fetch iCloud account status. \(detail, privacy: .public)"
                )
            }
            return .couldNotDetermine
        }
    }
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

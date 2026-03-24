import CloudKit
import Foundation

/// Live `CKContainer.accountStatus()` bridge; work runs off the main actor.
final class ICloudAccountStatusService: ICloudAccountStatusProviding {
    private let containerIdentifier: String

    init(containerIdentifier: String = "iCloud.com.gracenotes.GraceNotes") {
        self.containerIdentifier = containerIdentifier
    }

    func fetchAccountBucket() async -> ICloudAccountBucket {
        await Task.detached(priority: .utility) { [containerIdentifier] in
            let container = CKContainer(identifier: containerIdentifier)
            do {
                let status = try await container.accountStatus()
                return ICloudAccountBucket(status)
            } catch {
                return .couldNotDetermine
            }
        }.value
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

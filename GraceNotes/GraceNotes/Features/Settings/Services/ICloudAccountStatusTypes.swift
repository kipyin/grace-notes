import Foundation

/// Designer-facing bucket for iCloud account reachability. Does not assert journal sync completeness.
enum ICloudAccountBucket: Sendable, Equatable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case couldNotDetermine
}

extension ICloudAccountBucket {
    /// `false` when the user cannot change iCloud sync in Settings (toggle hidden).
    var showsICloudSyncToggle: Bool {
        switch self {
        case .noAccount, .restricted:
            return false
        case .available, .temporarilyUnavailable, .couldNotDetermine:
            return true
        }
    }
}

protocol ICloudAccountStatusProviding {
    func fetchAccountBucket() async -> ICloudAccountBucket
}

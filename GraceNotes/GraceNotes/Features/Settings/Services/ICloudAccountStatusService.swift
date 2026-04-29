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
            let status = try await Task(priority: .utility) {
                try await container.accountStatus()
            }.value
            return ICloudAccountBucket(status)
        } catch {
            if !isCancellationLike(error) {
                let nsError = error as NSError
                iCloudAccountStatusLogger.error(
                    """
                    Failed to fetch iCloud account status. \
                    type=\(String(describing: type(of: error)), privacy: .public) \
                    domain=\(nsError.domain, privacy: .public) \
                    code=\(nsError.code, privacy: .public)
                    """
                )
            }
            return .couldNotDetermine
        }
    }
}

/// CloudKit may report cancellation as `CKError.Code.operationCancelled`; URL loading as `URLError.cancelled`, not only
/// `CancellationError`.
internal func isCancellationLike(_ error: Error) -> Bool {
    isCancellationLikeRecursively(error, depth: 0)
}

private let underlyingErrorsUserInfoKey = "NSUnderlyingErrorsKey"

private func isDirectCancellationMatch(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let ckError = error as? CKError, ckError.code == .operationCancelled { return true }

    let nsError = error as NSError
    if nsError.domain == CKError.errorDomain, nsError.code == CKError.Code.operationCancelled.rawValue {
        return true
    }
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
}

private func isCancellationInUnderlyingErrorsArray(_ nsError: NSError, depth: Int) -> Bool {
    guard let raw = nsError.userInfo[underlyingErrorsUserInfoKey] else { return false }
    if let errors = raw as? [Error] {
        return errors.contains { isCancellationLikeRecursively($0, depth: depth + 1) }
    }
    guard let array = raw as? NSArray else { return false }
    for idx in 0..<array.count {
        if let underlying = array[idx] as? Error, isCancellationLikeRecursively(underlying, depth: depth + 1) {
            return true
        }
    }
    return false
}

private func isCancellationLikeRecursively(_ error: Error, depth: Int) -> Bool {
    guard depth < 32 else { return false }
    if isDirectCancellationMatch(error) { return true }

    let nsError = error as NSError
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
       isCancellationLikeRecursively(underlying, depth: depth + 1) {
        return true
    }
    return isCancellationInUnderlyingErrorsArray(nsError, depth: depth)
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

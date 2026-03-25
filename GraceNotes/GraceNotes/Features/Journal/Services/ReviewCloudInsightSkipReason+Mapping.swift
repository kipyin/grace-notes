import Foundation

extension ReviewCloudInsightSkipReason {
    /// Maps a thrown error from the cloud review-insights path into a user-facing skip reason.
    static func fromCloudFailure(_ error: Error) -> ReviewCloudInsightSkipReason {
        if let cloud = error as? CloudReviewInsightsError {
            return mapCloudReviewInsightsError(cloud)
        }
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, let mapped = mapNSURLFailureCode(nsError.code) {
            return mapped
        }
        return .cloudGenerationFailed
    }

    private static func mapCloudReviewInsightsError(_ error: CloudReviewInsightsError) -> ReviewCloudInsightSkipReason {
        switch error {
        case .insufficientContext:
            return .insufficientEvidenceThisWeek
        case .failedQualityGate:
            return .cloudInsightQualityCheckFailed
        case .invalidURL:
            return .cloudGenerationFailed
        case .invalidResponse, .missingContent, .invalidPayload:
            return .cloudResponseNotUsable
        case .httpError(let statusCode):
            return mapHTTPStatusCode(statusCode)
        }
    }

    private static func mapHTTPStatusCode(_ code: Int) -> ReviewCloudInsightSkipReason {
        switch code {
        case 401, 403, 429:
            return .cloudServiceAuthOrQuota
        case 500...599:
            return .cloudServiceTemporarilyUnavailable
        case 408:
            return .cloudRequestTimedOut
        case 400..<500:
            return .cloudResponseNotUsable
        default:
            return .cloudResponseNotUsable
        }
    }

    private static func mapURLError(_ error: URLError) -> ReviewCloudInsightSkipReason {
        mapNSURLFailureCode(error.code.rawValue) ?? .cloudGenerationFailed
    }

    private static func mapNSURLFailureCode(_ code: Int) -> ReviewCloudInsightSkipReason? {
        switch code {
        case NSURLErrorTimedOut:
            return .cloudRequestTimedOut
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorCannotConnectToHost,
             NSURLErrorDataNotAllowed,
             NSURLErrorInternationalRoamingOff:
            return .cloudNetworkUnavailable
        default:
            return nil
        }
    }
}

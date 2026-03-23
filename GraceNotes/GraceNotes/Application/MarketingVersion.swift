import Foundation

/// Compares dotted marketing versions (e.g. `CFBundleShortVersionString`).
enum MarketingVersion {
    /// Release that introduced version-gated upgrade orientation (see onboarding roadmap).
    static let orientationReleaseAnchor = "0.5.1"

    /// `.orderedAscending` if `lhs` is strictly less than `rhs`.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let partsLeft = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let partsRight = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(partsLeft.count, partsRight.count)
        for index in 0..<count {
            let leftPart = index < partsLeft.count ? partsLeft[index] : 0
            let rightPart = index < partsRight.count ? partsRight[index] : 0
            if leftPart < rightPart { return .orderedAscending }
            if leftPart > rightPart { return .orderedDescending }
        }
        return .orderedSame
    }
}

extension Bundle {
    var graceNotesMarketingVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

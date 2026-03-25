import Foundation

/// Compares dotted marketing versions (e.g. `CFBundleShortVersionString`).
enum MarketingVersion {
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

/// Marketing + bundle pair for the release that introduced version-gated upgrade orientation (`0.5.0` / build 7).
enum OrientationReleaseGate {
    static let marketingVersion = "0.5.0"
    static let bundleVersion = 7

    /// Prior process launch is strictly before `(marketingVersion, bundleVersion)`.
    /// When `storedBundle` is missing and marketing equals `marketingVersion`, treats bundle as `0` (migration from builds that only persisted marketing).
    static func isPriorLaunchBeforeRelease(marketing: String, storedBundle: Int?) -> Bool {
        let versusAnchor = MarketingVersion.compare(marketing, marketingVersion)
        if versusAnchor == .orderedAscending { return true }
        if versusAnchor == .orderedDescending { return false }
        let effectiveBundle = storedBundle ?? 0
        return effectiveBundle < bundleVersion
    }

    /// Current launch is at or after `(marketingVersion, bundleVersion)`. Nil bundle counts as `0`.
    static func isCurrentLaunchAtOrAfterRelease(marketing: String, bundle: Int?) -> Bool {
        let versusAnchor = MarketingVersion.compare(marketing, marketingVersion)
        if versusAnchor == .orderedDescending { return true }
        if versusAnchor == .orderedAscending { return false }
        let effectiveBundle = bundle ?? 0
        return effectiveBundle >= bundleVersion
    }
}

extension Bundle {
    var graceNotesMarketingVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var graceNotesBundleVersion: Int? {
        if let str = infoDictionary?["CFBundleVersion"] as? String {
            let head = str.split(separator: ".").first.map(String.init) ?? str
            return Int(head)
        }
        if let num = infoDictionary?["CFBundleVersion"] as? Int {
            return num
        }
        return nil
    }
}

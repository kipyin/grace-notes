import Foundation

/// Cloud summarization API key resolution order:
/// 1) Info.plist `CloudSummarizationAPIKey`
/// 2) Placeholder (`YOUR_KEY_HERE`) which disables cloud use
///
/// Keep real credentials out of git. Prefer a local, untracked plist override.
enum ApiSecrets {
    private static let placeholderApiKey = "YOUR_KEY_HERE"

    /// True when the resolved bundle key is non-placeholder (cloud route may be used if user enables it).
    static var isCloudApiKeyConfigured: Bool {
        isUsableCloudApiKey(cloudApiKey)
    }

    /// True for a non-empty, non-placeholder API key string (used for injected keys in tests).
    static func isUsableCloudApiKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != placeholderApiKey
    }

    static let cloudApiKey: String = {
        let infoPlistKey = Bundle.main.object(
            forInfoDictionaryKey: "CloudSummarizationAPIKey"
        ) as? String
        let trimmedInfoPlistKey = infoPlistKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedInfoPlistKey, !trimmedInfoPlistKey.isEmpty {
            return trimmedInfoPlistKey
        }

        return placeholderApiKey
    }()
}

import Foundation

/// Cloud summarization API key resolution order:
/// 1) `FIVE_CUBED_CLOUD_API_KEY` environment variable
/// 2) Info.plist `CloudSummarizationAPIKey`
/// 3) Placeholder (`YOUR_KEY_HERE`) which disables cloud use
///
/// Keep real credentials out of git. Prefer local environment variables or an untracked plist.
enum ApiSecrets {
    private static let placeholderApiKey = "YOUR_KEY_HERE"

    static let cloudApiKey: String = {
        let environmentKey = ProcessInfo.processInfo.environment["FIVE_CUBED_CLOUD_API_KEY"]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let environmentKey, !environmentKey.isEmpty {
            return environmentKey
        }

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

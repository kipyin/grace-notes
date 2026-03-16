import Foundation

/// Default API key for cloud summarization. Replace with your key. With "YOUR_KEY_HERE",
/// API calls will fail and the app falls back to on-device NL.
///
/// Safer workflows for real keys: (1) Commit an `ApiSecrets.example.swift` with placeholders
/// and add `ApiSecrets.swift` to .gitignore; or (2) Source the key from an xcconfig or
/// Secrets.plist excluded from git.
enum ApiSecrets {
    static let cloudApiKey = "YOUR_KEY_HERE"
}

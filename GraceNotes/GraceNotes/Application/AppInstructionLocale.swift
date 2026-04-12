import Foundation

/// Which natural language to use for cloud LLM *instructions* (not user-facing `Localizable` strings).
/// Matches Review chip insights: follow the app bundle’s active UI localization.
enum AppInstructionLocale: Equatable, Sendable {
    case english
    case simplifiedChinese

    /// `zh-Hans` → Simplified Chinese; otherwise English (default for future locales until prompts exist).
    static func preferred(bundle: Bundle = .main) -> AppInstructionLocale {
        guard let preferred = bundle.preferredLocalizations.first else {
            return .english
        }
        if isSimplifiedChineseUIIdentifier(preferred) {
            return .simplifiedChinese
        }
        return .english
    }

    /// BCP 47 tags are case-insensitive; `Bundle` may return `zh-Hans` or `zh-hans`.
    /// Require `zh-Hans` as a full tag or as the language-script prefix before the next subtag (`zh-Hans-CN`, …), not `zh-Hant`.
    private static func isSimplifiedChineseUIIdentifier(_ identifier: String) -> Bool {
        let tag = identifier.lowercased()
        return tag == "zh-hans" || tag.hasPrefix("zh-hans-")
    }
}

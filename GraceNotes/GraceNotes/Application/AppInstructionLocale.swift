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

    /// Uses `Locale.Language` so tags with explicit scripts (e.g. `zh-Hans`, `zh-Hant`, `zh_CN` when
    /// Foundation infers a script) are handled without brittle `zh-hans` / `zh-hans-` string prefix checks.
    ///
    /// **Script inference:** When `Locale.Language(identifier:)` supplies a `script`, we treat
    /// `Hans` as Simplified Chinese. Foundation does not infer Hans vs Hant from region alone for
    /// scriptless identifiers—e.g. bare `zh` typically has no script and falls through to English
    /// prompts here, matching the old `zh-hans` prefix behavior. If the product ever needs
    /// “unspecified Chinese → follow region” (e.g. infer Hans from `CN`), add an explicit rule in
    /// this function; do not rely on Foundation to do that in the guards below.
    private static func isSimplifiedChineseUIIdentifier(_ identifier: String) -> Bool {
        let language = Locale.Language(identifier: identifier)
        guard language.languageCode?.identifier == "zh" else {
            return false
        }
        guard let script = language.script?.identifier else {
            // No script: bare `zh` / legacy forms Foundation leaves scriptless → English instructions.
            return false
        }
        return script.caseInsensitiveCompare("Hans") == .orderedSame
    }

    private static let simplifiedChineseScript = Locale.Script("Hans")
}

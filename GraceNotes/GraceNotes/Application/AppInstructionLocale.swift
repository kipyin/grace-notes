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

    /// Uses `Locale.Language` so legacy tags (`zh_CN`, `zh_Hans_CN`) and bare `zh` resolve like the system,
    /// instead of brittle `zh-hans` / `zh-hans-` string prefix checks that miss underscore forms.
    private static func isSimplifiedChineseUIIdentifier(_ identifier: String) -> Bool {
        let language = Locale.Language(identifier: identifier)
        guard language.languageCode?.identifier == "zh" else {
            return false
        }
        guard let script = language.script?.identifier else {
            return false
        }
        return script.caseInsensitiveCompare("Hans") == .orderedSame
    }
}

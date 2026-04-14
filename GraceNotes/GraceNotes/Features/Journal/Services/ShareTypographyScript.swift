import Foundation

/// Latin vs system CJK typography for share cards (`zh` / `ja` / `ko` locale languages).
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    case chinese
}

extension ShareTypographyScript {
    /// Consults the app bundle’s active UI language before the system locale, so CJK typography
    /// applies when the app is localized to Chinese/Japanese/Korean even if the device language is English.
    static func current(bundle: Bundle = .main) -> ShareTypographyScript {
        let languages: [Locale.Language] = bundle.preferredLocalizations.map { Locale.Language(identifier: $0) }
            + [Locale.current.language]
        for language in languages where isCJK(language.languageCode) {
            return .chinese
        }
        return .latin
    }

    private static func isCJK(_ code: Locale.LanguageCode?) -> Bool {
        switch code?.identifier {
        case "zh", "ja", "ko":
            return true
        default:
            return false
        }
    }
}

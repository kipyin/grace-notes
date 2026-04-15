import Foundation

/// Latin vs system CJK typography for share cards (`zh` / `ja` / `ko` locale languages).
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    /// System CJK typography path for zh / ja / ko share cards (not “Chinese-only”).
    case cjk
}

extension ShareTypographyScript {
    /// Consults the app bundle’s active UI language before the system locale, so CJK typography
    /// applies when the app is localized to Chinese/Japanese/Korean even if the device language is English.
    ///
    /// Uses only the bundle’s first preferred localization (the active UI language), not the full
    /// `preferredLocalizations` list, which can include additional user languages that are not the app UI.
    /// - Parameters:
    ///   - bundle: App bundle (or another bundle in extensions).
    ///   - preferredUILocalizationIdentifier: Overrides `bundle.preferredLocalizations.first` for tests
    ///     or custom bundle resolution; pass `nil` for production.
    ///   - systemLanguage: Device/system language; override in tests instead of relying on `Locale.current`.
    static func current(
        bundle: Bundle = .main,
        preferredUILocalizationIdentifier: String? = nil,
        systemLanguage: Locale.Language = Locale.current.language
    ) -> ShareTypographyScript {
        let uiIdentifier = preferredUILocalizationIdentifier ?? bundle.preferredLocalizations.first
        var languages: [Locale.Language] = []
        if let uiIdentifier {
            languages.append(Locale.Language(identifier: uiIdentifier))
        }
        languages.append(systemLanguage)
        for language in languages where isCJK(language) {
            return .cjk
        }
        return .latin
    }

    /// Maps a concrete locale’s base language code (for tests and direct locale-driven layout).
    static func forLocale(_ locale: Locale) -> ShareTypographyScript {
        switch locale.language.languageCode?.identifier {
        case "zh", "ja", "ko":
            return .cjk
        default:
            return .latin
        }
    }

    private static func isCJK(_ language: Locale.Language) -> Bool {
        switch resolvedBaseLanguageCode(for: language) {
        case "zh", "ja", "ko":
            return true
        default:
            return false
        }
    }

    /// Prefer `Locale.Language.languageCode`, then the same derived from a `Locale` wrapper, then the
    /// leading BCP‑47 tag (covers rare cases where `languageCode` is nil but the identifier is still CJK).
    private static func resolvedBaseLanguageCode(for language: Locale.Language) -> String? {
        if let code = language.languageCode?.identifier {
            return code
        }
        let viaLocale = Locale(identifier: language.maximalIdentifier).language.languageCode?.identifier
        if let viaLocale {
            return viaLocale
        }
        return language.maximalIdentifier
            .split { $0 == "-" || $0 == "_" }
            .first
            .map(String.init)?
            .lowercased()
    }
}

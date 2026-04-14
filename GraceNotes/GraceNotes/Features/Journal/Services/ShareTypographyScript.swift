import Foundation

/// Latin vs system CJK typography for share cards (`zh` / `ja` / `ko` locale languages).
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    case chinese
}

extension ShareTypographyScript {
    /// Pure CJK vs Latin selection for unit tests and stable behavior vs `Locale.current`.
    static func forLanguageCode(_ languageCode: Locale.LanguageCode?) -> ShareTypographyScript {
        switch languageCode {
        case .some(.chinese), .some(.japanese), .some(.korean):
            return .chinese
        default:
            return .latin
        }
    }

    static func current() -> ShareTypographyScript {
        forLanguageCode(Locale.current.language.languageCode)
    }
}

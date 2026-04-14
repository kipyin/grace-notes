import Foundation

/// Latin vs system CJK typography for share cards (`zh` / `ja` / `ko` locale languages).
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    /// System CJK typography path for zh / ja / ko share cards (not “Chinese-only”).
    case cjk
}

extension ShareTypographyScript {
    static func forLocale(_ locale: Locale) -> ShareTypographyScript {
        switch locale.language.languageCode?.identifier {
        case "zh", "ja", "ko":
            return .cjk
        default:
            return .latin
        }
    }

    static func current() -> ShareTypographyScript {
        forLocale(.current)
    }
}

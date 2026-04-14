import Foundation

/// Latin vs system CJK typography for share cards (`zh` / `ja` / `ko` locale languages).
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    case chinese
}

extension ShareTypographyScript {
    static func current() -> ShareTypographyScript {
        switch Locale.current.language.languageCode {
        case .some(.chinese), .some(.japanese), .some(.korean):
            return .chinese
        default:
            return .latin
        }
    }
}

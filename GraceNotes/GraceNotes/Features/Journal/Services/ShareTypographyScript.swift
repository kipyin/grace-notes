import Foundation

/// Latin vs Chinese typography for share cards.
/// Figma uses Noto for zh; we approximate CJK with system serif/sans to avoid multi‑MB font bundles.
enum ShareTypographyScript: Equatable, Sendable {
    case latin
    case chinese
}

extension ShareTypographyScript {
    static func current() -> ShareTypographyScript {
        if Locale.current.identifier.hasPrefix("zh") {
            return .chinese
        }
        return .latin
    }
}

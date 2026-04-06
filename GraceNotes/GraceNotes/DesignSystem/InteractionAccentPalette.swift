import SwiftUI
import UIKit

/// Accent roles for controls and Past review chrome, resolved from ``AccentPreference``.
struct InteractionAccentPalette: Equatable {
    var accent: Color
    var accentText: Color
    var onAccent: Color
    /// Adaptive Past/review accent (search highlights, links, app tour on settings-like surfaces).
    var reviewAccent: Color
    var activeEditingAccent: Color
    var activeEditingAccentStrong: Color

    /// Baseline terracotta; matches ``AppTheme`` defaults.
    static let terracotta = InteractionAccentPalette(
        accent: Color(hex: 0xC77B5B),
        accentText: Color(hex: 0x8A4A34),
        onAccent: Color(hex: 0x1F1A16),
        reviewAccent: Color.adaptive(lightHex: 0xC77B5B, darkHex: 0xD89D82),
        activeEditingAccent: Color(hex: 0xB07358),
        activeEditingAccentStrong: Color(hex: 0x7B4835)
    )

    /// Deep green accent; harmonizes with completion tones without replacing tier semantics.
    static let forest = InteractionAccentPalette(
        accent: Color(hex: 0x4F6B52),
        accentText: Color(hex: 0x344936),
        onAccent: Color(hex: 0x121A14),
        reviewAccent: Color.adaptive(lightHex: 0x4F6B52, darkHex: 0x8BA88E),
        activeEditingAccent: Color(hex: 0x435A46),
        activeEditingAccentStrong: Color(hex: 0x2C3D2E)
    )

    static func resolve(_ preference: AccentPreference) -> InteractionAccentPalette {
        switch preference {
        case .terracotta:
            return .terracotta
        case .forest:
            return .forest
        }
    }
}

// MARK: - Primary / secondary chrome (Settings, onboarding, App Tour)

extension InteractionAccentPalette {
    /// Filled primary control: Try again, Begin, App Tour Next/Done custom chrome.
    var primaryProminentFill: Color { accent }

    /// Label on ``primaryProminentFill``. Adaptive so Settings light/dark stays readable on saturated fills.
    var primaryProminentForeground: Color {
        Color.adaptive(lightHex: 0xF8F4EF, darkHex: 0xF8F4EF)
    }

    /// Bordered secondary and date-picker tint (matches former `reminderSecondaryActionTint` role).
    var secondaryControlTint: Color { accentText }
}

// MARK: - Color Hex (shared with Theme.swift pattern)

private extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    static func adaptive(lightHex: UInt, darkHex: UInt) -> Color {
        Color(
            UIColor { traitCollection in
                let colorHex = traitCollection.userInterfaceStyle == .dark ? darkHex : lightHex
                return UIColor(hex: colorHex)
            }
        )
    }
}

private extension UIColor {
    convenience init(hex: UInt) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: 1)
    }
}

private struct InteractionAccentPaletteKey: EnvironmentKey {
    static let defaultValue = InteractionAccentPalette.terracotta
}

extension EnvironmentValues {
    /// Resolved interaction accent; mirrors ``AppTheme`` terracotta baseline when unset.
    var interactionAccentPalette: InteractionAccentPalette {
        get { self[InteractionAccentPaletteKey.self] }
        set { self[InteractionAccentPaletteKey.self] = newValue }
    }
}

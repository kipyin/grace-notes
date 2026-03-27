import SwiftUI
import UIKit

enum AppTheme {
    // MARK: - Colors

    static let background = Color(hex: 0xF8F4EF)
    static let paper = Color(hex: 0xF5EDE4)
    static let textPrimary = Color(hex: 0x2C2C2C)
    static let textMuted = Color(hex: 0x5C5346)
    static let accent = Color(hex: 0xC77B5B)
    static let accentText = Color(hex: 0x8A4A34)
    static let onAccent = Color(hex: 0x1F1A16)
    static let activeEditingAccent = Color(hex: 0xB07358)
    static let activeEditingAccentStrong = Color(hex: 0x7B4835)
    static let pendingOutline = Color(hex: 0x8F8375)
    static let complete = Color(hex: 0x8B9A7D)
    static let completeText = Color(hex: 0x5F6D54)
    static let inputBorder = Color(hex: 0xD2C4B5)
    static let inputPlaceholder = Color(hex: 0x746759)
    static let reflectionStartedBackground = Color(hex: 0xF5EDE4)
    static let reflectionStartedBorder = Color(hex: 0xD9C7B5)
    static let reflectionStartedText = Color(hex: 0x6A5646)
    static let reflectionStartedGlow = Color(hex: 0xE1CBB4)
    static let fullFifteenBackgroundStart = Color(hex: 0xF2E8D9)
    static let fullFifteenBackgroundEnd = Color(hex: 0xEED9C0)
    static let fullFifteenBorder = Color(hex: 0xD2B28E)
    static let fullFifteenText = Color(hex: 0x6E452A)
    static let fullFifteenMetaText = Color(hex: 0x84583B)
    static let fullFifteenGlow = Color(hex: 0xD7AB7B)
    static let perfectRhythmBackgroundStart = Color(hex: 0xE8EEDC)
    static let perfectRhythmBackgroundEnd = Color(hex: 0xDDE8C9)
    static let perfectRhythmBorder = Color(hex: 0x9AAE78)
    static let perfectRhythmText = Color(hex: 0x4E6040)
    static let perfectRhythmGlow = Color(hex: 0xA2BA83)
    static let error = Color(hex: 0xA3564A)
    static let border = Color(hex: 0xE5DDD4)
    static let settingsBackground = Color.adaptive(lightHex: 0xF8F4EF, darkHex: 0x151311)
    static let settingsPaper = Color.adaptive(lightHex: 0xF5EDE4, darkHex: 0x201C18)
    static let settingsTextPrimary = Color.adaptive(lightHex: 0x2C2C2C, darkHex: 0xF2E8DE)
    static let settingsTextMuted = Color.adaptive(lightHex: 0x5C5346, darkHex: 0xC5B7A8)
    static let reminderPrimaryActionBackground = Color.adaptive(lightHex: 0x8A4A34, darkHex: 0xCD977D)
    static let reminderPrimaryActionForeground = Color.adaptive(lightHex: 0xF8F4EF, darkHex: 0x1F1712)
    static let reminderSecondaryActionTint = Color.adaptive(lightHex: 0x8A4A34, darkHex: 0xD8A58B)
    static let reminderDestructiveActionTint = Color.adaptive(lightHex: 0xA3564A, darkHex: 0xD48C80)
    static let reviewBackground = Color.adaptive(lightHex: 0xF8F4EF, darkHex: 0x151311)
    static let reviewPaper = Color.adaptive(lightHex: 0xF5EDE4, darkHex: 0x201C18)
    static let reviewTextPrimary = Color.adaptive(lightHex: 0x2C2C2C, darkHex: 0xF2E8DE)
    static let reviewTextMuted = Color.adaptive(lightHex: 0x5C5346, darkHex: 0xC5B7A8)
    static let reviewAccent = Color.adaptive(lightHex: 0xC77B5B, darkHex: 0xD89D82)
    static let reviewOnAccent = Color.adaptive(lightHex: 0x1F1A16, darkHex: 0x2D1B12)
    static let reviewCompleteBackground = Color.adaptive(lightHex: 0xE8EEDC, darkHex: 0x2A3324)
    static let reviewCompleteBorder = Color.adaptive(lightHex: 0x9AAE78, darkHex: 0x9EB487)
    static let reviewCompleteText = Color.adaptive(lightHex: 0x4E6040, darkHex: 0xD1DFC0)
    static let reviewStandardBackground = Color.adaptive(lightHex: 0xF2E8D9, darkHex: 0x34271E)
    static let reviewStandardBorder = Color.adaptive(lightHex: 0xD2B28E, darkHex: 0xD6B692)
    static let reviewStandardText = Color.adaptive(lightHex: 0x6E452A, darkHex: 0xE4C4A5)
    static let reviewQuickStartBackground = Color.adaptive(lightHex: 0xF5EDE4, darkHex: 0x2A241F)
    static let reviewQuickStartBorder = Color.adaptive(lightHex: 0xD9C7B5, darkHex: 0x8D7A69)
    static let reviewQuickStartText = Color.adaptive(lightHex: 0x6A5646, darkHex: 0xCDB9A6)
    static let reviewRhythmActive = Color.adaptive(lightHex: 0xAA8E79, darkHex: 0xB69E8E)
    static let reviewRhythmInactive = Color.adaptive(lightHex: 0xE7DED6, darkHex: 0x413731)

    // MARK: - Journal Semantic Colors

    static let journalBackground = Color("JournalBackground")
    /// Slightly cooler tone when inline sentence editing is active (no scrim cutout).
    static let journalAmbientEditingBackground = Color(hex: 0xE5DFD6)
    static let journalPaper = Color("JournalPaper")
    static let journalTextPrimary = Color("JournalTextPrimary")
    static let journalTextMuted = Color("JournalTextMuted")
    static let journalBorder = Color("JournalBorder")
    static let journalInputBorder = Color("JournalInputBorder")
    static let journalInputPlaceholder = Color("JournalInputPlaceholder")
    static let journalComplete = Color("JournalComplete")
    static let journalPendingOutline = Color("JournalPendingOutline")
    static let journalActiveEditingAccent = Color("JournalActiveEditingAccent")
    static let journalActiveEditingAccentStrong = Color("JournalActiveEditingAccentStrong")
    static let journalQuickCheckInBackground = Color("JournalQuickCheckInBackground")
    static let journalQuickCheckInBorder = Color("JournalQuickCheckInBorder")
    static let journalQuickCheckInText = Color("JournalQuickCheckInText")
    static let journalQuickCheckInGlow = Color("JournalQuickCheckInGlow")
    static let journalStandardBackgroundStart = Color("JournalStandardBackgroundStart")
    static let journalStandardBackgroundEnd = Color("JournalStandardBackgroundEnd")
    static let journalStandardBorder = Color("JournalStandardBorder")
    static let journalStandardText = Color("JournalStandardText")
    static let journalStandardGlow = Color("JournalStandardGlow")
    static let journalFullBackgroundStart = Color("JournalFullBackgroundStart")
    static let journalFullBackgroundEnd = Color("JournalFullBackgroundEnd")
    static let journalFullBorder = Color("JournalFullBorder")
    static let journalFullText = Color("JournalFullText")
    static let journalFullGlow = Color("JournalFullGlow")
    static let journalError = Color.adaptive(lightHex: 0xA3564A, darkHex: 0xD48C80)

    /// Alias for accent; kept for backward compatibility.
    static let primaryColor = accent

    // MARK: - Typography

    static let warmPaperHeader = Font.custom("PlayfairDisplay-Regular", size: 22, relativeTo: .title3)
        .weight(.semibold)
    static let warmPaperBody = Font.custom("SourceSerif4Roman-Regular", size: 17, relativeTo: .body)
    static let warmPaperMeta = Font.custom("SourceSerif4Roman-Regular", size: 15, relativeTo: .footnote)
    static let warmPaperMetaEmphasis = Font.custom("SourceSerif4Roman-Regular", size: 15, relativeTo: .footnote)
        .weight(.semibold)
    /// Supporting copy under meta titles (e.g. path criteria); scales with Dynamic Type caption.
    static let warmPaperCaption = Font.custom("SourceSerif4Roman-Regular", size: 13, relativeTo: .caption)

    // MARK: - Interface sans (Outfit)

    /// Default SwiftUI sans; inherited by controls unless a view sets `.font` (journal uses `warmPaper*` instead).
    static let outfitUI = Font.custom("Outfit-Regular", size: 17, relativeTo: .body)

    static let outfitSemiboldHeadline = Font.custom("Outfit-SemiBold", size: 17, relativeTo: .headline)
    static let outfitRegularTitle3 = Font.custom("Outfit-Regular", size: 20, relativeTo: .title3)
    static let outfitSemiboldSubheadline = Font.custom("Outfit-SemiBold", size: 15, relativeTo: .subheadline)

    /// Disclosure chevrons and other compact chrome.
    static let outfitSemiboldCaption = Font.custom("Outfit-SemiBold", size: 12, relativeTo: .caption2)

    // MARK: - Spacing & Radius

    static let spacingTight: CGFloat = 8
    static let spacingRegular: CGFloat = 12
    static let spacingWide: CGFloat = 16
    static let spacingSection: CGFloat = 24
    static let floatingTabBarClearance: CGFloat = 84
    static let todayHorizontalPadding: CGFloat = 16
    static let todayTopPadding: CGFloat = 14
    static let todaySectionSpacing: CGFloat = 22
    static let todayClusterSpacing: CGFloat = 18
    static let todayNotesSpacing: CGFloat = 18
    static let todayBottomPadding: CGFloat = spacingSection + floatingTabBarClearance
    static let cornerRadiusMedium: CGFloat = 14
    static let cornerRadiusLarge: CGFloat = 16

    // MARK: - Motion

    static func celebrationVisibleSeconds(for level: JournalCompletionLevel) -> Double {
        switch level {
        case .empty:
            return 0
        case .started:
            return 0.65
        case .growing:
            return 0.78
        case .balanced:
            return 0.95
        case .full:
            return 1.2
        }
    }

    static func celebrationEntranceAnimation(for level: JournalCompletionLevel) -> Animation {
        switch level {
        case .empty:
            return .easeOut(duration: 0.12)
        case .started:
            return .easeOut(duration: 0.16)
        case .growing:
            return .spring(response: 0.3, dampingFraction: 0.78)
        case .balanced:
            return .spring(response: 0.34, dampingFraction: 0.76)
        case .full:
            return .spring(response: 0.42, dampingFraction: 0.68)
        }
    }

    static func celebrationExitAnimation(for level: JournalCompletionLevel) -> Animation {
        switch level {
        case .empty:
            return .easeOut(duration: 0.12)
        case .started:
            return .easeOut(duration: 0.14)
        case .growing:
            return .easeOut(duration: 0.17)
        case .balanced:
            return .easeOut(duration: 0.2)
        case .full:
            return .easeOut(duration: 0.24)
        }
    }

    static func celebrationPulseAnimation(for level: JournalCompletionLevel) -> Animation {
        switch level {
        case .empty:
            return .easeOut(duration: 0.12)
        case .started:
            return .easeOut(duration: 0.14)
        case .growing:
            return .easeOut(duration: 0.17)
        case .balanced:
            return .easeOut(duration: 0.2)
        case .full:
            return .easeOut(duration: 0.24)
        }
    }

    static func unlockToastEntranceAnimation(for level: JournalCompletionLevel) -> Animation {
        switch level {
        case .empty:
            return .easeOut(duration: 0.12)
        case .started:
            return .easeOut(duration: 0.22)
        case .growing:
            return celebrationEntranceAnimation(for: .growing)
        case .balanced:
            return celebrationEntranceAnimation(for: .balanced)
        case .full:
            return celebrationEntranceAnimation(for: .full)
        }
    }

    static func unlockToastExitAnimation(for level: JournalCompletionLevel) -> Animation {
        switch level {
        case .empty:
            return .easeOut(duration: 0.12)
        case .started:
            return .easeOut(duration: 0.2)
        case .growing:
            return celebrationExitAnimation(for: .growing)
        case .balanced:
            return celebrationExitAnimation(for: .balanced)
        case .full:
            return celebrationExitAnimation(for: .full)
        }
    }
}

// MARK: - Input Styling

/// Applies Warm Paper styling: rounded corners, light border, paper-tinted background.
/// System applies default focus styling when the input is focused.
struct WarmPaperInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.spacingRegular)
            .background(AppTheme.journalPaper.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(AppTheme.journalInputBorder, lineWidth: 1)
            )
    }
}

extension View {
    func warmPaperInputStyle() -> some View {
        modifier(WarmPaperInputStyle())
    }

    /// Soft tier-tinted halo around journal toasts; collapses to a single modest shadow when Reduce Transparency is on.
    func journalToastOuterGlow(accentColor: Color, reduceTransparency: Bool) -> some View {
        modifier(JournalToastOuterGlowModifier(accentGlow: accentColor, reduceTransparency: reduceTransparency))
    }
}

/// Feathered outer glow for floating journal toasts (unlock, saved-to-photos).
private struct JournalToastOuterGlowModifier: ViewModifier {
    let accentGlow: Color
    let reduceTransparency: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
        } else {
            content
                .shadow(color: accentGlow.opacity(0.14), radius: 6, x: 0, y: 2)
                .shadow(color: accentGlow.opacity(0.09), radius: 16, x: 0, y: 3)
                .shadow(color: accentGlow.opacity(0.05), radius: 28, x: 0, y: 0)
        }
    }
}

/// Shared press feedback for tappable controls on warm paper surfaces.
struct WarmPaperPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.86 : 1.0)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }
}

// MARK: - Color Hex Extension

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

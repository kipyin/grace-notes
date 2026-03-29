import SwiftUI

/// Resolved colors and opacities for the Today journal stack. Injected via `\.todayJournalPalette`.
struct TodayJournalPalette: Equatable {
    var background: Color
    var ambientEditingBackground: Color
    var paper: Color
    var textPrimary: Color
    var textMuted: Color
    var border: Color
    var inputBorder: Color
    var inputPlaceholder: Color
    var complete: Color
    var pendingOutline: Color
    var activeEditingAccent: Color
    var activeEditingAccentStrong: Color
    var quickCheckInBackground: Color
    var quickCheckInBorder: Color
    var quickCheckInText: Color
    var quickCheckInGlow: Color
    var standardBackgroundStart: Color
    var standardBackgroundEnd: Color
    var standardBorder: Color
    var standardText: Color
    var standardGlow: Color
    var fullBackgroundStart: Color
    var fullBackgroundEnd: Color
    var fullBorder: Color
    var fullText: Color
    var fullGlow: Color
    var journalError: Color
    /// Opacity for `WarmPaperInputStyle` paper fill.
    var inputPaperOpacity: CGFloat
    /// Extra translucency for section chrome (completion pill, strips) in Summer.
    var sectionPaperOpacity: CGFloat

    static let standard = TodayJournalPalette(
        background: AppTheme.journalBackground,
        ambientEditingBackground: AppTheme.journalAmbientEditingBackground,
        paper: AppTheme.journalPaper,
        textPrimary: AppTheme.journalTextPrimary,
        textMuted: AppTheme.journalTextMuted,
        border: AppTheme.journalBorder,
        inputBorder: AppTheme.journalInputBorder,
        inputPlaceholder: AppTheme.journalInputPlaceholder,
        complete: AppTheme.journalComplete,
        pendingOutline: AppTheme.journalPendingOutline,
        activeEditingAccent: AppTheme.journalActiveEditingAccent,
        activeEditingAccentStrong: AppTheme.journalActiveEditingAccentStrong,
        quickCheckInBackground: AppTheme.journalQuickCheckInBackground,
        quickCheckInBorder: AppTheme.journalQuickCheckInBorder,
        quickCheckInText: AppTheme.journalQuickCheckInText,
        quickCheckInGlow: AppTheme.journalQuickCheckInGlow,
        standardBackgroundStart: AppTheme.journalStandardBackgroundStart,
        standardBackgroundEnd: AppTheme.journalStandardBackgroundEnd,
        standardBorder: AppTheme.journalStandardBorder,
        standardText: AppTheme.journalStandardText,
        standardGlow: AppTheme.journalStandardGlow,
        fullBackgroundStart: AppTheme.journalFullBackgroundStart,
        fullBackgroundEnd: AppTheme.journalFullBackgroundEnd,
        fullBorder: AppTheme.journalFullBorder,
        fullText: AppTheme.journalFullText,
        fullGlow: AppTheme.journalFullGlow,
        journalError: AppTheme.journalError,
        inputPaperOpacity: 0.6,
        sectionPaperOpacity: 1.0
    )

    /// Warmer cream paper and ink-forward typography; tier accent colors stay asset-backed for parity.
    static let summer = TodayJournalPalette(
        background: Color.clear,
        ambientEditingBackground: summerHex(0xE5DDD0),
        paper: summerHex(0xFFF8EE),
        textPrimary: summerHex(0x1A1410),
        textMuted: summerHex(0x5C534A),
        border: summerHex(0xD4C4B0),
        inputBorder: summerHex(0xC4B29A),
        inputPlaceholder: summerHex(0x6B5E50),
        complete: AppTheme.journalComplete,
        pendingOutline: summerHex(0x7A6E62),
        activeEditingAccent: summerHex(0x9A5C45),
        activeEditingAccentStrong: summerHex(0x6B3D2E),
        quickCheckInBackground: AppTheme.journalQuickCheckInBackground,
        quickCheckInBorder: AppTheme.journalQuickCheckInBorder,
        quickCheckInText: AppTheme.journalQuickCheckInText,
        quickCheckInGlow: AppTheme.journalQuickCheckInGlow,
        standardBackgroundStart: AppTheme.journalStandardBackgroundStart,
        standardBackgroundEnd: AppTheme.journalStandardBackgroundEnd,
        standardBorder: AppTheme.journalStandardBorder,
        standardText: AppTheme.journalStandardText,
        standardGlow: AppTheme.journalStandardGlow,
        fullBackgroundStart: AppTheme.journalFullBackgroundStart,
        fullBackgroundEnd: AppTheme.journalFullBackgroundEnd,
        fullBorder: AppTheme.journalFullBorder,
        fullText: AppTheme.journalFullText,
        fullGlow: AppTheme.journalFullGlow,
        journalError: AppTheme.journalError,
        inputPaperOpacity: 0.38,
        sectionPaperOpacity: 0.72
    )

    static func resolve(mode: JournalAppearanceMode) -> TodayJournalPalette {
        switch mode {
        case .standard: return .standard
        case .summer: return .summer
        }
    }
}

private func summerHex(_ hex: UInt) -> Color {
    let red = Double((hex >> 16) & 0xFF) / 255
    let green = Double((hex >> 8) & 0xFF) / 255
    let blue = Double(hex & 0xFF) / 255
    return Color(red: red, green: green, blue: blue)
}

private struct TodayJournalPaletteKey: EnvironmentKey {
    static let defaultValue = TodayJournalPalette.standard
}

extension EnvironmentValues {
    var todayJournalPalette: TodayJournalPalette {
        get { self[TodayJournalPaletteKey.self] }
        set { self[TodayJournalPaletteKey.self] = newValue }
    }
}

private struct JournalSummerAtmosphereHostedKey: EnvironmentKey {
    /// Default: `JournalScreen` draws Summer paper and leaves when the resolved appearance is Summer.
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When `true`, a parent already composes Summer paper/leaves; `JournalScreen` skips duplicating them.
    var journalSummerAtmosphereHosted: Bool {
        get { self[JournalSummerAtmosphereHostedKey.self] }
        set { self[JournalSummerAtmosphereHostedKey.self] = newValue }
    }
}

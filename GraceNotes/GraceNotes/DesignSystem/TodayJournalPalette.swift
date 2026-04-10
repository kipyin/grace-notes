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
    /// Extra translucency for section chrome (completion pill, entry rows) in Bloom mode.
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
    static let bloom = TodayJournalPalette(
        background: Color.clear,
        ambientEditingBackground: bloomPaperHex(0xE5DDD0),
        paper: bloomPaperHex(0xFFF8EE),
        textPrimary: bloomPaperHex(0x1A1410),
        textMuted: bloomPaperHex(0x5C534A),
        border: bloomPaperHex(0xD4C4B0),
        inputBorder: bloomPaperHex(0xC4B29A),
        inputPlaceholder: bloomPaperHex(0x6B5E50),
        complete: AppTheme.journalComplete,
        pendingOutline: bloomPaperHex(0x7A6E62),
        activeEditingAccent: bloomPaperHex(0x9A5C45),
        activeEditingAccentStrong: bloomPaperHex(0x6B3D2E),
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
        case .bloom: return .bloom
        }
    }
}

private func bloomPaperHex(_ hex: UInt) -> Color {
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

private struct JournalBloomAtmosphereHostedKey: EnvironmentKey {
    /// Default: journal draws Bloom paper + leaves inside `JournalScreen` (e.g. embedded routes).
    static let defaultValue = false
}

extension EnvironmentValues {
    /// When `true`, Bloom paper and leaves are provided by `TodayTabRoot`; `JournalScreen` must not duplicate them.
    var journalBloomAtmosphereHosted: Bool {
        get { self[JournalBloomAtmosphereHostedKey.self] }
        set { self[JournalBloomAtmosphereHostedKey.self] = newValue }
    }
}

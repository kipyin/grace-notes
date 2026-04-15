import SwiftUI

/// Resolved colors and fills for one share card snapshot (light or dark theme).
struct ShareCardSurface: Sendable {
    let style: ShareCardStyle
    let usesDarkTheme: Bool

    var useLightCardPalette: Bool { !usesDarkTheme }

    init(style: ShareCardStyle, usesDarkTheme: Bool) {
        self.style = style
        self.usesDarkTheme = usesDarkTheme
    }

    var bodyInk: Color {
        guard usesDarkTheme else { return style.bodyInk }
        return Color(hex: 0xF2E8DE)
    }

    var sectionTitleInk: Color { bodyInk }

    var footerInk: Color {
        guard usesDarkTheme else { return style.footerInk }
        return Color(hex: 0xC5B7A8)
    }

    var stubInk: Color { footerInk }
    var sectionControlInk: Color { footerInk }

    var sectionDividerColor: Color {
        guard usesDarkTheme else { return style.sectionDividerColor }
        return Color(hex: 0x3D3834)
    }

    var redactionBarColor: Color {
        guard usesDarkTheme else { return style.redactionBarColor }
        return Color(hex: 0x4A423A)
    }

    var cardShadowColor: Color {
        guard usesDarkTheme else { return style.cardShadowColor }
        return Color.black.opacity(0.35)
    }

    var completionChipTextColor: Color {
        guard usesDarkTheme else { return style.completionChipTextColor }
        return Color(hex: 0xD4C4B6)
    }

    @ViewBuilder
    func cardBackground() -> some View {
        if useLightCardPalette {
            style.cardBackgroundLayer()
        } else {
            darkCardBackground(style: style)
        }
    }

    @ViewBuilder
    func completionChipBackground() -> some View {
        if useLightCardPalette {
            style.completionChipBackgroundView()
        } else {
            darkCompletionChipBackground(style: style)
        }
    }
}

extension ShareRenderPayload {
    var cardSurface: ShareCardSurface {
        ShareCardSurface(style: style, usesDarkTheme: shareCardUsesDarkTheme)
    }
}

// MARK: - Dark card chrome (was ShareCardStyle+ResolvedAppearance)

@ViewBuilder
private func darkCardBackground(style: ShareCardStyle) -> some View {
    switch style {
    case .paperWarm:
        Color(hex: 0x2A241F)
    case .editorialMist:
        Color(hex: 0x1C1C1C)
    case .sunriseGradient:
        LinearGradient(
            colors: [
                Color(hex: 0x2A1F1A),
                Color(hex: 0x302820),
                Color(hex: 0x261C18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@ViewBuilder
private func darkCompletionChipBackground(style: ShareCardStyle) -> some View {
    switch style {
    case .paperWarm:
        Color(hex: 0x3A322C)
    case .editorialMist:
        Color(hex: 0x333333)
    case .sunriseGradient:
        LinearGradient(
            colors: [Color(hex: 0x3D322C), Color(hex: 0x453D36)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

import SwiftUI

private extension Color {
    init(hex: UInt) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

/// Named presets for the exported share card bitmap (Figma Make: grace-notes / editorial / embellished).
enum ShareCardStyle: String, CaseIterable, Identifiable, Sendable {
    case paperWarm
    case editorialMist
    case sunriseGradient

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .paperWarm:
            String(localized: "sharing.style.paperWarm")
        case .editorialMist:
            String(localized: "sharing.style.editorialMist")
        case .sunriseGradient:
            String(localized: "sharing.style.sunriseGradient")
        }
    }

    // MARK: - Background

    @ViewBuilder
    func cardBackgroundLayer() -> some View {
        switch self {
        case .paperWarm:
            Color(hex: 0xF5EDE4)
        case .editorialMist:
            Color(hex: 0xFAFAF9)
        case .sunriseGradient:
            LinearGradient(
                colors: [
                    Color(hex: 0xF8F4F0),
                    Color(hex: 0xFBF7F3),
                    Color(hex: 0xF5EEE8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Primary ink for body copy (list items and prose).
    var bodyInk: Color {
        switch self {
        case .paperWarm:
            Color(hex: 0x2B2520)
        case .editorialMist:
            Color(hex: 0x1A1A1A)
        case .sunriseGradient:
            Color(hex: 0x1F1B18)
        }
    }

    /// Section titles (below the date row).
    var sectionTitleInk: Color {
        bodyInk
    }

    var footerInk: Color {
        switch self {
        case .paperWarm:
            Color(hex: 0x7A6F68)
        case .editorialMist:
            Color(hex: 0x737373)
        case .sunriseGradient:
            Color(hex: 0x9B8A7E)
        }
    }

    var stubInk: Color {
        footerInk
    }

    /// Muted ink for section include/exclude control (× / +).
    var sectionControlInk: Color {
        footerInk
    }

    var completionChipLabelFont: Font {
        Font.system(size: 11, weight: .medium, design: .default)
    }

    var completionChipTextColor: Color {
        switch self {
        case .paperWarm:
            Color(hex: 0x7A6F68)
        case .editorialMist:
            Color(hex: 0x737373)
        case .sunriseGradient:
            Color(hex: 0x9B8A7E)
        }
    }

    @ViewBuilder
    func completionChipBackgroundView() -> some View {
        switch self {
        case .paperWarm:
            Color(hex: 0xE8DED2)
        case .editorialMist:
            Color(hex: 0xE5E5E5)
        case .sunriseGradient:
            LinearGradient(
                colors: [Color(hex: 0xE8DDD4), Color(hex: 0xEDE3DA)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var sectionDividerColor: Color {
        Color(hex: 0xE5E5E5)
    }

    var redactionBarColor: Color {
        Color(hex: 0xD4CEC7)
    }

    // MARK: - Chrome

    var showsTopAccentRule: Bool {
        true
    }

    var showsAccentRuleUnderDate: Bool {
        false
    }

    var showsSectionDividers: Bool {
        self == .editorialMist
    }

    func topAccentHeight() -> CGFloat {
        3
    }

    func topAccentGradient() -> LinearGradient {
        switch self {
        case .paperWarm:
            LinearGradient(
                colors: [Color(hex: 0xD97757), Color(hex: 0xE88B6F)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .editorialMist:
            LinearGradient(
                colors: [Color(hex: 0xB8968E), Color(hex: 0xC4A59E)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .sunriseGradient:
            LinearGradient(
                colors: [
                    Color(hex: 0xC17B5B),
                    Color(hex: 0xD4916F),
                    Color(hex: 0xC17B5B)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    var cardShadowColor: Color {
        switch self {
        case .paperWarm:
            Color.black.opacity(0.12)
        case .editorialMist:
            Color.black.opacity(0.08)
        case .sunriseGradient:
            Color.black.opacity(0.14)
        }
    }

    var cardShadowRadius: CGFloat {
        switch self {
        case .paperWarm:
            10
        case .editorialMist:
            6
        case .sunriseGradient:
            14
        }
    }

    var cardShadowOffsetY: CGFloat {
        switch self {
        case .paperWarm:
            4
        case .editorialMist:
            2
        case .sunriseGradient:
            6
        }
    }
}

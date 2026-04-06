import SwiftUI

/// Named presets for the exported share card bitmap (maps to `AppTheme` tokens).
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
            AppTheme.paper
        case .editorialMist:
            AppTheme.background
        case .sunriseGradient:
            LinearGradient(
                colors: [AppTheme.fullFifteenBackgroundStart, AppTheme.fullFifteenBackgroundEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Primary ink for body copy (list items and prose).
    var bodyInk: Color {
        switch self {
        case .paperWarm, .editorialMist:
            AppTheme.textPrimary
        case .sunriseGradient:
            AppTheme.fullFifteenText
        }
    }

    /// Section titles (below the date row).
    var sectionTitleInk: Color {
        switch self {
        case .paperWarm:
            AppTheme.textPrimary
        case .editorialMist:
            AppTheme.textMuted
        case .sunriseGradient:
            AppTheme.fullFifteenText
        }
    }

    var dateFont: Font {
        switch self {
        case .paperWarm, .editorialMist:
            AppTheme.warmPaperHeader
        case .sunriseGradient:
            Font.custom("Outfit-SemiBold", size: 20, relativeTo: .title3)
        }
    }

    /// Gratitudes / needs / people / reading / reflections headers.
    var sectionTitleFont: Font {
        switch self {
        case .paperWarm:
            Font.custom("PlayfairDisplay-Regular", size: 17, relativeTo: .headline).weight(.semibold)
        case .editorialMist:
            AppTheme.outfitSemiboldSubheadline
        case .sunriseGradient:
            AppTheme.outfitSemiboldSubheadline
        }
    }

    var footerInk: Color {
        switch self {
        case .paperWarm:
            AppTheme.textPrimary.opacity(0.55)
        case .editorialMist:
            AppTheme.textMuted.opacity(0.72)
        case .sunriseGradient:
            AppTheme.fullFifteenMetaText.opacity(0.88)
        }
    }

    var stubInk: Color {
        switch self {
        case .paperWarm, .editorialMist:
            AppTheme.textMuted
        case .sunriseGradient:
            AppTheme.fullFifteenMetaText.opacity(0.9)
        }
    }

    // MARK: - Chrome

    var showsTopAccentRule: Bool {
        self == .paperWarm
    }

    var showsAccentRuleUnderDate: Bool {
        self == .sunriseGradient
    }

    var showsSectionDividers: Bool {
        self == .editorialMist
    }

    var showsPaperShadow: Bool {
        self == .paperWarm
    }

    func topAccentOpacity() -> Double {
        switch self {
        case .paperWarm: 0.85
        case .sunriseGradient: 0.9
        case .editorialMist: 0.85
        }
    }

    func topAccentHeight() -> CGFloat {
        switch self {
        case .sunriseGradient: 6
        default: 4
        }
    }
}

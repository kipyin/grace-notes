import SwiftUI

/// First-time congratulations variant for unlock toasts (issue #60).
enum JournalUnlockMilestoneHighlight: Equatable {
    case none
    case firstOneOneOne
    case firstBalanced
    case firstFull
}

/// Brief encouragement when journal completion moves up a tier.
struct JournalUnlockToastView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette

    let level: JournalCompletionLevel
    var milestoneHighlight: JournalUnlockMilestoneHighlight = .none

    var body: some View {
        Text(message)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(palette.textPrimary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AppTheme.spacingWide)
            .padding(.vertical, AppTheme.spacingRegular)
            .background(
                reduceTransparency
                    ? palette.paper
                    : palette.paper.opacity(palette.sectionPaperOpacity)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(borderTint, lineWidth: 1)
            )
            .journalToastOuterGlow(accentColor: glowAccentColor, reduceTransparency: reduceTransparency)
    }

    private var message: String {
        switch milestoneHighlight {
        case .firstOneOneOne:
            return String(localized: "journal.guidance.firstTimeOneLineEach")
        case .firstBalanced:
            return String(
                localized: "journal.guidance.firstLeafDay"
            )
        case .firstFull:
            return String(
                localized: "journal.guidance.firstBloomDay"
            )
        case .none:
            break
        }
        switch level {
        case .soil:
            return ""
        case .sprout:
            return String(localized: "journal.guidance.reachedSproutToday")
        case .twig:
            return String(localized: "journal.guidance.towardLeafShort")
        case .leaf:
            return String(localized: "journal.guidance.reachedLeafToday")
        case .bloom:
            return String(localized: "journal.guidance.reachedBloomToday")
        }
    }

    private var borderTint: Color {
        switch level {
        case .soil:
            return palette.border
        case .sprout:
            return palette.quickCheckInBorder
        case .twig:
            return palette.standardBorder
        case .leaf:
            return palette.standardBorder
        case .bloom:
            return palette.fullBorder
        }
    }

    private var shadowTint: Color {
        switch level {
        case .soil:
            return .clear
        case .sprout:
            return palette.quickCheckInGlow
        case .twig:
            return palette.standardGlow
        case .leaf:
            return palette.standardGlow
        case .bloom:
            return palette.fullGlow
        }
    }

    private var glowAccentColor: Color {
        switch level {
        case .soil:
            return palette.border
        default:
            return shadowTint
        }
    }
}

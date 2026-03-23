import SwiftUI

/// First-time congratulations variant for unlock toasts (issue #60).
enum JournalUnlockMilestoneHighlight: Equatable {
    case none
    case firstSeed
    case firstFifteenChipHarvest
    case firstFifteenChipHarvestWithFullRhythm
}

/// Brief encouragement when journal completion moves up a tier.
struct JournalUnlockToastView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconBounceTrigger = 0

    let level: JournalCompletionLevel
    var milestoneHighlight: JournalUnlockMilestoneHighlight = .none

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            toastIcon
            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppTheme.spacingWide)
        .padding(.vertical, AppTheme.spacingRegular)
        .background(AppTheme.journalPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(borderTint, lineWidth: 1)
        )
        .journalToastOuterGlow(accentColor: glowAccentColor, reduceTransparency: reduceTransparency)
    }

    @ViewBuilder
    private var toastIcon: some View {
        if shouldPlayIconBounce {
            Image(systemName: iconName)
                .foregroundStyle(iconTint)
                .symbolEffect(.bounce, value: iconBounceTrigger)
                .onAppear {
                    iconBounceTrigger += 1
                }
        } else {
            Image(systemName: iconName)
                .foregroundStyle(iconTint)
        }
    }

    private var shouldPlayIconBounce: Bool {
        !reduceMotion && (level == .harvest || level == .abundance)
    }

    private var message: String {
        switch milestoneHighlight {
        case .firstSeed:
            return String(
                // swiftlint:disable:next line_length
                localized: "You've planted Seed for the first time—one gratitude, one need, and someone on your mind. Lovely."
            )
        case .firstFifteenChipHarvest:
            return String(
                // swiftlint:disable:next line_length
                localized: "Your first Harvest—you filled all fifteen spots today. Add reading notes and reflections when you're ready for Abundance."
            )
        case .firstFifteenChipHarvestWithFullRhythm:
            return String(
                localized: "Your first Harvest, and you've added reading notes and reflections—a full rhythm for today."
            )
        case .none:
            break
        }
        switch level {
        case .soil:
            return ""
        case .seed:
            return String(localized: "You planted a seed today.")
        case .ripening:
            return String(localized: "You're growing—at least three in each section. Keep going toward Harvest.")
        case .harvest:
            return String(localized: "You reached Harvest.")
        case .abundance:
            return String(localized: "You reached Abundance today.")
        }
    }

    private var iconName: String {
        switch level {
        case .soil:
            return "circle.dotted"
        case .seed:
            return "leaf.fill"
        case .ripening:
            return "leaf.circle.fill"
        case .harvest:
            return "sparkles.rectangle.stack.fill"
        case .abundance:
            return "checkmark.circle.fill"
        }
    }

    private var iconTint: Color {
        switch level {
        case .soil:
            return AppTheme.journalTextMuted
        case .seed:
            return AppTheme.journalQuickCheckInText
        case .ripening:
            return AppTheme.journalStandardText
        case .harvest:
            return AppTheme.journalStandardText
        case .abundance:
            return AppTheme.journalFullText
        }
    }

    private var borderTint: Color {
        switch level {
        case .soil:
            return AppTheme.journalBorder
        case .seed:
            return AppTheme.journalQuickCheckInBorder
        case .ripening:
            return AppTheme.journalStandardBorder
        case .harvest:
            return AppTheme.journalStandardBorder
        case .abundance:
            return AppTheme.journalFullBorder
        }
    }

    private var shadowTint: Color {
        switch level {
        case .soil:
            return .clear
        case .seed:
            return AppTheme.journalQuickCheckInGlow
        case .ripening:
            return AppTheme.journalStandardGlow
        case .harvest:
            return AppTheme.journalStandardGlow
        case .abundance:
            return AppTheme.journalFullGlow
        }
    }

    private var glowAccentColor: Color {
        switch level {
        case .soil:
            return AppTheme.journalBorder
        default:
            return shadowTint
        }
    }
}

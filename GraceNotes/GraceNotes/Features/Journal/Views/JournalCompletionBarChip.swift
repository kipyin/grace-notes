import SwiftUI

/// Compact completion control for the navigation bar: **capsule** fill (tier colors).
///
/// Shadows read poorly in toolbar chrome on **iOS 17–18** (clip / double edge), so the chip stays flat there.
/// On **iOS 26+**, with ``ToolbarItem/sharedBackgroundVisibility(_:)`` set to ``Visibility/hidden``, add a
/// tier-aware shadow stack so the chip reads clearly above the bar.
struct JournalCompletionBarChip: View {
    /// Sticky chip stays one line; cap text scaling at the largest standard Dynamic Type (not accessibility buckets).
    private static let toolbarChipDynamicTypeRange = DynamicTypeSize.xSmall ... DynamicTypeSize.xxxLarge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @Environment(\.todayJournalPalette) private var palette

    /// Fixed bar height from ``JournalScreen/journalToolbarControlHeight`` (matched to the share symbol row).
    let toolbarControlHeight: CGFloat

    let completionLevel: JournalCompletionLevel
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    /// When `false`, show only the tier symbol (toolbar stays compact).
    let showsCompletionTitle: Bool
    let onCollapseExpandTap: () -> Void
    let onShowCompletionInfo: () -> Void

    /// Matches the trailing share symbol row (Outfit 17pt headline scale).
    @ScaledMetric(relativeTo: .headline) private var tierIconLength: CGFloat = 24

    /// After a long-press succeeds, UIKit may still deliver the `Button` action on finger-up; skip one cycle.
    @State private var suppressNextCollapseExpandTap = false

    var body: some View {
        Button {
            if suppressNextCollapseExpandTap {
                suppressNextCollapseExpandTap = false
                return
            }
            onCollapseExpandTap()
        } label: {
            labelCore
                .padding(.horizontal, showsCompletionTitle ? 14 : 10)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showsCompletionTitle)
                .frame(minHeight: toolbarControlHeight, maxHeight: toolbarControlHeight)
                .background {
                    chipCapsuleBackground
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(Self.toolbarChipDynamicTypeRange)
        .fixedSize(horizontal: true, vertical: true)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                suppressNextCollapseExpandTap = true
                onShowCompletionInfo()
            }
        )
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(String(localized: "accessibility.stickyCompletionChipHint"))
        .accessibilityAction(named: String(localized: "accessibility.stickyCompletionChipShowDetailsAction")) {
            onShowCompletionInfo()
        }
    }

    @ViewBuilder
    private var chipCapsuleBackground: some View {
        let capsule = Capsule(style: .continuous)
            .fill(JournalCompletionTierSurface.backgroundFill(for: completionLevel, palette: palette))

        if #available(iOS 26, *) {
            if reduceTransparency {
                capsule
            } else {
                capsule
                    .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
                    .shadow(
                        color: AppTheme.reviewRhythmPillShadow(for: completionLevel),
                        radius: 5,
                        x: 0,
                        y: 3
                    )
            }
        } else {
            capsule
        }
    }

    private var labelCore: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingTight) {
            Image(ReviewRhythmFormatting.assetName(for: completionLevel))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: tierIconLength, height: tierIconLength)
                .accessibilityHidden(true)
            if showsCompletionTitle {
                Text(completionTitle)
                    .font(AppTheme.warmPaperToolbarChipTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(toolbarCompletionTitleMinimumScaleFactor)
            }
        }
        .foregroundStyle(labelColor)
        .frame(maxHeight: .infinity)
    }

    /// Latin titles stay short; CJK growth-stage strings are wider. Shrinking them made the chip read
    /// shorter than the trailing share control—prefer full type size and a wider capsule.
    private var toolbarCompletionTitleMinimumScaleFactor: CGFloat {
        switch locale.language.languageCode?.identifier {
        case "zh", "ja", "ko":
            return 1.0
        default:
            return 0.78
        }
    }

    private var completionTitle: String {
        CompletionBadgeInfo.matching(completionLevel).title
    }

    private var accessibilityLabelText: String {
        let statusName = completionTitle
        let format = String(localized: "journal.share.sectionCountsSentence")
        return String(format: format, locale: Locale.current, statusName, gratitudesCount, needsCount, peopleCount)
    }

    private var labelColor: Color {
        switch completionLevel {
        case .soil:
            return palette.textMuted
        case .sprout:
            return palette.quickCheckInText
        case .twig, .leaf:
            return palette.standardText
        case .bloom:
            return palette.fullText
        }
    }

}

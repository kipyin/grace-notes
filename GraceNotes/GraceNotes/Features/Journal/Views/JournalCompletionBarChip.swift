import SwiftUI
import UIKit

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

    /// Icon-only: slightly shorter than the share row and padded so width tracks height (near-circular capsule).
    private var collapsedChipHeight: CGFloat {
        max(toolbarControlHeight - 1, tierIconLength + 8)
    }

    /// Keep 44+ tap target in nav bar while letting the visual capsule hug icon/title content.
    private var chipTapTargetHeight: CGFloat { toolbarControlHeight }

    /// Visual capsule height used in both collapsed and expanded states.
    private var chipVisualHeight: CGFloat {
        min(collapsedChipHeight, 36)
    }

    /// Keep icon centered inside the collapsed capsule.
    private var collapsedChipWidth: CGFloat { collapsedChipHeight }

    private var chipLeadingInset: CGFloat {
        max(0, (collapsedChipHeight - tierIconLength) / 2)
    }

    /// Fixed expanded width keeps the leading edge anchored in the toolbar host.
    private var expandedChipWidth: CGFloat {
        let contentWidth =
            chipLeadingInset + tierIconLength + AppTheme.spacingTight + completionTitleWidth + chipLeadingInset
        return max(collapsedChipWidth, ceil(contentWidth))
    }

    private var hiddenScale: CGFloat {
        reduceMotion ? 1 : 0.98
    }

    var body: some View {
        Button {
            if suppressNextCollapseExpandTap {
                suppressNextCollapseExpandTap = false
                return
            }
            onCollapseExpandTap()
        } label: {
            ZStack(alignment: .leading) {
                collapsedChipLabel
                    .opacity(showsCompletionTitle ? 0 : 1)
                    .scaleEffect(showsCompletionTitle ? hiddenScale : 1, anchor: .leading)

                expandedChipLabel
                    .opacity(showsCompletionTitle ? 1 : 0)
                    .scaleEffect(showsCompletionTitle ? 1 : hiddenScale, anchor: .leading)
            }
            .frame(width: expandedChipWidth, alignment: .leading)
            .frame(height: chipTapTargetHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(Self.toolbarChipDynamicTypeRange)
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

    private var collapsedChipLabel: some View {
        tierIcon
            .foregroundStyle(labelColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .frame(width: collapsedChipWidth, height: chipVisualHeight, alignment: .center)
            .background { chipCapsuleBackground }
            .contentShape(Capsule(style: .continuous))
    }

    private var expandedChipLabel: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingTight) {
            tierIcon
            Text(completionTitle)
                .font(AppTheme.warmPaperToolbarChipTitle)
                .lineLimit(1)
                .minimumScaleFactor(toolbarCompletionTitleMinimumScaleFactor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHidden(true)
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, chipLeadingInset)
        .frame(width: expandedChipWidth, height: chipVisualHeight, alignment: .leading)
        .background { chipCapsuleBackground }
        .contentShape(Capsule(style: .continuous))
    }

    private var tierIcon: some View {
        Image(ReviewRhythmFormatting.assetName(for: completionLevel))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: tierIconLength, height: tierIconLength)
            .accessibilityHidden(true)
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

    /// Approximate rendered width for the current localized title using the same font family/size.
    private var completionTitleWidth: CGFloat {
        let baseFont = UIFont(name: "SourceSerif4Roman-Regular", size: 16)
            ?? UIFont.preferredFont(forTextStyle: .body)
        let scaledFont = UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        let attributes: [NSAttributedString.Key: Any] = [.font: scaledFont]
        let width = (completionTitle as NSString).size(withAttributes: attributes).width
        return width
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

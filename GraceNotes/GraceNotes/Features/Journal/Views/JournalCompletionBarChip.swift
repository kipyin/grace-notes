import SwiftUI

/// Compact completion control for the navigation bar: **capsule** fill (tier colors).
///
/// Shadows read poorly in toolbar chrome on **iOS 17–18** (clip / double edge), so the chip stays flat there.
/// On **iOS 26+**, with ``ToolbarItem/sharedBackgroundVisibility(_:)`` set to ``Visibility/hidden``, add a
/// tier-aware shadow stack so the chip reads clearly above the bar.
struct JournalCompletionBarChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette

    let completionLevel: JournalCompletionLevel
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var tierIconLength: CGFloat = 15
    @ScaledMetric(relativeTo: .body) private var minToolbarCapsuleHeight: CGFloat = 34

    var body: some View {
        Button(action: onTap) {
            labelCore
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .frame(minHeight: minToolbarCapsuleHeight)
                .frame(maxHeight: .infinity)
                .background {
                    chipCapsuleBackground
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(String(localized: "accessibility.journalStatusMeaningHint"))
    }

    @ViewBuilder
    private var chipCapsuleBackground: some View {
        let capsule = Capsule(style: .continuous)
            .fill(backgroundFill(for: completionLevel))

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
        HStack(spacing: AppTheme.spacingTight) {
            Image(ReviewRhythmFormatting.assetName(for: completionLevel))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: tierIconLength, height: tierIconLength)
                .accessibilityHidden(true)
            Text(completionTitle)
                .font(AppTheme.warmPaperMetaEmphasis)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
        }
        .foregroundStyle(labelColor)
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

    private func backgroundFill(for level: JournalCompletionLevel) -> AnyShapeStyle {
        switch level {
        case .soil:
            return AnyShapeStyle(palette.background)
        case .sprout:
            return AnyShapeStyle(palette.quickCheckInBackground)
        case .twig, .leaf:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [palette.standardBackgroundStart, palette.standardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .bloom:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [palette.fullBackgroundStart, palette.fullBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }
}

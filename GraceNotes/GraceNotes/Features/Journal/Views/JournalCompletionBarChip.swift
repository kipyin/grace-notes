import SwiftUI

/// Compact completion indicator for the navigation bar. Avoids the full ``JournalCompletionPill`` chrome
/// to reduce Liquid Glass / double-material issues when embedded in toolbar items.
struct JournalCompletionBarChip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.todayJournalPalette) private var palette

    let completionLevel: JournalCompletionLevel
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    let stickyMorphNamespace: Namespace.ID
    let isStickyMorphSource: Bool
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .body) private var tierIconLength: CGFloat = 15

    var body: some View {
        Button(action: onTap) {
            labelCore
                .matchedGeometryEffect(
                    id: "journalStickyCompletionLabel",
                    in: stickyMorphNamespace,
                    properties: .frame,
                    anchor: .topLeading,
                    isSource: isStickyMorphSource
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(String(localized: "accessibility.journalStatusMeaningHint"))
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
}

import SwiftUI

/// Background and stroke only; panel titles share one typographic style (matches Past review inset panels).
enum ReviewInsightPanelChrome {
    case lead
    case standard
}

struct ReviewInsightInsetPanel<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let panelChrome: ReviewInsightPanelChrome
    let titleTrailingText: String?
    let onTitleTap: (() -> Void)?
    /// When the title is a button, optional VoiceOver hint (e.g. rhythm chrome). Omit when reused without a drilldown.
    let titleAccessibilityHint: String?
    let content: Content

    init(
        title: String,
        panelChrome: ReviewInsightPanelChrome = .standard,
        titleTrailingText: String? = nil,
        onTitleTap: (() -> Void)? = nil,
        titleAccessibilityHint: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.panelChrome = panelChrome
        self.titleTrailingText = titleTrailingText
        self.onTitleTap = onTitleTap
        self.titleAccessibilityHint = titleAccessibilityHint
        self.content = content()
    }

    private var strokeOpacity: CGFloat {
        switch panelChrome {
        case .lead:
            return 0.55
        case .standard:
            return 0.4
        }
    }

    @ViewBuilder
    private var titlePrimary: some View {
        if let onTitleTap {
            Button(action: onTitleTap) {
                Text(title)
                    .font(AppTheme.warmPaperBody.weight(.semibold))
                    .foregroundStyle(AppTheme.reviewTextPrimary)
            }
            .buttonStyle(PastTappablePressStyle())
            .accessibilityAddTraits(.isHeader)
            .optionalAccessibilityHint(titleAccessibilityHint)
        } else {
            Text(title)
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// Title in the side-by-side row: wrap and shrink so long copy does not crowd out trailing meta text.
    private var titlePrimaryForHorizontalPair: some View {
        titlePrimary
            .lineLimit(2)
            .minimumScaleFactor(0.85)
            .multilineTextAlignment(.leading)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var titleRow: some View {
        if let trailing = titleTrailingText, !trailing.isEmpty {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    titlePrimary
                    Text(trailing)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        titlePrimaryForHorizontalPair
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.85)
                            .lineLimit(2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        titlePrimary
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } else {
            titlePrimary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleRow
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `reviewPaper` on `reviewBackground` (list row); avoid low-opacity `reviewBackground` here — it vanishes.
        .background {
            RoundedRectangle(cornerRadius: 12, style: .circular)
                .fill(AppTheme.reviewPaper)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .circular)
                .strokeBorder(AppTheme.border.opacity(strokeOpacity), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .circular))
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityHint(_ hint: String?) -> some View {
        if let hint {
            let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                accessibilityHint(trimmed)
            } else {
                self
            }
        } else {
            self
        }
    }
}

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
    let content: Content

    init(
        title: String,
        panelChrome: ReviewInsightPanelChrome = .standard,
        titleTrailingText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.panelChrome = panelChrome
        self.titleTrailingText = titleTrailingText
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

    private var titleText: some View {
        Text(title)
            .font(AppTheme.warmPaperBody.weight(.semibold))
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var titleRow: some View {
        if let trailing = titleTrailingText, !trailing.isEmpty {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    titleText
                    Text(trailing)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        titleText
                        Spacer(minLength: 8)
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.85)
                            .lineLimit(2)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        titleText
                        Text(trailing)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.reviewTextMuted)
                    }
                }
            }
        } else {
            titleText
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

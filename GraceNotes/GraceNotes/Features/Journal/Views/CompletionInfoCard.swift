import SwiftUI

struct CompletionInfoCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var contentVisible = false

    let badgeInfo: CompletionBadgeInfo
    let cardTintColor: Color
    let reduceTransparency: Bool
    let morphNamespace: Namespace.ID
    let showMorph: Bool
    let bloomProgress: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(badgeInfo.description)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.journalTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(contentVisible || reduceMotion ? 1 : 0)
        .offset(y: contentVisible || reduceMotion ? 0 : 8)
        .padding(AppTheme.spacingRegular)
        .background(cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(cardTintColor.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: cardTintColor.opacity(reduceTransparency ? 0.18 : 0.24), radius: 8, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(badgeInfo.description))
        .onAppear {
            animateEntry()
        }
    }

    private var cardSurface: AnyView {
        let base = RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            .fill(AppTheme.journalPaper.opacity(reduceTransparency ? 1.0 : 0.94))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(cardTintColor.opacity(0.24 * bloomProgress), lineWidth: 1.4)
                    .scaleEffect(1.0 + (0.02 * (1 - bloomProgress)))
            )

        guard showMorph, !reduceMotion else {
            return AnyView(base)
        }

        return AnyView(
            base.matchedGeometryEffect(
                id: "completionInfoMorphSurface",
                in: morphNamespace,
                properties: .frame,
                anchor: .topLeading,
                isSource: false
            )
        )
    }

    private func animateEntry() {
        guard !reduceMotion else {
            contentVisible = true
            return
        }

        contentVisible = false

        withAnimation(.easeOut(duration: 0.24)) {
            contentVisible = true
        }
    }
}

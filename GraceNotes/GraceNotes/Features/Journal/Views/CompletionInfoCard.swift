import SwiftUI

struct CompletionInfoCard: View {
    let badgeInfo: CompletionBadgeInfo
    let cardTintColor: Color
    let reduceTransparency: Bool
    let morphNamespace: Namespace.ID
    let showMorph: Bool
    let bloomProgress: CGFloat

    var body: some View {
        CompletionInfoCardContent(
            badgeInfo: badgeInfo,
            cardTintColor: cardTintColor,
            reduceTransparency: reduceTransparency,
            morphNamespace: morphNamespace,
            showMorph: showMorph,
            bloomProgress: bloomProgress
        )
        .id(badgeInfo)
    }
}

private struct CompletionInfoCardContent: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.todayJournalPalette) private var palette
    @State private var contentVisible = false
    @State private var didPlayEntryAnimation = false

    let badgeInfo: CompletionBadgeInfo
    let cardTintColor: Color
    let reduceTransparency: Bool
    let morphNamespace: Namespace.ID
    let showMorph: Bool
    let bloomProgress: CGFloat

    private var isEntryRevealed: Bool {
        contentVisible || reduceMotion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(badgeInfo.description)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isEntryRevealed ? 1 : 0)
        .offset(y: isEntryRevealed ? 0 : 8)
        .padding(AppTheme.spacingRegular)
        .background(cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(cardTintColor.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: cardTintColor.opacity(reduceTransparency ? 0.18 : 0.24), radius: 8, x: 0, y: 4)
        .allowsHitTesting(isEntryRevealed)
        .accessibilityHidden(!isEntryRevealed)
        .accessibilityElement(children: .contain)
        .onAppear {
            animateEntry()
        }
    }

    private var cardSurface: some View {
        Group {
            if showMorph && !reduceMotion {
                roundedRectangleSurface
                    .matchedGeometryEffect(
                        id: "completionInfoMorphSurface",
                        in: morphNamespace,
                        properties: .frame,
                        anchor: .topLeading,
                        isSource: false
                    )
            } else {
                roundedRectangleSurface
            }
        }
    }

    private var roundedRectangleSurface: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            .fill(
                palette.paper.opacity(reduceTransparency ? 1.0 : 0.94 * palette.sectionPaperOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(cardTintColor.opacity(0.24 * bloomProgress), lineWidth: 1.4)
                    .scaleEffect(1.0 + (0.02 * (1 - bloomProgress)))
            )
    }

    private func animateEntry() {
        guard !reduceMotion else {
            contentVisible = true
            return
        }

        if didPlayEntryAnimation {
            contentVisible = true
            return
        }
        didPlayEntryAnimation = true

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            contentVisible = false
        }

        withAnimation(.easeOut(duration: 0.24)) {
            contentVisible = true
        }
    }
}

import SwiftUI

/// Displays the journal entry completion status.
struct DateSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette

    let completionInfo: JournalCompletionInfoPresentation
    let completionInfoMorphNamespace: Namespace.ID
    let stickyMorphNamespace: Namespace.ID
    let showStickyCompletionBar: Bool

    let completionLevel: JournalCompletionLevel
    let celebratingLevel: JournalCompletionLevel?
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            if completionInfo.isInfoCardPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        completionInfo.dismissInfoCard(reduceMotion: reduceMotion)
                    }
                    .accessibilityHidden(true)
                    .zIndex(0)
            }
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                completionStatusLabel
                    .zIndex(2)
                if let selectedBadgeInfo = completionInfo.selectedBadgeInfo, completionInfo.isInfoCardPresented {
                    CompletionInfoCard(
                        badgeInfo: selectedBadgeInfo,
                        cardTintColor: selectedBadgeInfo.infoCardTintColor(using: palette),
                        reduceTransparency: reduceTransparency,
                        morphNamespace: completionInfoMorphNamespace,
                        showMorph: false,
                        bloomProgress: completionInfo.infoCardBloomProgress
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        completionInfo.dismissInfoCard(reduceMotion: reduceMotion)
                    }
                    .transition(infoCardTransition)
                    .zIndex(1)
                    .accessibilitySortPriority(2)
                }
            }
            .zIndex(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            completionInfo.cancelTasksOnDisappear()
        }
    }

    private var completionStatusLabel: some View {
        Group {
            switch completionLevel {
            case .soil:
                statusButton(.empty)
            case .sprout:
                statusButton(.started)
            case .twig:
                statusButton(.growing)
            case .leaf:
                statusButton(.balanced)
            case .bloom:
                statusButton(.full)
            }
        }
    }

    private func statusButton(_ badgeInfo: CompletionBadgeInfo) -> some View {
        Button {
            completionInfo.completionBadgeTapped(badgeInfo, reduceMotion: reduceMotion)
        } label: {
            JournalCompletionPill(
                completionLevel: badgeInfo.completionLevel,
                celebratingLevel: celebratingLevel,
                morphSource: false,
                morphNamespace: completionInfoMorphNamespace,
                morphAccentColor: (completionInfo.selectedBadgeInfo ?? badgeInfo).infoCardTintColor(using: palette),
                morphBloomProgress: completionInfo.infoCardBloomProgress,
                stickyMorphNamespace: stickyMorphNamespace,
                isStickyMorphSourceForToolbar: !showStickyCompletionBar
            )
        }
        .buttonStyle(WarmPaperPressStyle())
        .accessibilityHint(String(localized: "accessibility.journalStatusMeaningHint"))
        .accessibilityLabel(statusAccessibilityLabel(for: badgeInfo.completionLevel))
    }

    private func statusAccessibilityLabel(for level: JournalCompletionLevel) -> String {
        let statusName = CompletionBadgeInfo.matching(level).title
        let format = String(localized: "journal.share.sectionCountsSentence")
        return String(format: format, locale: Locale.current, statusName, gratitudesCount, needsCount, peopleCount)
    }

    private var infoCardTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .top)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 0.98, anchor: .topLeading)),
            removal: .opacity
        )
    }
}

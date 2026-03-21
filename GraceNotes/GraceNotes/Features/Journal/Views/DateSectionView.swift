import SwiftUI
import UIKit

/// Displays the journal entry completion status.
struct DateSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Namespace private var completionInfoMorphNamespace
    @State private var selectedBadgeInfo: CompletionBadgeInfo?
    @State private var isInfoCardPresented = false
    @State private var infoCardDismissTask: Task<Void, Never>?
    @State private var infoCardBloomTask: Task<Void, Never>?
    @State private var infoCardBloomProgress: CGFloat = 0

    let completionLevel: JournalCompletionLevel
    let celebratingLevel: JournalCompletionLevel?

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isInfoCardPresented {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissInfoCard()
                    }
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                completionStatusLabel
                if let selectedBadgeInfo, isInfoCardPresented {
                    CompletionInfoCard(
                        badgeInfo: selectedBadgeInfo,
                        cardTintColor: infoCardTintColor(for: selectedBadgeInfo),
                        reduceTransparency: reduceTransparency,
                        morphNamespace: completionInfoMorphNamespace,
                        showMorph: !reduceMotion,
                        bloomProgress: infoCardBloomProgress
                    )
                    .transition(infoCardTransition)
                    .accessibilitySortPriority(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onDisappear {
            infoCardDismissTask?.cancel()
            infoCardDismissTask = nil
            infoCardBloomTask?.cancel()
            infoCardBloomTask = nil
        }
    }

    private var completionStatusLabel: some View {
        Group {
            switch completionLevel {
            case .quickCheckIn:
                Button {
                    completionBadgeTapped(.seed)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .quickCheckIn,
                        celebratingLevel: celebratingLevel,
                        morphSource: selectedBadgeInfo == .seed && isInfoCardPresented,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .seed),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Seed means for today."))
            case .standardReflection:
                Button {
                    completionBadgeTapped(.harvest)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .standardReflection,
                        celebratingLevel: celebratingLevel,
                        morphSource: selectedBadgeInfo == .harvest && isInfoCardPresented,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .harvest),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Harvest means for today."))
            case .fullFiveCubed:
                Button {
                    completionBadgeTapped(.harvest)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .fullFiveCubed,
                        celebratingLevel: celebratingLevel,
                        morphSource: selectedBadgeInfo == .harvest && isInfoCardPresented,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .harvest),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Harvest means for today."))
            case .none:
                Button {
                    completionBadgeTapped(.inProgress)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .none,
                        celebratingLevel: celebratingLevel,
                        morphSource: selectedBadgeInfo == .inProgress && isInfoCardPresented,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .inProgress),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what In Progress means for today."))
            }
        }
    }

}

private extension DateSectionView {
    var infoCardTransition: AnyTransition {
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

    var infoCardEntranceAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.22)
    }

    var infoCardExitAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }

    func completionBadgeTapped(_ badgeInfo: CompletionBadgeInfo) {
        triggerInfoRevealHaptic()
        infoCardDismissTask?.cancel()

        let isSameSelection = selectedBadgeInfo == badgeInfo
        if isSameSelection, isInfoCardPresented {
            dismissInfoCard()
            return
        }

        selectedBadgeInfo = badgeInfo

        if isInfoCardPresented {
            withAnimation(infoCardExitAnimation) {
                isInfoCardPresented = false
            }

            infoCardDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 130))
                guard !Task.isCancelled else { return }
                withAnimation(infoCardEntranceAnimation) {
                    isInfoCardPresented = true
                }
                triggerInfoCardBloomPulse()
            }
            return
        }

        withAnimation(infoCardEntranceAnimation) {
            isInfoCardPresented = true
        }
        triggerInfoCardBloomPulse()
    }

    func dismissInfoCard() {
        infoCardDismissTask?.cancel()
        withAnimation(infoCardExitAnimation) {
            isInfoCardPresented = false
        }

        if reduceMotion {
            selectedBadgeInfo = nil
            return
        }

        infoCardDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            selectedBadgeInfo = nil
        }
    }

    func triggerInfoRevealHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: reduceMotion ? 0.35 : 0.58)
    }

    func infoCardTintColor(for badgeInfo: CompletionBadgeInfo) -> Color {
        switch badgeInfo {
        case .inProgress:
            return AppTheme.journalTextMuted
        case .seed:
            return AppTheme.journalQuickCheckInText
        case .harvest:
            return completionLevel == .fullFiveCubed ? AppTheme.journalFullText : AppTheme.journalStandardText
        }
    }

    func triggerInfoCardBloomPulse() {
        guard !reduceMotion else {
            infoCardBloomProgress = 1
            return
        }

        infoCardBloomTask?.cancel()
        infoCardBloomProgress = 0

        withAnimation(.easeOut(duration: 0.2)) {
            infoCardBloomProgress = 1
        }

        infoCardBloomTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                infoCardBloomProgress = 0
            }
        }
    }
}

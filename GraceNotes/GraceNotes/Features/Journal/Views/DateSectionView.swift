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
    @State private var infoCardDismissSequence: UInt64 = 0
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
                    .zIndex(0)
            }
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                completionStatusLabel
                    .zIndex(2)
                if let selectedBadgeInfo, isInfoCardPresented {
                    CompletionInfoCard(
                        badgeInfo: selectedBadgeInfo,
                        cardTintColor: infoCardTintColor(for: selectedBadgeInfo),
                        reduceTransparency: reduceTransparency,
                        morphNamespace: completionInfoMorphNamespace,
                        showMorph: false,
                        bloomProgress: infoCardBloomProgress
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissInfoCard()
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
            infoCardDismissTask?.cancel()
            infoCardDismissSequence += 1
            infoCardDismissTask = nil
            infoCardBloomTask?.cancel()
            infoCardBloomTask = nil
        }
    }

    private var completionStatusLabel: some View {
        Group {
            switch completionLevel {
            case .soil:
                Button {
                    completionBadgeTapped(.soil)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .soil,
                        celebratingLevel: celebratingLevel,
                        morphSource: false,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .soil),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Soil means for today."))
            case .seed:
                Button {
                    completionBadgeTapped(.seed)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .seed,
                        celebratingLevel: celebratingLevel,
                        morphSource: false,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .seed),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Seed means for today."))
            case .ripening:
                Button {
                    completionBadgeTapped(.ripening)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .ripening,
                        celebratingLevel: celebratingLevel,
                        morphSource: false,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .ripening),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Ripening means for today."))
            case .harvest:
                Button {
                    completionBadgeTapped(.harvest)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .harvest,
                        celebratingLevel: celebratingLevel,
                        morphSource: false,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .harvest),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Harvest means for today."))
            case .abundance:
                Button {
                    completionBadgeTapped(.abundance)
                } label: {
                    JournalCompletionPill(
                        completionLevel: .abundance,
                        celebratingLevel: celebratingLevel,
                        morphSource: false,
                        morphNamespace: completionInfoMorphNamespace,
                        morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? .abundance),
                        morphBloomProgress: infoCardBloomProgress
                    )
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Abundance means for today."))
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
        infoCardDismissSequence += 1
        infoCardDismissTask = nil

        let isSameSelection = selectedBadgeInfo == badgeInfo
        if isSameSelection, isInfoCardPresented {
            dismissInfoCard()
            return
        }

        selectedBadgeInfo = badgeInfo

        if isInfoCardPresented {
            scheduleInfoCardCloseThenReopenAfterDelay()
            return
        }

        withAnimation(infoCardEntranceAnimation) {
            isInfoCardPresented = true
        }
        triggerInfoCardBloomPulse()
    }

    func scheduleInfoCardCloseThenReopenAfterDelay() {
        withAnimation(infoCardExitAnimation) {
            isInfoCardPresented = false
        }

        infoCardDismissSequence += 1
        let reopenSequence = infoCardDismissSequence
        infoCardDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 130))
            guard !Task.isCancelled, reopenSequence == infoCardDismissSequence else { return }
            withAnimation(infoCardEntranceAnimation) {
                isInfoCardPresented = true
            }
            triggerInfoCardBloomPulse()
            if reopenSequence == infoCardDismissSequence {
                infoCardDismissTask = nil
            }
        }
    }

    func dismissInfoCard() {
        infoCardDismissTask?.cancel()
        infoCardDismissSequence += 1
        infoCardDismissTask = nil
        withAnimation(infoCardExitAnimation) {
            isInfoCardPresented = false
        }

        if reduceMotion {
            selectedBadgeInfo = nil
            return
        }

        infoCardDismissSequence += 1
        let clearSelectionSequence = infoCardDismissSequence
        infoCardDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled, clearSelectionSequence == infoCardDismissSequence else { return }
            selectedBadgeInfo = nil
            if clearSelectionSequence == infoCardDismissSequence {
                infoCardDismissTask = nil
            }
        }
    }

    func triggerInfoRevealHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: reduceMotion ? 0.35 : 0.58)
    }

    func infoCardTintColor(for badgeInfo: CompletionBadgeInfo) -> Color {
        switch badgeInfo {
        case .soil:
            return AppTheme.journalTextMuted
        case .seed:
            return AppTheme.journalQuickCheckInText
        case .ripening:
            return AppTheme.journalStandardText
        case .harvest:
            return AppTheme.journalStandardText
        case .abundance:
            return AppTheme.journalFullText
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

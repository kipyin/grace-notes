import SwiftUI
import UIKit

/// Displays the journal entry completion status.
struct DateSectionView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette
    @Namespace private var completionInfoMorphNamespace
    @State private var selectedBadgeInfo: CompletionBadgeInfo?
    @State private var isInfoCardPresented = false
    @State private var infoCardDismissTask: Task<Void, Never>?
    @State private var infoCardDismissSequence: UInt64 = 0
    @State private var infoCardBloomTask: Task<Void, Never>?
    @State private var infoCardBloomProgress: CGFloat = 0

    let completionLevel: JournalCompletionLevel
    let celebratingLevel: JournalCompletionLevel?
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int

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
            completionBadgeTapped(badgeInfo)
        } label: {
            JournalCompletionPill(
                completionLevel: badgeInfo.completionLevel,
                celebratingLevel: celebratingLevel,
                morphSource: false,
                morphNamespace: completionInfoMorphNamespace,
                morphAccentColor: infoCardTintColor(for: selectedBadgeInfo ?? badgeInfo),
                morphBloomProgress: infoCardBloomProgress
            )
        }
        .buttonStyle(WarmPaperPressStyle())
        .accessibilityHint(String(localized: "Shows what this status means for today."))
        .accessibilityLabel(statusAccessibilityLabel(for: badgeInfo.completionLevel))
    }

    private func statusAccessibilityLabel(for level: JournalCompletionLevel) -> String {
        let statusName = CompletionBadgeInfo.matching(level).title
        let format = String(localized: "%1$@. Gratitudes %2$d, Needs %3$d, People in Mind %4$d.")
        return String(format: format, locale: Locale.current, statusName, gratitudesCount, needsCount, peopleCount)
    }
}

private extension CompletionBadgeInfo {
    var completionLevel: JournalCompletionLevel {
        switch self {
        case .empty:
            return .soil
        case .started:
            return .sprout
        case .growing:
            return .twig
        case .balanced:
            return .leaf
        case .full:
            return .bloom
        }
    }

    static func matching(_ level: JournalCompletionLevel) -> CompletionBadgeInfo {
        switch level {
        case .soil:
            return .empty
        case .sprout:
            return .started
        case .twig:
            return .growing
        case .leaf:
            return .balanced
        case .bloom:
            return .full
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
        case .empty:
            return palette.textMuted
        case .started:
            return palette.quickCheckInText
        case .growing, .balanced:
            return palette.standardText
        case .full:
            return palette.fullText
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

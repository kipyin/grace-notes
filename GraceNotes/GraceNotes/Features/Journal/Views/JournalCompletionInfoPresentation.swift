import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class JournalCompletionInfoPresentation {
    var selectedBadgeInfo: CompletionBadgeInfo?
    var isInfoCardPresented = false
    var infoCardBloomProgress: CGFloat = 0

    private var infoCardDismissTask: Task<Void, Never>?
    private var infoCardDismissSequence: UInt64 = 0
    private var infoCardBloomTask: Task<Void, Never>?

    func completionBadgeTapped(_ badgeInfo: CompletionBadgeInfo, reduceMotion: Bool) {
        triggerInfoRevealHaptic(reduceMotion: reduceMotion)
        infoCardDismissTask?.cancel()
        infoCardDismissSequence += 1
        infoCardDismissTask = nil

        let isSameSelection = selectedBadgeInfo == badgeInfo
        if isSameSelection, isInfoCardPresented {
            dismissInfoCard(reduceMotion: reduceMotion)
            return
        }

        selectedBadgeInfo = badgeInfo

        if isInfoCardPresented {
            scheduleInfoCardCloseThenReopenAfterDelay(reduceMotion: reduceMotion)
            return
        }

        withAnimation(infoCardEntranceAnimation(reduceMotion: reduceMotion)) {
            isInfoCardPresented = true
        }
        triggerInfoCardBloomPulse(reduceMotion: reduceMotion)
    }

    func dismissInfoCard(reduceMotion: Bool) {
        cancelInfoCardBloomAnimation(resetProgress: true)
        infoCardDismissTask?.cancel()
        infoCardDismissSequence += 1
        infoCardDismissTask = nil
        withAnimation(infoCardExitAnimation(reduceMotion: reduceMotion)) {
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

    func cancelTasksOnDisappear() {
        infoCardDismissTask?.cancel()
        infoCardDismissSequence += 1
        infoCardDismissTask = nil
        cancelInfoCardBloomAnimation(resetProgress: true)
    }

    private func scheduleInfoCardCloseThenReopenAfterDelay(reduceMotion: Bool) {
        cancelInfoCardBloomAnimation(resetProgress: true)
        withAnimation(infoCardExitAnimation(reduceMotion: reduceMotion)) {
            isInfoCardPresented = false
        }

        infoCardDismissSequence += 1
        let reopenSequence = infoCardDismissSequence
        infoCardDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 130))
            guard !Task.isCancelled, reopenSequence == infoCardDismissSequence else { return }
            withAnimation(infoCardEntranceAnimation(reduceMotion: reduceMotion)) {
                isInfoCardPresented = true
            }
            triggerInfoCardBloomPulse(reduceMotion: reduceMotion)
            if reopenSequence == infoCardDismissSequence {
                infoCardDismissTask = nil
            }
        }
    }

    private func triggerInfoRevealHaptic(reduceMotion: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: reduceMotion ? 0.35 : 0.58)
    }

    private func triggerInfoCardBloomPulse(reduceMotion: Bool) {
        guard !reduceMotion else {
            cancelInfoCardBloomAnimation(resetProgress: false)
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

    private func cancelInfoCardBloomAnimation(resetProgress: Bool) {
        infoCardBloomTask?.cancel()
        infoCardBloomTask = nil
        if resetProgress {
            infoCardBloomProgress = 0
        }
    }

    private func infoCardEntranceAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.22)
    }

    private func infoCardExitAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.16)
    }
}

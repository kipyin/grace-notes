import SwiftUI
import UIKit

private extension JournalScreen {
    func unlockToastTransition(for level: JournalCompletionLevel) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch level {
        case .soil:
            return .opacity
        case .seed:
            return .move(edge: .bottom).combined(with: .opacity)
        case .ripening:
            return .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.97, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            )
        case .harvest:
            return .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            )
        case .abundance:
            return .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.93, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            )
        }
    }

    func triggerStatusCelebration(for level: JournalCompletionLevel) {
        statusCelebrationDismissTask?.cancel()
        triggerStatusHaptics(for: level)

        let entranceAnimation = reduceMotion ? nil : AppTheme.celebrationEntranceAnimation(for: level)
        withAnimation(entranceAnimation) {
            celebratingLevel = level
        }

        statusCelebrationDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(AppTheme.celebrationVisibleSeconds(for: level)))
            let exitAnimation = reduceMotion ? nil : AppTheme.celebrationExitAnimation(for: level)
            withAnimation(exitAnimation) {
                celebratingLevel = nil
            }
        }
    }

    func triggerStatusHaptics(for level: JournalCompletionLevel) {
        switch level {
        case .soil:
            break
        case .seed:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.45 : 0.65)
        case .ripening:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.5 : 0.72)
        case .harvest:
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)

            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                medium.impactOccurred(intensity: self.reduceMotion ? 0.6 : 0.85)
            }
        case .abundance:
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)

            let emphasis = UIImpactFeedbackGenerator(style: .rigid)
            emphasis.prepare()
            let firstDelay = reduceMotion ? 0.0 : 0.08
            let secondDelay = reduceMotion ? 0.1 : 0.18
            DispatchQueue.main.asyncAfter(deadline: .now() + firstDelay) {
                emphasis.impactOccurred(intensity: self.reduceMotion ? 0.75 : 1.0)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + secondDelay) {
                emphasis.impactOccurred(intensity: self.reduceMotion ? 0.55 : 0.8)
            }
        }
    }
}

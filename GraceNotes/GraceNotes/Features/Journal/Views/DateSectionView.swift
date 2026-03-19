import SwiftUI
import UIKit

/// Displays the journal entry completion status.
struct DateSectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
                        bloomProgress: infoCardBloomProgress,
                        onDismiss: dismissInfoCard
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
                    levelSurface(
                        level: .quickCheckIn,
                        isCelebrating: celebratingLevel == .quickCheckIn,
                        morphSource: selectedBadgeInfo == .seed && isInfoCardPresented
                    ) {
                        Label(String(localized: "Seed"), systemImage: "leaf.fill")
                            .font(AppTheme.warmPaperMetaEmphasis)
                            .foregroundStyle(AppTheme.journalQuickCheckInText)
                    }
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Seed means for today."))
            case .standardReflection:
                Button {
                    completionBadgeTapped(.harvest)
                } label: {
                    levelSurface(
                        level: .standardReflection,
                        isCelebrating: celebratingLevel == .standardReflection,
                        morphSource: selectedBadgeInfo == .harvest && isInfoCardPresented
                    ) {
                        Label(
                            String(localized: "Harvest"),
                            systemImage: celebratingLevel == .standardReflection
                                ? "sparkles.rectangle.stack.fill"
                                : "sparkles.rectangle.stack"
                        )
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.journalStandardText)
                    }
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Harvest means for today."))
            case .fullFiveCubed:
                Button {
                    completionBadgeTapped(.harvest)
                } label: {
                    levelSurface(
                        level: .fullFiveCubed,
                        isCelebrating: celebratingLevel == .fullFiveCubed,
                        morphSource: selectedBadgeInfo == .harvest && isInfoCardPresented
                    ) {
                        Label(
                            String(localized: "Harvest"),
                            systemImage: celebratingLevel == .fullFiveCubed
                                ? "checkmark.circle.fill"
                                : "checkmark.circle"
                        )
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.journalFullText)
                    }
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what Harvest means for today."))
            case .none:
                Button {
                    completionBadgeTapped(.inProgress)
                } label: {
                    levelSurface(
                        level: .none,
                        isCelebrating: false,
                        morphSource: selectedBadgeInfo == .inProgress && isInfoCardPresented
                    ) {
                        Label(String(localized: "In Progress"), systemImage: "pencil.circle")
                            .font(AppTheme.warmPaperMetaEmphasis)
                            .foregroundStyle(AppTheme.journalTextMuted)
                    }
                }
                .buttonStyle(WarmPaperPressStyle())
                .accessibilityHint(String(localized: "Shows what In Progress means for today."))
            }
        }
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
    }

    private func levelSurface<Content: View>(
        level: JournalCompletionLevel,
        isCelebrating: Bool,
        morphSource: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, AppTheme.spacingRegular)
            .padding(.vertical, AppTheme.spacingTight)
            .frame(minHeight: 44)
            .background(pillBackground(for: level, morphSource: morphSource))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(borderColor(for: level), lineWidth: 1)
            )
            .scaleEffect(scaleFactor(for: level, isCelebrating: isCelebrating))
            .shadow(
                color: shadowColor(for: level, isCelebrating: isCelebrating),
                radius: shadowRadius(for: level, isCelebrating: isCelebrating),
                x: 0,
                y: isCelebrating && !reduceTransparency ? 2 : 0
            )
            .animation(
                reduceMotion ? nil : AppTheme.celebrationPulseAnimation(for: level),
                value: isCelebrating
            )
            .overlay {
                if morphSource {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(
                            infoCardTintColor(for: selectedBadgeInfo ?? .harvest)
                                .opacity(0.32 * infoCardBloomProgress),
                            lineWidth: 1.6
                        )
                        .scaleEffect(1.02 + (0.08 * (1 - infoCardBloomProgress)))
                }
            }
            .opacity(morphSource && !reduceMotion ? 0.92 : 1)
    }

}

private extension DateSectionView {
    func backgroundFill(for level: JournalCompletionLevel) -> AnyShapeStyle {
        switch level {
        case .quickCheckIn:
            return AnyShapeStyle(AppTheme.journalQuickCheckInBackground)
        case .standardReflection:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalStandardBackgroundStart, AppTheme.journalStandardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .fullFiveCubed:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalFullBackgroundStart, AppTheme.journalFullBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .none:
            return AnyShapeStyle(AppTheme.journalBackground)
        }
    }

    func borderColor(for level: JournalCompletionLevel) -> Color {
        switch level {
        case .quickCheckIn:
            return AppTheme.journalQuickCheckInBorder
        case .standardReflection:
            return AppTheme.journalStandardBorder
        case .fullFiveCubed:
            return AppTheme.journalFullBorder
        case .none:
            return AppTheme.journalBorder
        }
    }

    func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .quickCheckIn:
            return 1.008
        case .standardReflection:
            return 1.015
        case .fullFiveCubed:
            return 1.02
        case .none:
            return 1.0
        }
    }

    func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .quickCheckIn:
            return AppTheme.journalQuickCheckInGlow.opacity(0.25)
        case .standardReflection:
            return AppTheme.journalStandardGlow.opacity(0.4)
        case .fullFiveCubed:
            return AppTheme.journalFullGlow.opacity(0.48)
        case .none:
            return .clear
        }
    }

    func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .quickCheckIn:
            return 4
        case .standardReflection:
            return 8
        case .fullFiveCubed:
            return 11
        case .none:
            return 0
        }
    }

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
                scheduleInfoCardAutoDismiss()
            }
            return
        }

        withAnimation(infoCardEntranceAnimation) {
            isInfoCardPresented = true
        }
        triggerInfoCardBloomPulse()
        scheduleInfoCardAutoDismiss()
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

    func scheduleInfoCardAutoDismiss() {
        infoCardDismissTask?.cancel()
        infoCardDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4.8))
            guard !Task.isCancelled else { return }
            withAnimation(infoCardExitAnimation) {
                isInfoCardPresented = false
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 1 : 150))
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

    func pillBackground(for level: JournalCompletionLevel, morphSource: Bool) -> AnyView {
        let base = RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            .fill(backgroundFill(for: level))

        guard morphSource, !reduceMotion else {
            return AnyView(base)
        }

        return AnyView(
            base.matchedGeometryEffect(
                id: "completionInfoMorphSurface",
                in: completionInfoMorphNamespace,
                properties: .frame,
                anchor: .topLeading,
                isSource: true
            )
        )
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

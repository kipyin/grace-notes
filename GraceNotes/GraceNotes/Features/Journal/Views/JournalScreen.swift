import SwiftUI
import SwiftData
import UIKit
import Combine

// swiftlint:disable file_length type_body_length
// Keeping interaction helpers in this file preserves `private` on `@State` / `@AppStorage` / `@FocusState`;
// Swift does not allow another file's `extension` to see those members.

// This screen still hosts multiple interaction surfaces while the UI refresh is in progress.

private enum JournalScreenLayout {
    static let journalScrollCoordinateSpaceName = "journalMainScroll"
    static let unlockToastScrollDismissThreshold: CGFloat = 20
    /// Unlock feedback ribbon / toolbar banner auto-dismiss after present.
    static let unlockFeedbackAutoDismissSeconds: TimeInterval = 5
    /// Reveal toolbar chip when scroll passes this threshold: iOS 18+ uses `contentOffset.y` **>** this;
    /// iOS 17 uses completion-header scroll-space `minY` **<** `-this`.
    static let stickyCompletionBarScrollRevealPoints: CGFloat = 0
    /// Toolbar chip opacity fade; inline header badge stays hidden until this elapses after hiding the chip
    /// so the two controls do not animate as one “moving down” illusion.
    static let stickyToolbarChipFadeDurationSeconds: TimeInterval = 0.28
    /// After the sticky completion chip expands, collapse back to icon-only when idle this long.
    static let stickyCompletionChipAutoCollapseSeconds: TimeInterval = 3

    /// Expand/collapse: smooth with ``JournalCompletionBarChip`` crossfade; Reduce Motion uses a shorter ease.
    static func stickyChipMorphAnimation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.22)
        }
        if #available(iOS 26, *) {
            return .smooth(duration: 0.38, extraBounce: 0.05)
        }
        return .easeInOut(duration: 0.32)
    }
}

private struct JournalScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// iOS 17: completion header top in ``journalMainScroll`` (negative after scrolling past the viewport top).
private struct JournalHeaderScrollMinYPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .infinity
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next.isFinite {
            value = next
        }
    }
}

private struct JournalNavigationBarTapProbe: UIViewControllerRepresentable {
    struct TapContext {
        let isNavigationChrome: Bool
    }

    let isEnabled: Bool
    let onTap: (TapContext) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onTap: onTap)
    }

    func makeUIViewController(context: Context) -> ProbeViewController {
        let controller = ProbeViewController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ProbeViewController, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onTap = onTap
        uiViewController.coordinator = context.coordinator
        uiViewController.attachIfPossible()
    }

    static func dismantleUIViewController(_ uiViewController: ProbeViewController, coordinator: Coordinator) {
        coordinator.detach()
        uiViewController.coordinator = nil
    }

    final class ProbeViewController: UIViewController {
        weak var coordinator: Coordinator?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            attachIfPossible()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            attachIfPossible()
        }

        func attachIfPossible() {
            guard let navigationContainerView = navigationController?.view else { return }
            coordinator?.attach(to: navigationContainerView, host: self)
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationContainerView: UIView?
        weak var hostViewController: ProbeViewController?
        var isEnabled: Bool
        var onTap: (TapContext) -> Void
        private weak var recognizer: UITapGestureRecognizer?

        init(isEnabled: Bool, onTap: @escaping (TapContext) -> Void) {
            self.isEnabled = isEnabled
            self.onTap = onTap
        }

        func attach(to navigationContainerView: UIView, host: ProbeViewController) {
            guard self.navigationContainerView !== navigationContainerView else {
                hostViewController = host
                return
            }
            detach()
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            navigationContainerView.addGestureRecognizer(recognizer)
            self.navigationContainerView = navigationContainerView
            self.hostViewController = host
            self.recognizer = recognizer
        }

        func detach() {
            if let recognizer, let navigationContainerView {
                navigationContainerView.removeGestureRecognizer(recognizer)
            }
            recognizer = nil
            navigationContainerView = nil
            hostViewController = nil
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard isEnabled, let navigationContainerView else { return }
            let location = recognizer.location(in: navigationContainerView)
            let isNavigationChrome: Bool
            if let nav = hostViewController?.navigationController {
                let navBar = nav.navigationBar
                let barFrame = navBar.convert(navBar.bounds, to: navigationContainerView)
                isNavigationChrome = barFrame.contains(location)
            } else {
                isNavigationChrome = false
            }
            onTap(TapContext(isNavigationChrome: isNavigationChrome))
        }

        func gestureRecognizer(
            _: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private extension View {
    @ViewBuilder
    func journalDismissUnlockToastOnTapOutside(_ isPresented: Bool, dismiss: @escaping () -> Void) -> some View {
        if isPresented {
            self.simultaneousGesture(TapGesture().onEnded { _ in dismiss() })
        } else {
            self
        }
    }

    /// Non-invasive tap-to-dismiss hook used on non-input regions.
    @ViewBuilder
    func journalDismissInlineEditOnTap(_ isPresented: Bool, dismiss: @escaping () -> Void) -> some View {
        if isPresented {
            self.simultaneousGesture(TapGesture().onEnded { _ in dismiss() })
        } else {
            self
        }
    }
}

struct JournalScreen: View {
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.journalBloomAtmosphereHosted) private var journalBloomAtmosphereHosted
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewModel = JournalViewModel()
    @State private var shareableImage: ShareableImage?
    @State private var showShareComposer = false
    @State private var showSavedToPhotosToast = false
    @State private var savedToPhotosDismissTask: Task<Void, Never>?
    @State private var hasTrackedInitialLoad = false
    /// Blocks session-resume refresh until the first `.task` load finishes (avoids racing the empty ViewModel).
    @State private var hasCompletedInitialJournalLoadTask = false
    @State private var statusCelebrationDismissTask: Task<Void, Never>?
    @State private var celebratingLevel: JournalCompletionLevel?
    @State private var hasInitializedCompletionTracking = false
    @State private var previousCompletionLevel: JournalCompletionLevel = .soil
    @State private var previousGratitudesCount = 0
    @State private var previousNeedsCount = 0
    @State private var previousPeopleCount = 0
    @State private var unlockToastLevel: JournalCompletionLevel?
    @State private var unlockToastMilestone: JournalUnlockMilestoneHighlight = .none
    @State private var journalScrollOffsetY: CGFloat = 0
    /// Sticky toolbar chip: iOS 18+ uses ``onScrollGeometryChange``; iOS 17 uses header scroll ``minY`` preference.
    @State private var stickyCompletionRevealedByScroll = false
    @State private var stickyCompletionChipLabelExpanded = false
    @State private var stickyCompletionChipCollapseTask: Task<Void, Never>?
    @State private var stickyChipExpansionScrollBaselineY: CGFloat?
    /// After the sticky chip fades out, the inline header pill may show (see ``applyStickyCompletionRevealed``).
    @State private var inlineBadgeUnlockedAfterStickyFade = true
    @State private var inlineStickyFadeUnlockTask: Task<Void, Never>?
    @State private var unlockToastScrollBaseline: CGFloat?
    @State private var unlockFeedbackAutoDismissTask: Task<Void, Never>?
    /// UIKit keyboard overlap with the key window; drives extra scroll padding and scroll-to-visible.
    @State private var keyboardOverlapHeight: CGFloat = 0
    /// Bottom safe area of the scroll view (tab bar / home indicator; may track keyboard when visible).
    @State private var journalScrollBottomSafeArea: CGFloat = 0
    @State private var journalKeyboardScrollTask: Task<Void, Never>?
    @State private var isClearingFocusAfterScrollDismiss = false
    @State private var tutorialProgress = JournalTutorialProgress()
    @State private var showAppTour = false
    @State private var appTourSkipsCongratulations = false
    @AppStorage(JournalOnboardingStorageKeys.completedGuidedJournal) private var hasCompletedGuidedJournal = false
    @AppStorage(JournalOnboardingStorageKeys.hasSeenAppTour) private var hasSeenAppTour = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedRemindersSuggestion)
    private var dismissedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedICloudSuggestion)
    private var dismissedICloudSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedRemindersSuggestion)
    private var openedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedICloudSuggestion)
    private var openedICloudSuggestion = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = false
    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue

    @State private var gratitudeInput = ""
    @State private var needInput = ""
    @State private var personInput = ""
    @State private var gratitudeInputNewlineCount = 0
    @State private var needInputNewlineCount = 0
    @State private var personInputNewlineCount = 0

    @State private var editingGratitudeIndex: Int?
    @State private var editingNeedIndex: Int?
    @State private var editingPersonIndex: Int?
    @State private var isGratitudeAddMorphComposerVisible = false
    @State private var isNeedAddMorphComposerVisible = false
    @State private var isPersonAddMorphComposerVisible = false
    @State private var isGratitudeTransitioning = false
    @State private var isNeedTransitioning = false
    @State private var isPersonTransitioning = false
    @FocusState private var isGratitudeInputFocused: Bool
    @FocusState private var isNeedInputFocused: Bool
    @FocusState private var isPersonInputFocused: Bool
    @FocusState private var isReadingNotesFocused: Bool
    @FocusState private var isReflectionsFocused: Bool
    @Namespace private var completionInfoMorphNamespace
    @State private var completionInfoPresentation = JournalCompletionInfoPresentation()
    @State private var completionHeaderScrollPulse: UInt = 0
    var entryDate: Date?

    /// Standard navigation-bar control height (HIG minimum touch target; scales with Dynamic Type).
    @ScaledMetric(relativeTo: .body) private var journalToolbarControlHeight: CGFloat = 47
    /// Pulls the leading toolbar chip toward the safe-area edge (pt; negative = left).
    private let stickyCompletionToolbarLeadingInset: CGFloat = -4

    private var stickyJournalCompletionToolbarChip: some View {
        JournalCompletionBarChip(
            toolbarControlHeight: journalToolbarControlHeight,
            completionLevel: viewModel.completionLevel,
            gratitudesCount: viewModel.gratitudes.count,
            needsCount: viewModel.needs.count,
            peopleCount: viewModel.people.count,
            showsCompletionTitle: stickyCompletionChipLabelExpanded,
            onCollapseExpandTap: {
                if stickyCompletionChipLabelExpanded {
                    collapseStickyCompletionChipLabel()
                } else {
                    expandStickyCompletionChipLabel()
                }
            },
            onShowCompletionInfo: {
                let badge = CompletionBadgeInfo.matching(viewModel.completionLevel)
                completionInfoPresentation.completionBadgeTapped(badge, reduceMotion: reduceMotion)
                if completionInfoPresentation.isInfoCardPresented {
                    completionHeaderScrollPulse &+= 1
                }
            }
        )
    }

    /// Leading toolbar chrome for the sticky chip (shared iOS 26 / earlier).
    private var stickyCompletionToolbarLeadingChrome: some View {
        stickyJournalCompletionToolbarChip
            .padding(.leading, stickyCompletionToolbarLeadingInset)
        .opacity(showStickyJournalCompletionBar ? 1 : 0)
        .animation(
            .easeInOut(duration: JournalScreenLayout.stickyToolbarChipFadeDurationSeconds),
            value: stickyCompletionRevealedByScroll
        )
        .allowsHitTesting(showStickyJournalCompletionBar)
        .accessibilityHidden(!showStickyJournalCompletionBar)
    }

    @ToolbarContentBuilder
    private var journalToolbarContent: some ToolbarContent {
        if #available(iOS 26, *) {
            // Opacity only (chip stays laid out): `if` + transition fights Liquid Glass and mid-fade layout collapse.
            ToolbarItem(placement: .topBarLeading) {
                stickyCompletionToolbarLeadingChrome
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) {
                stickyCompletionToolbarLeadingChrome
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                shareTapped()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(AppTheme.outfitSemiboldHeadline)
            }
            .accessibilityLabel(String(localized: "common.share"))
            .accessibilityIdentifier("Share")
        }
    }

    private var journalScreenBaseStack: some View {
        ZStack {
            if effectiveTodayAppearance == .bloom, !journalBloomAtmosphereHosted {
                SummerPaperBackgroundView()
            }
            if effectiveTodayAppearance == .bloom, !journalBloomAtmosphereHosted {
                SummerLeavesOverlaySeam(reduceMotion: reduceMotion)
            }
            journalScrollContent
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            journalUnlockToolbarBannerIfNeeded
        }
    }

    @ViewBuilder
    private var journalUnlockToolbarBannerIfNeeded: some View {
        if journalUnlockFeedbackPlacement == .toolbarBanner,
           let level = unlockToastLevel {
            Button {
                dismissUnlockToastIfNeeded()
            } label: {
                JournalUnlockFeedbackSurface(
                    level: level,
                    milestoneHighlight: unlockToastMilestone
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppTheme.todayHorizontalPadding)
            .accessibilityLabel(
                JournalUnlockFeedbackMessage.message(for: level, milestone: unlockToastMilestone)
            )
            .accessibilityHint(String(localized: "common.dismiss"))
            .transition(.opacity)
        }
    }

    var body: some View {
        journalScreenDecoratedRoot
    }

    private var journalScreenDecoratedRoot: some View {
        let palette = TodayJournalPalette.resolve(mode: effectiveTodayAppearance)
        return journalScreenBaseStack
            .environment(\.todayJournalPalette, palette)
            .overlay { journalToastOverlay }
            .navigationTitle(navigationTitle)
            .toolbar { journalToolbarContent }
            .toolbarBackground(
                effectiveTodayAppearance == .bloom ? .hidden : .automatic,
                for: .navigationBar
            )
            .sheet(isPresented: $showShareComposer) {
                JournalShareComposerView(
                    basePayload: viewModel.exportSnapshot(),
                    onDismiss: { showShareComposer = false },
                    onShare: { image in
                        showShareComposer = false
                        Task { @MainActor in
                            await Task.yield()
                            shareableImage = ShareableImage(image: image)
                        }
                    }
                )
            }
            .sheet(item: $shareableImage) { item in
                ShareSheet(
                    activityItems: [item.image],
                    applicationActivities: [SaveToPhotosActivity(image: item.image)]
                )
            }
            .fullScreenCover(isPresented: $showAppTour) {
                AppTourView(
                    onFinish: completeAppTour,
                    skipsCongratulationsPage: appTourSkipsCongratulations
                )
            }
            .onChange(of: showAppTour) { _, isPresented in
                dismissAllJournalFocusIfAppTourPresented(isPresented)
            }
            .onChange(of: isAnyChipInputFocused) { wasFocused, isFocused in
                handleChipInputFocusChange(wasFocused: wasFocused, isFocused: isFocused)
            }
            .onReceive(NotificationCenter.default.publisher(for: .photoSavedToLibrary)) { _ in
                scheduleSavedToPhotosToast()
            }
            .onDisappear {
                statusCelebrationDismissTask?.cancel()
                inlineStickyFadeUnlockTask?.cancel()
                unlockFeedbackAutoDismissTask?.cancel()
            }
            .onChange(of: onboardingPresentation.step) { _, newStep in
                focusOnboardingStepIfNeeded(newStep)
            }
            .onChange(of: journalProgressFingerprint) { _, _ in
                if showShareComposer {
                    showShareComposer = false
                }
                handleJournalProgressChange()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChangeForResume(oldPhase: oldPhase, newPhase: newPhase)
            }
            .onChange(of: appNavigation.selectedTab) { oldTab, newTab in
                guard newTab == .today, oldTab != .today else { return }
                refreshTodayAfterSessionResumeIfNeeded()
            }
            .task(id: entryDate) {
                await runJournalScreenLoadTask()
            }
    }

    private func handleScenePhaseChangeForResume(oldPhase: ScenePhase, newPhase: ScenePhase) {
        guard oldPhase != .active, newPhase == .active else { return }
        guard appNavigation.selectedTab == .today else { return }
        refreshTodayAfterSessionResumeIfNeeded()
    }

    private var journalScrollContent: some View {
        ScrollViewReader { proxy in
            journalScrollView(proxy: proxy)
        }
    }

    @ViewBuilder
    private func journalScrollView(proxy: ScrollViewProxy) -> some View {
        journalScrollViewWithModifiers(
            content: journalScrollRootScrollView(proxy: proxy),
            proxy: proxy
        )
    }

    @ViewBuilder
    private func journalScrollRootScrollView(proxy: ScrollViewProxy) -> some View {
        if #available(iOS 18, *) {
            ScrollView {
                journalScrollMainColumn(proxy: proxy)
            }
            .onScrollGeometryChange(for: Bool.self) { geo in
                JournalStickyCompletionVisibility.shouldShowBarIndicator(
                    scrollContentOffsetY: geo.contentOffset.y,
                    scrollRevealThreshold: JournalScreenLayout.stickyCompletionBarScrollRevealPoints,
                    currentlyRevealed: stickyCompletionRevealedByScroll
                )
            } action: { _, pastThreshold in
                applyStickyCompletionRevealed(pastThreshold)
            }
        } else {
            ScrollView {
                journalScrollMainColumn(proxy: proxy)
            }
        }
    }

    private func applyStickyCompletionRevealed(_ revealed: Bool) {
        guard stickyCompletionRevealedByScroll != revealed else { return }

        if !revealed {
            collapseStickyCompletionChipLabel()
        }

        inlineStickyFadeUnlockTask?.cancel()
        inlineStickyFadeUnlockTask = nil

        if reduceMotion {
            stickyCompletionRevealedByScroll = revealed
            inlineBadgeUnlockedAfterStickyFade = true
            return
        }

        let fadeDuration = JournalScreenLayout.stickyToolbarChipFadeDurationSeconds

        if !revealed {
            inlineBadgeUnlockedAfterStickyFade = false
        }

        let shouldAnimateUnlockPlacementCrossfade = unlockToastLevel != nil
            && JournalUnlockFeedbackPlacement.resolve(
                isUnlockPresent: true,
                stickyCompletionRevealed: stickyCompletionRevealedByScroll
            ) != JournalUnlockFeedbackPlacement.resolve(
                isUnlockPresent: true,
                stickyCompletionRevealed: revealed
            )

        if shouldAnimateUnlockPlacementCrossfade {
            withAnimation(unlockFeedbackPlacementAnimation) {
                stickyCompletionRevealedByScroll = revealed
            }
        } else {
            stickyCompletionRevealedByScroll = revealed
        }

        if !revealed {
            let nanos = UInt64(fadeDuration * 1_000_000_000)
            inlineStickyFadeUnlockTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: nanos)
                guard !Task.isCancelled else { return }
                inlineBadgeUnlockedAfterStickyFade = true
            }
        }
    }

    private func applyStickyCompletionFromHeaderScrollMinY(_ minY: CGFloat) {
        let revealed = JournalStickyCompletionVisibility.shouldShowBarIndicator(
            headerMinYInScrollSpace: minY,
            scrollRevealThreshold: JournalScreenLayout.stickyCompletionBarScrollRevealPoints,
            currentlyRevealed: stickyCompletionRevealedByScroll
        )
        applyStickyCompletionRevealed(revealed)
    }

    private func cancelStickyCompletionChipCollapseTask() {
        stickyCompletionChipCollapseTask?.cancel()
        stickyCompletionChipCollapseTask = nil
    }

    private func scheduleStickyCompletionChipAutoCollapse() {
        cancelStickyCompletionChipCollapseTask()
        let seconds = JournalScreenLayout.stickyCompletionChipAutoCollapseSeconds
        stickyCompletionChipCollapseTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            withAnimation(JournalScreenLayout.stickyChipMorphAnimation(reduceMotion: reduceMotion)) {
                stickyCompletionChipLabelExpanded = false
            }
            stickyCompletionChipCollapseTask = nil
        }
    }

    private func expandStickyCompletionChipLabel() {
        withAnimation(JournalScreenLayout.stickyChipMorphAnimation(reduceMotion: reduceMotion)) {
            stickyCompletionChipLabelExpanded = true
        }
        stickyChipExpansionScrollBaselineY = journalScrollOffsetY
        scheduleStickyCompletionChipAutoCollapse()
    }

    private func collapseStickyCompletionChipLabel() {
        cancelStickyCompletionChipCollapseTask()
        withAnimation(JournalScreenLayout.stickyChipMorphAnimation(reduceMotion: reduceMotion)) {
            stickyCompletionChipLabelExpanded = false
        }
        stickyChipExpansionScrollBaselineY = nil
    }

    @ViewBuilder
    private func journalScrollViewWithModifiers(content: some View, proxy: ScrollViewProxy) -> some View {
        journalScrollViewWithKeyboardTracking(
            content: journalScrollViewWithChrome(content: content),
            proxy: proxy
        )
    }

    @ViewBuilder
    private func journalScrollViewWithChrome(content: some View) -> some View {
        content
            .background(
                JournalNavigationBarTapProbe(isEnabled: isAnyInlineChipEditing) { context in
                    guard context.isNavigationChrome else { return }
                    dismissInlineChipEditingSession()
                }
            )
            .coordinateSpace(name: JournalScreenLayout.journalScrollCoordinateSpaceName)
    }

    @ViewBuilder
    private func journalScrollViewWithKeyboardTracking(content: some View, proxy: ScrollViewProxy) -> some View {
        content
            .onReceive(
                NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)
            ) { notification in
                handleKeyboardDidChangeFrame(notification)
            }
            .onChange(of: keyboardOverlapHeight) { oldOverlap, newOverlap in
                journalKeyboardOverlapChanged(proxy: proxy, oldOverlap: oldOverlap, newOverlap: newOverlap)
            }
            .onChange(of: isReadingNotesFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.readingNotes))
            }
            .onChange(of: isReflectionsFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.reflections))
            }
            .onChange(of: isGratitudeInputFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.gratitudeSection))
            }
            .onChange(of: isNeedInputFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.needInputArea))
            }
            .onChange(of: isPersonInputFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.peopleInputArea))
            }
            .overlay {
                GeometryReader { geo in
                    Color.clear.preference(
                        key: JournalScrollBottomSafeAreaPreferenceKey.self,
                        value: geo.safeAreaInsets.bottom
                    )
                }
                .allowsHitTesting(false)
            }
            .onPreferenceChange(JournalScrollBottomSafeAreaPreferenceKey.self) { inset in
                journalScrollBottomSafeArea = inset
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(todayPalette.background.ignoresSafeArea(edges: [.top, .bottom]))
    }

    private func journalKeyboardOverlapChanged(
        proxy: ScrollViewProxy,
        oldOverlap: CGFloat,
        newOverlap: CGFloat
    ) {
        if oldOverlap > 0, newOverlap == 0, isAnyJournalFieldFocused {
            clearJournalFocusAfterScrollDismiss()
        }
        guard newOverlap > 0, isAnyJournalFieldFocused else { return }
        guard JournalKeyboardScrollCoordinator.shouldScheduleScrollAfterOverlapChange(
            oldOverlap: oldOverlap,
            newOverlap: newOverlap
        ) else { return }
        scheduleJournalKeyboardScroll(proxy: proxy, reason: .keyboardDidChangeFrame)
    }

    private func handleKeyboardDidChangeFrame(_ notification: Notification) {
        let nextOverlap = JournalKeyboardOverlapReader.overlapHeight(from: notification)
        keyboardOverlapHeight = nextOverlap
    }

    private func clearJournalFocusAfterScrollDismiss() {
        guard !isClearingFocusAfterScrollDismiss else { return }
        isClearingFocusAfterScrollDismiss = true
        journalKeyboardScrollTask?.cancel()
        clearJournalFocusAndResignFirstResponder()
        DispatchQueue.main.async {
            for _ in 1...3 {
                if !isAnyJournalFieldFocused { break }
                clearJournalFocusAndResignFirstResponder()
            }
            isClearingFocusAfterScrollDismiss = false
        }
    }

    private func clearJournalFocusAndResignFirstResponder() {
        clearAllJournalFocusBindings()
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func clearAllJournalFocusBindings() {
        isGratitudeInputFocused = false
        isNeedInputFocused = false
        isPersonInputFocused = false
        isReadingNotesFocused = false
        isReflectionsFocused = false
    }

}

private extension JournalScreen {
    var showStickyJournalCompletionBar: Bool {
        stickyCompletionRevealedByScroll
    }

    var journalUnlockFeedbackPlacement: JournalUnlockFeedbackPlacement {
        JournalUnlockFeedbackPlacement.resolve(
            isUnlockPresent: unlockToastLevel != nil,
            stickyCompletionRevealed: showStickyJournalCompletionBar
        )
    }

    /// Fades unlock feedback when moving between the in-page ribbon and the toolbar inset.
    var unlockFeedbackPlacementAnimation: Animation {
        reduceMotion
            ? .easeInOut(duration: 0.18)
            : .easeInOut(duration: 0.25)
    }

    /// Hidden while the sticky chip shows and briefly after it fades so two badges never overlap in motion.
    var isInlineBadgeHiddenDuringStickyFade: Bool {
        stickyCompletionRevealedByScroll || !inlineBadgeUnlockedAfterStickyFade
    }

    @ViewBuilder
    func journalScrollMainColumn(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.todaySectionSpacing) {
            journalTodayHeaderGroup(isInlineCompletionBadgeHidden: isInlineBadgeHiddenDuringStickyFade)
                .journalDismissInlineEditOnTap(isAnyInlineChipEditing) {
                    dismissInlineChipEditingSession()
                }

            journalSentenceSections(proxy: proxy)
                .id(JournalScrollTarget.sentenceSections)

            journalNotesSections(proxy: proxy)

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Text(saveErrorMessage)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(todayPalette.journalError)
            }

            if isAnyInlineChipEditing {
                Color.clear
                    .frame(minHeight: SequentialSectionInlineLayout.inlineEditBottomTapCatcherMinHeight)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismissInlineChipEditingSession()
                    }
            }
        }
        .padding(.horizontal, AppTheme.todayHorizontalPadding)
        .padding(.top, AppTheme.todayTopPadding)
        .padding(.bottom, contentBottomPadding)
        .background(journalScrollOffsetReader)
        .background(journalInlineScrollBackdropDismiss)
        .journalDismissUnlockToastOnTapOutside(unlockToastLevel != nil) {
            dismissUnlockToastIfNeeded()
        }
        .onPreferenceChange(JournalScrollOffsetPreferenceKey.self) { offsetY in
            journalScrollOffsetPreferenceChanged(offsetY)
        }
        .onPreferenceChange(JournalHeaderScrollMinYPreferenceKey.self) { headerMinY in
            if #available(iOS 18, *) { return }
            applyStickyCompletionFromHeaderScrollMinY(headerMinY)
        }
        .onChange(of: completionHeaderScrollPulse) { _, _ in
            scrollJournalCompletionHeaderToTop(using: proxy)
        }
    }

    func journalScrollOffsetPreferenceChanged(_ offsetY: CGFloat) {
        journalScrollOffsetY = offsetY
        if stickyCompletionChipLabelExpanded, let baseline = stickyChipExpansionScrollBaselineY {
            if abs(offsetY - baseline) > JournalScreenLayout.unlockToastScrollDismissThreshold {
                stickyChipExpansionScrollBaselineY = offsetY
                scheduleStickyCompletionChipAutoCollapse()
            }
        }
        if unlockToastLevel != nil,
           !showStickyJournalCompletionBar,
           let baseline = unlockToastScrollBaseline {
            if abs(offsetY - baseline) > JournalScreenLayout.unlockToastScrollDismissThreshold {
                dismissUnlockToastIfNeeded()
            }
        }
    }

    private func scrollJournalCompletionHeaderToTop(using proxy: ScrollViewProxy) {
        if reduceMotion {
            proxy.scrollTo(JournalScrollTarget.completionHeader, anchor: .top)
        } else {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(JournalScrollTarget.completionHeader, anchor: .top)
            }
        }
    }

    @ViewBuilder
    private func journalTodayHeaderGroup(isInlineCompletionBadgeHidden: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if #available(iOS 18, *) {
                journalCompletionDateSection(isInlineCompletionBadgeHidden: isInlineCompletionBadgeHidden)
                    .id(JournalScrollTarget.completionHeader)
            } else {
                journalCompletionDateSection(isInlineCompletionBadgeHidden: isInlineCompletionBadgeHidden)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: JournalHeaderScrollMinYPreferenceKey.self,
                                value: geo.frame(
                                    in: .named(JournalScreenLayout.journalScrollCoordinateSpaceName)
                                ).minY
                            )
                        }
                    }
                    .id(JournalScrollTarget.completionHeader)
            }

            journalUnlockHeaderRibbonIfNeeded()

            journalOnboardingSuggestionIfNeeded
                .padding(.top, AppTheme.todaySectionSpacing)
        }
    }

    @ViewBuilder
    private func journalUnlockHeaderRibbonIfNeeded() -> some View {
        if journalUnlockFeedbackPlacement == .headerRibbon,
           let level = unlockToastLevel {
            Button {
                dismissUnlockToastIfNeeded()
            } label: {
                JournalUnlockFeedbackSurface(
                    level: level,
                    milestoneHighlight: unlockToastMilestone
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                JournalUnlockFeedbackMessage.message(for: level, milestone: unlockToastMilestone)
            )
            .accessibilityHint(String(localized: "common.dismiss"))
            .transition(.opacity)
            .padding(.top, AppTheme.spacingTight)
        }
    }

    private func journalCompletionDateSection(isInlineCompletionBadgeHidden: Bool) -> some View {
        DateSectionView(
            completionInfo: completionInfoPresentation,
            completionInfoMorphNamespace: completionInfoMorphNamespace,
            isInlineCompletionBadgeHidden: isInlineCompletionBadgeHidden,
            completionLevel: viewModel.completionLevel,
            celebratingLevel: celebratingLevel,
            gratitudesCount: viewModel.gratitudes.count,
            needsCount: viewModel.needs.count,
            peopleCount: viewModel.people.count
        )
    }

    var effectiveTodayAppearance: JournalAppearanceMode {
        if entryDate != nil { return .standard }
        return JournalAppearanceMode.resolveStored(rawValue: journalTodayAppearanceRaw)
    }

    var todayPalette: TodayJournalPalette {
        TodayJournalPalette.resolve(mode: effectiveTodayAppearance)
    }

    /// Tracks chip counts and completion level together so milestones like first 1/1/1 fire without a rank change.
    var journalProgressFingerprint: String {
        let gratitudesCount = viewModel.gratitudes.count
        let needsCount = viewModel.needs.count
        let peopleCount = viewModel.people.count
        let levelRaw = viewModel.completionLevel.rawValue
        return "\(gratitudesCount)-\(needsCount)-\(peopleCount)|\(levelRaw)"
    }

    var isAnyInlineChipEditing: Bool {
        editingGratitudeIndex != nil
            || editingNeedIndex != nil
            || editingPersonIndex != nil
            || isGratitudeAddMorphComposerVisible
            || isNeedAddMorphComposerVisible
            || isPersonAddMorphComposerVisible
    }

    var isAnyChipInputFocused: Bool {
        isGratitudeInputFocused || isNeedInputFocused || isPersonInputFocused
    }

    func dismissInlineChipEditingSession() {
        guard isAnyInlineChipEditing else { return }
        commitActiveInlineChipEdit()
    }

    func handleChipInputFocusChange(wasFocused: Bool, isFocused: Bool) {
        guard wasFocused, !isFocused else { return }
        Task { @MainActor in
            await Task.yield()
            guard !isAnyChipInputFocused else { return }
            dismissInlineChipEditingSession()
        }
    }

    /// Saves the active inline strip edit and dismisses keyboard (same as tapping outside the editor).
    func commitActiveInlineChipEdit() {
        if editingGratitudeIndex != nil {
            submit(section: .gratitude, restoreFocusAfterSubmit: false)
        } else if editingNeedIndex != nil {
            submit(section: .need, restoreFocusAfterSubmit: false)
        } else if editingPersonIndex != nil {
            submit(section: .person, restoreFocusAfterSubmit: false)
        } else if isGratitudeAddMorphComposerVisible {
            dismissEmptyAddMorphOrSubmit(section: .gratitude, restoreFocusAfterSubmit: false)
        } else if isNeedAddMorphComposerVisible {
            dismissEmptyAddMorphOrSubmit(section: .need, restoreFocusAfterSubmit: false)
        } else if isPersonAddMorphComposerVisible {
            dismissEmptyAddMorphOrSubmit(section: .person, restoreFocusAfterSubmit: false)
        }
    }

    func dismissEmptyAddMorphOrSubmit(section: StripSection, restoreFocusAfterSubmit: Bool) {
        let adapter = stripSectionAdapter(for: section)
        let trimmed = adapter.input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearAddMorphComposer(for: section)
            clearChipInputFocus()
        } else {
            submit(section: section, restoreFocusAfterSubmit: restoreFocusAfterSubmit)
        }
    }

    func clearAddMorphComposer(for section: StripSection) {
        switch section {
        case .gratitude:
            isGratitudeAddMorphComposerVisible = false
        case .need:
            isNeedAddMorphComposerVisible = false
        case .person:
            isPersonAddMorphComposerVisible = false
        }
    }

    func isAddMorphComposerVisible(for section: StripSection) -> Bool {
        switch section {
        case .gratitude:
            return isGratitudeAddMorphComposerVisible
        case .need:
            return isNeedAddMorphComposerVisible
        case .person:
            return isPersonAddMorphComposerVisible
        }
    }

    var contentBottomPadding: CGFloat {
        AppTheme.todayBottomPadding + bottomSpacingAdjustment + journalKeyboardExtraScrollPadding
    }

    /// Extra bottom padding so multiline editors can scroll above the keyboard with a comfort margin.
    private var journalKeyboardExtraScrollPadding: CGFloat {
        guard keyboardOverlapHeight > 0 else { return 0 }
        if isMultilineNotesFieldFocused {
            let uncovered = max(0, keyboardOverlapHeight - journalScrollBottomSafeArea)
            return uncovered + JournalKeyboardScrollMetrics.comfortMarginAboveKeyboard()
        }
        if isAnyChipInputFocused {
            // Keep chip editor caret a little above keyboard without the large uncovered-padding jump.
            return JournalKeyboardScrollMetrics.comfortMarginAboveKeyboard()
        }
        return 0
    }

    /// Single backdrop behind the journal column: taps on “empty” scroll space dismiss inline editing.
    @ViewBuilder
    var journalInlineScrollBackdropDismiss: some View {
        if isAnyInlineChipEditing {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissInlineChipEditingSession()
                }
        }
    }

    private var bottomSpacingAdjustment: CGFloat {
        var adjustment: CGFloat = AppTheme.spacingTight
        if dynamicTypeSize.isAccessibilitySize {
            adjustment += AppTheme.spacingRegular
        }
        if verticalSizeClass == .compact {
            adjustment += AppTheme.spacingRegular
        }
        return adjustment
    }

    @ViewBuilder
    var journalOnboardingSuggestionIfNeeded: some View {
        if let onboardingSuggestion {
            JournalOnboardingSuggestionView(
                title: suggestionTitle(for: onboardingSuggestion),
                message: suggestionMessage(for: onboardingSuggestion),
                primaryActionTitle: String(localized: "settings.openSettings"),
                secondaryActionTitle: String(localized: "common.notNow"),
                onPrimaryAction: { openSettings(for: onboardingSuggestion) },
                onSecondaryAction: { dismissSuggestion(onboardingSuggestion) }
            )
        }
    }

    func journalSentenceSections(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.todayClusterSpacing) {
            gratitudesSequentialSection
            needsSequentialSection
            peopleSequentialSection
        }
        .padding(.top, AppTheme.spacingTight)
        .onChange(of: gratitudeInput) { oldValue, newValue in
            scheduleChipKeyboardScrollOnTextChange(
                .init(
                    proxy: proxy,
                    isInputFocused: isGratitudeInputFocused,
                    oldValue: oldValue,
                    newValue: newValue,
                    scrollTarget: .gratitudeSection
                ),
                storedNewlineCount: &gratitudeInputNewlineCount
            )
        }
        .onChange(of: needInput) { oldValue, newValue in
            scheduleChipKeyboardScrollOnTextChange(
                .init(
                    proxy: proxy,
                    isInputFocused: isNeedInputFocused,
                    oldValue: oldValue,
                    newValue: newValue,
                    scrollTarget: .needInputArea
                ),
                storedNewlineCount: &needInputNewlineCount
            )
        }
        .onChange(of: personInput) { oldValue, newValue in
            scheduleChipKeyboardScrollOnTextChange(
                .init(
                    proxy: proxy,
                    isInputFocused: isPersonInputFocused,
                    oldValue: oldValue,
                    newValue: newValue,
                    scrollTarget: .peopleInputArea
                ),
                storedNewlineCount: &personInputNewlineCount
            )
        }
    }

    private struct SentenceChipTextChange {
        let proxy: ScrollViewProxy
        let isInputFocused: Bool
        let oldValue: String
        let newValue: String
        let scrollTarget: JournalScrollTarget
    }

    private func scheduleChipKeyboardScrollOnTextChange(
        _ change: SentenceChipTextChange,
        storedNewlineCount: inout Int
    ) {
        if change.isInputFocused, keyboardOverlapHeight > 0, change.newValue.count > change.oldValue.count {
            scheduleJournalKeyboardScroll(proxy: change.proxy, reason: .typing(change.scrollTarget))
        }
        let newCount = change.newValue.filter { $0 == "\n" }.count
        if newCount > storedNewlineCount {
            scheduleJournalKeyboardScroll(proxy: change.proxy, reason: .newlineAdded(change.scrollTarget))
        }
        storedNewlineCount = newCount
    }

    private var gratitudesSequentialSection: some View {
        SequentialSectionView(
            title: String(localized: "journal.section.gratitudesTitle"),
            addButtonTitle: viewModel.gratitudes.isEmpty
                ? String(localized: "journal.actions.addGratitude")
                : String(localized: "journal.actions.addAnotherGratitude"),
            addButtonAccessibilityHint: String(localized: "accessibility.addAnotherItemHint"),
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .gratitude)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .gratitude)?.message,
            guidanceMessageSecondary: onboardingPresentation.sectionGuidance(for: .gratitude)?
                .messageSecondary,
            items: viewModel.gratitudes,
            placeholder: String(localized: "journal.prompts.gratefulFor"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Gratitude 1",
            entryAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalGratitudeEntry"
                : nil,
            addItemAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalSectionAdd.gratitude"
                : nil,
            onboardingState: onboardingPresentation.state(for: .gratitude),
            isTransitioning: isGratitudeTransitioning,
            inputText: $gratitudeInput,
            editingIndex: editingGratitudeIndex,
            inputFocus: $isGratitudeInputFocused,
            onSubmit: submitGratitude,
            onItemTap: { index in chipTapped(section: .gratitude, index: index) },
            onMoveItem: { from, toOffset in moveChip(section: .gratitude, from: from, toOffset: toOffset) },
            onDeleteItem: { index in deleteChip(section: .gratitude, index: index) },
            onAddNew: { addNewTapped(section: .gratitude) },
            isAddMorphComposerVisible: $isGratitudeAddMorphComposerVisible,
            ambientInlineEditingActive: isAnyInlineChipEditing,
            sectionHostsInlineFocus: editingGratitudeIndex != nil || isGratitudeAddMorphComposerVisible,
            onRequestDismissInlineEditing: { dismissInlineChipEditingSession() },
            keyboardScrollAnchorID: .gratitudeSection
        )
    }

    private var needsSequentialSection: some View {
        SequentialSectionView(
            title: String(localized: "journal.section.needsTitle"),
            addButtonTitle: viewModel.needs.isEmpty
                ? String(localized: "journal.actions.addNeed")
                : String(localized: "journal.actions.addAnotherNeed"),
            addButtonAccessibilityHint: String(localized: "accessibility.addAnotherItemHint"),
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .need)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .need)?.message,
            items: viewModel.needs,
            placeholder: String(localized: "journal.prompts.whatNeedToday"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Need 1",
            entryAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalNeedEntry"
                : nil,
            addItemAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalSectionAdd.need"
                : nil,
            onboardingState: onboardingPresentation.state(for: .need),
            isTransitioning: isNeedTransitioning,
            inputText: $needInput,
            editingIndex: editingNeedIndex,
            inputFocus: $isNeedInputFocused,
            onSubmit: submitNeed,
            onItemTap: { index in chipTapped(section: .need, index: index) },
            onMoveItem: { from, toOffset in moveChip(section: .need, from: from, toOffset: toOffset) },
            onDeleteItem: { index in deleteChip(section: .need, index: index) },
            onAddNew: { addNewTapped(section: .need) },
            isAddMorphComposerVisible: $isNeedAddMorphComposerVisible,
            ambientInlineEditingActive: isAnyInlineChipEditing,
            sectionHostsInlineFocus: editingNeedIndex != nil || isNeedAddMorphComposerVisible,
            onRequestDismissInlineEditing: { dismissInlineChipEditingSession() },
            keyboardScrollAnchorID: .needInputArea
        )
    }

    private var peopleSequentialSection: some View {
        SequentialSectionView(
            title: String(localized: "journal.section.peopleTitle"),
            addButtonTitle: viewModel.people.isEmpty
                ? String(localized: "journal.actions.addPerson")
                : String(localized: "journal.actions.addAnotherPerson"),
            addButtonAccessibilityHint: String(localized: "accessibility.addAnotherItemHint"),
            showsTrailingChevronOnAddRow: false,
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .person)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .person)?.message,
            items: viewModel.people,
            placeholder: String(localized: "journal.prompts.whoThinking"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Person 1",
            entryAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalPersonEntry"
                : nil,
            addItemAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalSectionAdd.person"
                : nil,
            onboardingState: onboardingPresentation.state(for: .person),
            isTransitioning: isPersonTransitioning,
            inputText: $personInput,
            editingIndex: editingPersonIndex,
            inputFocus: $isPersonInputFocused,
            onSubmit: submitPerson,
            onItemTap: { index in chipTapped(section: .person, index: index) },
            onMoveItem: { from, toOffset in moveChip(section: .person, from: from, toOffset: toOffset) },
            onDeleteItem: { index in deleteChip(section: .person, index: index) },
            onAddNew: { addNewTapped(section: .person) },
            isAddMorphComposerVisible: $isPersonAddMorphComposerVisible,
            ambientInlineEditingActive: isAnyInlineChipEditing,
            sectionHostsInlineFocus: editingPersonIndex != nil || isPersonAddMorphComposerVisible,
            onRequestDismissInlineEditing: { dismissInlineChipEditingSession() },
            keyboardScrollAnchorID: .peopleInputArea
        )
    }

    func journalNotesSections(proxy: ScrollViewProxy) -> some View {
        journalNotesSectionsStack(proxy: proxy)
            .onChange(of: viewModel.readingNotes) { oldValue, newValue in
            // Outer scroll keeps the notes field above the keyboard; bounded `TextEditor` height keeps the
            // section from growing without limit (avoids pinning the caret off the top of the screen).
            if isReadingNotesFocused,
               keyboardOverlapHeight > 0,
               newValue.count > oldValue.count {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .typing(.readingNotes)
                )
            }
            }
            .onChange(of: viewModel.reflections) { oldValue, newValue in
            if isReflectionsFocused,
               keyboardOverlapHeight > 0,
               newValue.count > oldValue.count {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .typing(.reflections)
                )
            }
            }
    }

    @ViewBuilder
    private func journalNotesSectionsStack(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.todayNotesSpacing) {
            EditableTextSection(
                title: String(localized: "journal.section.readingNotesTitle"),
                guidanceTitle: onboardingPresentation.sectionGuidance(for: .readingNotes)?.title,
                guidanceMessage: onboardingPresentation.sectionGuidance(for: .readingNotes)?.message,
                guidanceMessageSecondary: onboardingPresentation.sectionGuidance(for: .readingNotes)?
                    .messageSecondary,
                text: Binding(
                    get: { viewModel.readingNotes },
                    set: { viewModel.updateReadingNotes($0) }
                ),
                onboardingState: onboardingPresentation.state(for: .readingNotes),
                inputFocus: $isReadingNotesFocused,
                keyboardScrollAnchorID: .readingNotes,
                onMultilineLineAdded: {
                    scheduleJournalKeyboardScroll(
                        proxy: proxy,
                        reason: .newlineAdded(.readingNotes)
                    )
                }
            )
            EditableTextSection(
                title: String(localized: "journal.section.reflectionsTitle"),
                text: Binding(
                    get: { viewModel.reflections },
                    set: { viewModel.updateReflections($0) }
                ),
                onboardingState: onboardingPresentation.state(for: .reflections),
                inputFocus: $isReflectionsFocused,
                keyboardScrollAnchorID: .reflections,
                onMultilineLineAdded: {
                    scheduleJournalKeyboardScroll(
                        proxy: proxy,
                        reason: .newlineAdded(.reflections)
                    )
                }
            )
        }
        .padding(.top, AppTheme.spacingTight)
    }

    private func scheduleJournalKeyboardScroll(
        proxy: ScrollViewProxy,
        reason: JournalKeyboardScrollReason
    ) {
        let resolvedTarget = reason.explicitTarget ?? currentJournalScrollTarget()
        guard keyboardOverlapHeight > 0 else { return }
        guard let scrollTarget = resolvedTarget else { return }
        JournalKeyboardScrollCoordinator.scheduleScrollAdjust(
            request: JournalKeyboardScrollRequest(
                proxy: proxy,
                reason: reason,
                scrollTarget: scrollTarget,
                keyboardOverlapHeight: keyboardOverlapHeight,
                reduceMotion: reduceMotion,
                showAppTour: showAppTour
            ),
            existingTask: &journalKeyboardScrollTask
        )
    }

    private func currentJournalScrollTarget() -> JournalScrollTarget? {
        if isGratitudeInputFocused || isNeedInputFocused || isPersonInputFocused {
            if isGratitudeInputFocused { return .gratitudeSection }
            if isNeedInputFocused { return .needInputArea }
            if isPersonInputFocused { return .peopleInputArea }
            return .sentenceSections
        }
        if isReadingNotesFocused { return .readingNotes }
        if isReflectionsFocused { return .reflections }
        return nil
    }

    var journalToastOverlay: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: AppTheme.spacingTight) {
                if showSavedToPhotosToast {
                    SavedToPhotosToastView()
                }
            }
            .padding(.bottom, AppTheme.spacingSection)
        }
    }

    func dismissAllJournalFocusIfAppTourPresented(_ isPresented: Bool) {
        guard isPresented else { return }
        clearJournalFocusAndResignFirstResponder()
    }

    func scheduleSavedToPhotosToast() {
        savedToPhotosDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showSavedToPhotosToast = true
        }
        savedToPhotosDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 0.2)) {
                showSavedToPhotosToast = false
            }
        }
    }

    func handleJournalProgressChange() {
        if !hasInitializedCompletionTracking {
            initializeJournalCompletionTracking()
            return
        }
        processJournalProgressUpdate()
    }

    private func initializeJournalCompletionTracking() {
        previousCompletionLevel = viewModel.completionLevel
        previousGratitudesCount = viewModel.gratitudes.count
        previousNeedsCount = viewModel.needs.count
        previousPeopleCount = viewModel.people.count
        hasInitializedCompletionTracking = true
        syncGuidedJournalCompletionIfNeeded()
        evaluateAppTourIfNeeded()
    }

    private func processJournalProgressUpdate() {
        let newLevel = viewModel.completionLevel
        let newGratitudesCount = viewModel.gratitudes.count
        let newNeedsCount = viewModel.needs.count
        let newPeopleCount = viewModel.people.count

        let prevLevel = previousCompletionLevel
        let prevGratitudesCount = previousGratitudesCount
        let prevNeedsCount = previousNeedsCount
        let prevPeopleCount = previousPeopleCount

        let newRank = newLevel.tutorialCompletionRank
        let prevRank = prevLevel.tutorialCompletionRank

        let milestoneOutcome = JournalTutorialUnlockEvaluator.milestoneOutcome(
            JournalTutorialUnlockEvaluator.MilestoneEvaluationInput(
                previousLevel: prevLevel,
                newLevel: newLevel,
                previousGratitudes: prevGratitudesCount,
                previousNeeds: prevNeedsCount,
                previousPeople: prevPeopleCount,
                newGratitudes: newGratitudesCount,
                newNeeds: newNeedsCount,
                newPeople: newPeopleCount,
                hasCelebratedFirstTripleOne: tutorialProgress.hasCelebratedFirstTripleOne,
                hasCelebratedFirstLeaf: tutorialProgress.hasCelebratedFirstLeaf,
                hasCelebratedFirstBloom: tutorialProgress.hasCelebratedFirstBloom
            )
        )

        defer {
            previousCompletionLevel = newLevel
            previousGratitudesCount = newGratitudesCount
            previousNeedsCount = newNeedsCount
            previousPeopleCount = newPeopleCount
        }

        if newRank < prevRank {
            dismissUnlockToastAndCelebrationForRankDown()
            syncGuidedAndAppTourOnTodayIfNeeded(for: newLevel)
            return
        }

        let rankUp = newRank > prevRank && newLevel != .soil

        if milestoneOutcome == nil && !rankUp {
            syncGuidedAndAppTourOnTodayIfNeeded(for: newLevel)
            return
        }

        if let milestoneOutcome {
            applyMilestoneUnlockToast(milestoneOutcome, newLevel: newLevel)
        } else if rankUp {
            applyGenericRankUpUnlockToast(newLevel: newLevel)
        }

        syncGuidedAndAppTourOnTodayIfNeeded(for: newLevel)
    }

    private func dismissUnlockToastAndCelebrationForRankDown() {
        statusCelebrationDismissTask?.cancel()
        unlockFeedbackAutoDismissTask?.cancel()
        unlockFeedbackAutoDismissTask = nil
        celebratingLevel = nil
        let dismissingLevel = unlockToastLevel
        let fallbackExit = Animation.easeOut(duration: 0.16)
        let toastExit = reduceMotion
            ? nil
            : dismissingLevel.map { AppTheme.unlockToastExitAnimation(for: $0) } ?? fallbackExit
        withAnimation(toastExit) {
            unlockToastLevel = nil
            unlockToastMilestone = .none
            unlockToastScrollBaseline = nil
        }
    }

    private func syncGuidedAndAppTourOnTodayIfNeeded(for newLevel: JournalCompletionLevel) {
        guard entryDate == nil else { return }
        syncGuidedJournalCompletionIfNeeded()
        evaluateAppTourIfNeeded()
    }

    private func applyMilestoneUnlockToast(
        _ milestoneOutcome: JournalTutorialUnlockEvaluator.MilestoneOutcome,
        newLevel: JournalCompletionLevel
    ) {
        tutorialProgress.applyRecording(from: milestoneOutcome)
        let suppressSproutFeedbackForAppTour = JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
            isTodayEntry: entryDate == nil,
            newLevel: newLevel,
            hasSeenAppTour: hasSeenAppTour,
            milestoneHighlight: milestoneOutcome.milestoneHighlight,
            hasAtLeastOneEntryInEachSection: viewModel.hasAtLeastOneEntryInEachSection
        )
        if !suppressSproutFeedbackForAppTour {
            triggerStatusCelebration(for: newLevel)
            presentUnlockToast(for: newLevel, milestoneHighlight: milestoneOutcome.milestoneHighlight)
        }
    }

    private func applyGenericRankUpUnlockToast(newLevel: JournalCompletionLevel) {
        let suppressSproutFeedbackForAppTour = JournalTodayOrientationPolicy.shouldSuppressSproutUnlockToast(
            isTodayEntry: entryDate == nil,
            newLevel: newLevel,
            hasSeenAppTour: hasSeenAppTour,
            milestoneHighlight: .none,
            hasAtLeastOneEntryInEachSection: viewModel.hasAtLeastOneEntryInEachSection
        )
        if !suppressSproutFeedbackForAppTour {
            triggerStatusCelebration(for: newLevel)
            presentUnlockToast(for: newLevel, milestoneHighlight: .none)
        }
    }

    func runJournalScreenLoadTask() async {
        if !hasTrackedInitialLoad {
            hasTrackedInitialLoad = true
            PerformanceTrace.instant("JournalScreen.firstTaskStarted")
        }
        let loadTrace = PerformanceTrace.begin("JournalScreen.loadTask")
        if let date = entryDate {
            viewModel.loadEntry(for: date, using: modelContext)
        } else {
            viewModel.loadTodayIfNeeded(using: modelContext)
            let hadPending051GuidedBranch = UserDefaults.standard.bool(
                forKey: JournalOnboardingStorageKeys.legacy051GuidedBranchResolution
            )
            JournalOnboardingProgress.resolvePending051GuidedJournalBranch(
                todayCompletionLevel: viewModel.completionLevel,
                using: .standard
            )
            if hadPending051GuidedBranch {
                hasCompletedGuidedJournal = UserDefaults.standard.bool(
                    forKey: JournalOnboardingStorageKeys.completedGuidedJournal
                )
            }
        }
        applyJournalScreenLoadFollowUps()
        hasCompletedInitialJournalLoadTask = true
        PerformanceTrace.end("JournalScreen.loadTask", startedAt: loadTrace)
    }

    private func refreshTodayAfterSessionResumeIfNeeded() {
        guard entryDate == nil else { return }
        guard hasCompletedInitialJournalLoadTask else { return }
        if showShareComposer {
            showShareComposer = false
        }
        viewModel.refreshTodayIfStale(using: modelContext)
        applyJournalScreenLoadFollowUps()
    }

    private func applyJournalScreenLoadFollowUps() {
        previousCompletionLevel = viewModel.completionLevel
        previousGratitudesCount = viewModel.gratitudes.count
        previousNeedsCount = viewModel.needs.count
        previousPeopleCount = viewModel.people.count
        hasInitializedCompletionTracking = true
        syncGuidedJournalCompletionIfNeeded()
        focusOnboardingStepIfNeeded(onboardingPresentation.step)
        evaluateAppTourIfNeeded()
    }

    var onboardingPresentation: JournalOnboardingPresentation {
        JournalOnboardingFlowEvaluator.presentation(
            for: JournalOnboardingContext(
                entryDate: entryDate,
                gratitudesCount: viewModel.gratitudes.count,
                needsCount: viewModel.needs.count,
                peopleCount: viewModel.people.count,
                hasCompletedGuidedJournal: hasCompletedGuidedJournal
            )
        )
    }

    var isAnyJournalFieldFocused: Bool {
        isGratitudeInputFocused ||
            isNeedInputFocused ||
            isPersonInputFocused ||
            isReadingNotesFocused ||
            isReflectionsFocused
    }

    var isMultilineNotesFieldFocused: Bool {
        isReadingNotesFocused || isReflectionsFocused
    }

    var onboardingSuggestionContext: JournalOnboardingSuggestionContext {
        JournalOnboardingSuggestionContext(
            entryDate: entryDate,
            hasCelebratedFirstTripleOne: tutorialProgress.hasCelebratedFirstTripleOne,
            hasCelebratedFirstBloom: tutorialProgress.hasCelebratedFirstBloom,
            dismissedRemindersSuggestion: dismissedRemindersSuggestion,
            openedRemindersSuggestion: openedRemindersSuggestion,
            hasConfiguredReminderTime: hasConfiguredReminderTime,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            dismissedICloudSuggestion: dismissedICloudSuggestion,
            openedICloudSuggestion: openedICloudSuggestion,
            isICloudSyncEnabled: isICloudSyncEnabled,
            isGuidanceActive: onboardingPresentation.isGuidanceActive
        )
    }

    var onboardingSuggestion: JournalOnboardingSuggestion? {
        JournalOnboardingSuggestionEvaluator.currentSuggestion(context: onboardingSuggestionContext)
    }

    var hasConfiguredReminderTime: Bool {
        UserDefaults.standard.object(forKey: ReminderSettings.timeIntervalKey) != nil
    }

    func submitGratitude() {
        submit(section: .gratitude)
    }
    func submitNeed() {
        submit(section: .need)
    }
    func submitPerson() {
        submit(section: .person)
    }
    func shareTapped() {
        showShareComposer = true
    }

    func syncGuidedJournalCompletionIfNeeded() {
        guard entryDate == nil else { return }
        guard viewModel.completedToday else { return }
        guard !hasCompletedGuidedJournal else { return }
        hasCompletedGuidedJournal = true
    }

    /// One-time App Tour on Today when each section has at least one line and the tour has not been seen.
    func evaluateAppTourIfNeeded() {
        guard let outcome = JournalTodayOrientationPolicy.appTourOutcome(
            for: todayOrientationInputs()
        ) else { return }

        appTourSkipsCongratulations = outcome.skipsCongratulationsPage
        showAppTour = true
    }

    func todayOrientationInputs() -> JournalTodayOrientationPolicy.Inputs {
        JournalTodayOrientationPolicy.Inputs(
            isTodayEntry: entryDate == nil,
            isRunningUITests: ProcessInfo.graceNotesIsRunningUITests,
            hasSeenAppTour: hasSeenAppTour,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            hasAtLeastOneEntryInEachSection: viewModel.hasAtLeastOneEntryInEachSection
        )
    }

    func completeAppTour() {
        JournalOnboardingProgress.applyAppTourCompletion(using: .standard)
        showAppTour = false
    }

    func focusOnboardingStepIfNeeded(_ step: JournalOnboardingStep?) {
        guard entryDate == nil else { return }
        guard !hasCompletedGuidedJournal else { return }
        guard !showAppTour else { return }
        guard !isAnyJournalFieldFocused else { return }
        focusOnboardingStepForced(step)
    }

    /// Applies onboarding keyboard focus even when another field still claims focus (e.g. after first-chip submit).
    func focusOnboardingStepForced(_ step: JournalOnboardingStep?) {
        guard entryDate == nil else { return }
        guard !hasCompletedGuidedJournal else { return }
        guard !showAppTour else { return }

        switch step {
        case .gratitude:
            restoreInputFocus($isGratitudeInputFocused)
        case .need:
            restoreInputFocus($isNeedInputFocused)
        case .person:
            restoreInputFocus($isPersonInputFocused)
        case .none:
            break
        }
    }

    func shouldAdvanceGuidedFocusAfterChipSubmit(section: StripSection) -> Bool {
        guard entryDate == nil, !hasCompletedGuidedJournal else { return false }
        switch onboardingPresentation.step {
        case .need where section == .gratitude:
            return viewModel.gratitudes.count == 1
        case .person where section == .need:
            return viewModel.needs.count == 1
        default:
            return false
        }
    }

    func clearChipInputFocus() {
        isGratitudeInputFocused = false
        isNeedInputFocused = false
        isPersonInputFocused = false
    }

    func suggestionTitle(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "review.labels.keepRhythm")
        case .iCloudSync:
            return String(localized: "tutorial.icloud.headlineAlt")
        }
    }

    func suggestionMessage(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "tutorial.reminders.optionalSettingsNote")
        case .iCloudSync:
            return String(localized: "tutorial.icloud.wheneverReady")
        }
    }

    func openSettings(for suggestion: JournalOnboardingSuggestion) {
        let authorized = JournalOnboardingSuggestionEvaluator.currentSuggestion(
            context: onboardingSuggestionContext
        )
        guard authorized == suggestion else { return }
        markSuggestionOpened(suggestion)
        appNavigation.openSettings(target: settingsTarget(for: suggestion))
    }

    func dismissSuggestion(_ suggestion: JournalOnboardingSuggestion) {
        switch suggestion {
        case .reminders:
            dismissedRemindersSuggestion = true
        case .iCloudSync:
            dismissedICloudSuggestion = true
        }
    }

    func markSuggestionOpened(_ suggestion: JournalOnboardingSuggestion) {
        switch suggestion {
        case .reminders:
            openedRemindersSuggestion = true
        case .iCloudSync:
            openedICloudSuggestion = true
        }
    }

    func settingsTarget(for suggestion: JournalOnboardingSuggestion) -> SettingsScrollTarget {
        switch suggestion {
        case .reminders:
            return .reminders
        case .iCloudSync:
            return .dataPrivacy
        }
    }

    enum StripSection {
        case gratitude, need, person
    }
    struct StripSectionAdapter {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let move: (Int, Int) -> Bool
        let remove: (Int) -> Bool
        let operations: EntrySectionOperations

        var entryInteractionContext: JournalEntryInteractionCoordinator.SectionContext {
            JournalEntryInteractionCoordinator.SectionContext(
                input: input,
                editingIndex: editingIndex,
                isTransitioning: isTransitioning,
                inputFocus: inputFocus,
                operations: operations
            )
        }
    }
    func stripSectionAdapter(for section: StripSection) -> StripSectionAdapter {
        switch section {
        case .gratitude:
            return makeGratitudeAdapter()
        case .need:
            return makeNeedAdapter()
        case .person:
            return makePersonAdapter()
        }
    }
    func makeGratitudeAdapter() -> StripSectionAdapter {
        StripSectionAdapter(
            input: $gratitudeInput,
            editingIndex: $editingGratitudeIndex,
            isTransitioning: $isGratitudeTransitioning,
            inputFocus: $isGratitudeInputFocused,
            move: { from, toOffset in viewModel.moveGratitude(from: from, to: toOffset) },
            remove: { index in viewModel.removeGratitude(at: index) },
            operations: EntrySectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateGratitudeImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addGratitudeImmediate,
                remove: { index in viewModel.removeGratitude(at: index) },
                fullText: { index in viewModel.fullTextForGratitude(at: index) },
                count: viewModel.gratitudes.count
            )
        )
    }
    func makeNeedAdapter() -> StripSectionAdapter {
        StripSectionAdapter(
            input: $needInput,
            editingIndex: $editingNeedIndex,
            isTransitioning: $isNeedTransitioning,
            inputFocus: $isNeedInputFocused,
            move: { from, toOffset in viewModel.moveNeed(from: from, to: toOffset) },
            remove: { index in viewModel.removeNeed(at: index) },
            operations: EntrySectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateNeedImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addNeedImmediate,
                remove: { index in viewModel.removeNeed(at: index) },
                fullText: { index in viewModel.fullTextForNeed(at: index) },
                count: viewModel.needs.count
            )
        )
    }
    func makePersonAdapter() -> StripSectionAdapter {
        StripSectionAdapter(
            input: $personInput,
            editingIndex: $editingPersonIndex,
            isTransitioning: $isPersonTransitioning,
            inputFocus: $isPersonInputFocused,
            move: { from, toOffset in viewModel.movePerson(from: from, to: toOffset) },
            remove: { index in viewModel.removePerson(at: index) },
            operations: EntrySectionOperations(
                updateImmediate: { index, text in
                    viewModel.updatePersonImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addPersonImmediate,
                remove: { index in viewModel.removePerson(at: index) },
                fullText: { index in viewModel.fullTextForPerson(at: index) },
                count: viewModel.people.count
            )
        )
    }
    func addNewTapped(section: StripSection) {
        let adapter = stripSectionAdapter(for: section)
        JournalEntryInteractionCoordinator.addNewTapped(
            context: adapter.entryInteractionContext,
            restoreInputFocus: restoreInputFocus
        )
    }

    func deleteChip(section: StripSection, index: Int) {
        let adapter = stripSectionAdapter(for: section)
        JournalScreenEntryHandling.performDelete(
            index: index,
            remove: adapter.remove,
            input: adapter.input,
            editingIndex: adapter.editingIndex
        )
    }

    func moveChip(section: StripSection, from sourceIndex: Int, toOffset destinationOffset: Int) {
        let adapter = stripSectionAdapter(for: section)
        JournalScreenEntryHandling.performMove(
            from: sourceIndex,
            to: destinationOffset,
            move: adapter.move,
            editingIndex: adapter.editingIndex
        )
    }

    func chipTapped(section: StripSection, index: Int) {
        let adapter = stripSectionAdapter(for: section)
        JournalEntryInteractionCoordinator.entryTapped(
            context: adapter.entryInteractionContext,
            tapIndex: index,
            restoreInputFocus: restoreInputFocus
        )
    }

    func submit(section: StripSection, restoreFocusAfterSubmit: Bool = true) {
        let adapter = stripSectionAdapter(for: section)
        let wasEditingExistingItem = adapter.editingIndex.wrappedValue != nil
        let shouldClearAddMorphAfterSubmit =
            adapter.editingIndex.wrappedValue == nil && isAddMorphComposerVisible(for: section)
        let didSubmit = JournalScreenEntryHandling.submitEntrySection(
            editingIndex: adapter.editingIndex,
            input: adapter.input,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        guard didSubmit else { return }
        if shouldClearAddMorphAfterSubmit {
            clearAddMorphComposer(for: section)
        }
        if shouldAdvanceGuidedFocusAfterChipSubmit(section: section) {
            clearChipInputFocus()
            Task { @MainActor in
                await Task.yield()
                focusOnboardingStepForced(onboardingPresentation.step)
            }
        } else if wasEditingExistingItem {
            clearChipInputFocus()
        } else if restoreFocusAfterSubmit {
            restoreInputFocus(adapter.inputFocus)
        } else {
            clearChipInputFocus()
        }
    }

    private func clearInlineChipEditingState(adapter: StripSectionAdapter) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            adapter.editingIndex.wrappedValue = nil
            adapter.input.wrappedValue = ""
        }
    }

    func commitChipDraftOnInputFocusLost(section: StripSection) {
        let adapter = stripSectionAdapter(for: section)
        // Keep add-button-first composition stable: losing focus from a "new draft" field
        // should not auto-submit and block immediate same-section strip taps.
        guard adapter.editingIndex.wrappedValue != nil else { return }
        if let editingIndex = adapter.editingIndex.wrappedValue,
           let persisted = adapter.operations.fullText(editingIndex) {
            let draft = adapter.input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let persistedTrimmed = persisted.trimmingCharacters(in: .whitespacesAndNewlines)
            if draft == persistedTrimmed {
                clearInlineChipEditingState(adapter: adapter)
                return
            }
        }
        let didSubmit = JournalScreenEntryHandling.submitEntrySection(
            editingIndex: adapter.editingIndex,
            input: adapter.input,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        guard didSubmit else {
            clearInlineChipEditingState(adapter: adapter)
            return
        }
        if shouldAdvanceGuidedFocusAfterChipSubmit(section: section) {
            clearChipInputFocus()
            Task { @MainActor in
                await Task.yield()
                focusOnboardingStepForced(onboardingPresentation.step)
            }
            return
        }
        Task { @MainActor in
            await Task.yield()
            if restoreKeyboardFocusIfAnotherJournalTextFieldIsActive() {
                return
            }
            // TextEditor focus can trail TextField by a frame; one extra yield before giving up.
            await Task.yield()
            _ = restoreKeyboardFocusIfAnotherJournalTextFieldIsActive()
        }
    }

    /// Re-asserts focus on whichever journal text field already has SwiftUI focus (chips, Reading Notes, Reflections).
    /// Single source of truth for the list—add new focused editors here only.
    @discardableResult
    func restoreKeyboardFocusIfAnotherJournalTextFieldIsActive() -> Bool {
        guard !showAppTour else { return false }
        let candidates: [(Bool, FocusState<Bool>.Binding)] = [
            (isGratitudeInputFocused, $isGratitudeInputFocused),
            (isNeedInputFocused, $isNeedInputFocused),
            (isPersonInputFocused, $isPersonInputFocused),
            (isReadingNotesFocused, $isReadingNotesFocused),
            (isReflectionsFocused, $isReflectionsFocused)
        ]
        for (isFocused, binding) in candidates where isFocused {
            restoreInputFocus(binding)
            return true
        }
        return false
    }

    func restoreInputFocus(_ focus: FocusState<Bool>.Binding) {
        guard !showAppTour else { return }
        guard !isClearingFocusAfterScrollDismiss else { return }
        // Apply focus immediately so keyboard spin-up starts without waiting a turn.
        focus.wrappedValue = true

        Task { @MainActor in
            await Task.yield()
            guard !showAppTour else { return }
            guard !isClearingFocusAfterScrollDismiss else { return }
            if !focus.wrappedValue {
                focus.wrappedValue = true
            }
        }
    }

    func presentUnlockToast(
        for level: JournalCompletionLevel,
        milestoneHighlight: JournalUnlockMilestoneHighlight
    ) {
        unlockFeedbackAutoDismissTask?.cancel()
        unlockFeedbackAutoDismissTask = nil

        let entrance = reduceMotion ? nil : AppTheme.unlockToastEntranceAnimation(for: level)
        withAnimation(entrance) {
            unlockToastLevel = level
            unlockToastMilestone = milestoneHighlight
            unlockToastScrollBaseline = journalScrollOffsetY
        }

        let dismissAfter = JournalScreenLayout.unlockFeedbackAutoDismissSeconds
        unlockFeedbackAutoDismissTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(dismissAfter))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            dismissUnlockToastIfNeeded()
        }
    }

    func dismissUnlockToastIfNeeded() {
        guard unlockToastLevel != nil else { return }
        dismissUnlockToast()
    }

    func dismissUnlockToast() {
        unlockFeedbackAutoDismissTask?.cancel()
        unlockFeedbackAutoDismissTask = nil
        guard let level = unlockToastLevel else { return }
        let exit = reduceMotion ? nil : AppTheme.unlockToastExitAnimation(for: level)
        withAnimation(exit) {
            unlockToastLevel = nil
            unlockToastMilestone = .none
            unlockToastScrollBaseline = nil
        }
    }

    var journalScrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: JournalScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(JournalScreenLayout.journalScrollCoordinateSpaceName)).minY
            )
        }
    }

    fileprivate var navigationTitle: String {
        if let date = entryDate {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return String(localized: "shell.tab.today")
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
        case .sprout:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.45 : 0.65)
        case .twig:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.5 : 0.72)
        case .leaf:
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)

            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                medium.impactOccurred(intensity: self.reduceMotion ? 0.6 : 0.85)
            }
        case .bloom:
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
// swiftlint:enable file_length type_body_length

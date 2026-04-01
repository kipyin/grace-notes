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
}

private struct JournalScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
    @Environment(\.journalSummerAtmosphereHosted) private var journalSummerAtmosphereHosted
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var viewModel = JournalViewModel()
    @State private var shareableImage: ShareableImage?
    @State private var showShareError = false
    @State private var showSavedToPhotosToast = false
    @State private var savedToPhotosDismissTask: Task<Void, Never>?
    @State private var hasTrackedInitialLoad = false
    @State private var gratitudeSummarizationTask: Task<Void, Never>?
    @State private var needSummarizationTask: Task<Void, Never>?
    @State private var personSummarizationTask: Task<Void, Never>?
    @State private var statusCelebrationDismissTask: Task<Void, Never>?
    @State private var celebratingLevel: JournalCompletionLevel?
    @State private var hasInitializedCompletionTracking = false
    @State private var previousCompletionLevel: JournalCompletionLevel = .empty
    @State private var previousGratitudesCount = 0
    @State private var previousNeedsCount = 0
    @State private var previousPeopleCount = 0
    @State private var unlockToastLevel: JournalCompletionLevel?
    @State private var unlockToastMilestone: JournalUnlockMilestoneHighlight = .none
    @State private var journalScrollOffsetY: CGFloat = 0
    @State private var unlockToastScrollBaseline: CGFloat?
    /// UIKit keyboard overlap with the key window; drives extra scroll padding and scroll-to-visible.
    @State private var keyboardOverlapHeight: CGFloat = 0
    /// Bottom safe area of the scroll view (tab bar / home indicator; may track keyboard when visible).
    @State private var journalScrollBottomSafeArea: CGFloat = 0
    @State private var journalKeyboardScrollTask: Task<Void, Never>?
    @State private var isClearingFocusAfterScrollDismiss = false
    @State private var tutorialProgress = JournalTutorialProgress()
    @State private var showPostSeedJourney = false
    @State private var postSeedJourneySkipsCongratulations = false
    @AppStorage(JournalOnboardingStorageKeys.completedGuidedJournal) private var hasCompletedGuidedJournal = false
    @AppStorage(JournalOnboardingStorageKeys.hasSeenPostSeedJourney) private var hasSeenPostSeedJourney = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedRemindersSuggestion)
    private var dismissedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedICloudSuggestion)
    private var dismissedICloudSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedRemindersSuggestion)
    private var openedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedICloudSuggestion)
    private var openedICloudSuggestion = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = false
    @AppStorage(JournalTutorialStorageKeys.dismissedSeedGuidance) private var dismissedSeedGuidance = false
    @AppStorage(JournalTutorialStorageKeys.dismissedHarvestGuidance) private var dismissedHarvestGuidance = false
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
    var entryDate: Date?
    var body: some View {
        let palette = TodayJournalPalette.resolve(mode: effectiveTodayAppearance)
        ZStack {
            if effectiveTodayAppearance == .summer, !journalSummerAtmosphereHosted {
                SummerPaperBackgroundView()
            }
            if effectiveTodayAppearance == .summer, !journalSummerAtmosphereHosted {
                SummerLeavesOverlaySeam(reduceMotion: reduceMotion)
            }
            journalScrollContent
        }
        .environment(\.todayJournalPalette, palette)
        .overlay { journalToastOverlay }
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareTapped()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(AppTheme.outfitSemiboldHeadline)
                }
                .accessibilityLabel(String(localized: "Share"))
                .accessibilityIdentifier("Share")
            }
        }
        .toolbarBackground(
            effectiveTodayAppearance == .summer ? .hidden : .automatic,
            for: .navigationBar
        )
        .sheet(item: $shareableImage) { item in
            ShareSheet(
                activityItems: [item.image],
                applicationActivities: [SaveToPhotosActivity(image: item.image)]
            )
        }
        .alert(String(localized: "Unable to share"), isPresented: $showShareError) {
            Button(String(localized: "Dismiss")) {
                showShareError = false
            }
        } message: {
            Text(String(localized: "We couldn't create a share image right now. Please try again."))
        }
        .fullScreenCover(isPresented: $showPostSeedJourney) {
            PostSeedJourneyView(
                onFinish: completePostSeedJourney,
                skipsCongratulationsPage: postSeedJourneySkipsCongratulations
            )
        }
        .onChange(of: showPostSeedJourney) { _, isPresented in
            dismissAllJournalFocusIfPostSeedJourneyPresented(isPresented)
        }
        .onChange(of: isAnyChipInputFocused) { wasFocused, isFocused in
            handleChipInputFocusChange(wasFocused: wasFocused, isFocused: isFocused)
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoSavedToLibrary)) { _ in
            scheduleSavedToPhotosToast()
        }
        .onDisappear {
            gratitudeSummarizationTask?.cancel()
            needSummarizationTask?.cancel()
            personSummarizationTask?.cancel()
            statusCelebrationDismissTask?.cancel()
        }
        .onChange(of: onboardingPresentation.step) { _, newStep in
            focusOnboardingStepIfNeeded(newStep)
        }
        .onChange(of: journalProgressFingerprint) { _, _ in
            handleJournalProgressChange()
        }
        .task {
            await runJournalScreenLoadTask()
        }
    }

    private var journalScrollContent: some View {
        ScrollViewReader { proxy in
            journalScrollView(proxy: proxy)
        }
    }

    @ViewBuilder
    private func journalScrollView(proxy: ScrollViewProxy) -> some View {
        journalScrollViewWithModifiers(
            content: ScrollView {
                journalScrollMainColumn(proxy: proxy)
            },
            proxy: proxy
        )
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
            .onPreferenceChange(JournalScrollOffsetPreferenceKey.self) { offsetY in
                journalScrollOffsetY = offsetY
                if unlockToastLevel != nil, let baseline = unlockToastScrollBaseline {
                    if abs(offsetY - baseline) > JournalScreenLayout.unlockToastScrollDismissThreshold {
                        dismissUnlockToastIfNeeded()
                    }
                }
            }
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
                if oldOverlap > 0, newOverlap == 0, isAnyJournalFieldFocused {
                    clearJournalFocusAfterScrollDismiss()
                }
                guard newOverlap > 0, isAnyJournalFieldFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .keyboardDidChangeFrame)
            }
            .onChange(of: isReadingNotesFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.readingNotes))
            }
            .onChange(of: isReflectionsFocused) { _, isFocused in
                guard isFocused else { return }
                scheduleJournalKeyboardScroll(proxy: proxy, reason: .focusChanged(.reflections))
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
            .scrollDismissesKeyboard(.immediately)
            .scrollContentBackground(.hidden)
            .background(todayPalette.background.ignoresSafeArea(edges: [.top, .bottom]))
    }

    private func handleKeyboardDidChangeFrame(_ notification: Notification) {
        keyboardOverlapHeight = JournalKeyboardOverlapReader.overlapHeight(from: notification)
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
    @ViewBuilder
    func journalScrollMainColumn(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.todaySectionSpacing) {
            Group {
                DateSectionView(
                    completionLevel: viewModel.completionLevel,
                    celebratingLevel: celebratingLevel,
                    gratitudesCount: viewModel.gratitudes.count,
                    needsCount: viewModel.needs.count,
                    peopleCount: viewModel.people.count
                )

                journalTutorialHintIfNeeded
                journalOnboardingSuggestionIfNeeded
            }
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
    }

    var effectiveTodayAppearance: JournalAppearanceMode {
        if entryDate != nil { return .standard }
        return JournalAppearanceMode(rawValue: journalTodayAppearanceRaw) ?? .standard
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

    func dismissEmptyAddMorphOrSubmit(section: ChipSection, restoreFocusAfterSubmit: Bool) {
        let adapter = chipSectionAdapter(for: section)
        let trimmed = adapter.input.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            clearAddMorphComposer(for: section)
            clearChipInputFocus()
        } else {
            submit(section: section, restoreFocusAfterSubmit: restoreFocusAfterSubmit)
        }
    }

    func clearAddMorphComposer(for section: ChipSection) {
        switch section {
        case .gratitude:
            isGratitudeAddMorphComposerVisible = false
        case .need:
            isNeedAddMorphComposerVisible = false
        case .person:
            isPersonAddMorphComposerVisible = false
        }
    }

    func isAddMorphComposerVisible(for section: ChipSection) -> Bool {
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
    var journalTutorialHintIfNeeded: some View {
        if !onboardingPresentation.isGuidanceActive,
           let hintKind = JournalTutorialHintPresentation.hintKind(
            entryDate: entryDate,
            completionLevel: viewModel.completionLevel,
            chipsFilledCount: viewModel.chipsFilledCount,
            dismissedSeedGuidance: dismissedSeedGuidance,
            dismissedHarvestGuidance: dismissedHarvestGuidance
        ) {
            JournalTutorialHintView(kind: hintKind) {
                switch hintKind {
                case .seed:
                    dismissedSeedGuidance = true
                case .harvest:
                    dismissedHarvestGuidance = true
                }
            }
        }
    }

    @ViewBuilder
    var journalOnboardingSuggestionIfNeeded: some View {
        if let onboardingSuggestion {
            JournalOnboardingSuggestionView(
                title: suggestionTitle(for: onboardingSuggestion),
                message: suggestionMessage(for: onboardingSuggestion),
                primaryActionTitle: String(localized: "Open Settings"),
                secondaryActionTitle: String(localized: "Not now"),
                onPrimaryAction: { openSettings(for: onboardingSuggestion) },
                onSecondaryAction: { dismissSuggestion(onboardingSuggestion) }
            )
        }
    }

    func journalSentenceSections(proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.todayClusterSpacing) {
            gratitudesSequentialSection
                .id(JournalScrollTarget.gratitudeSection)
            needsSequentialSection
            peopleSequentialSection
        }
        .padding(.top, AppTheme.spacingTight)
        .onChange(of: gratitudeInput) { oldValue, newValue in
            if isGratitudeInputFocused,
               keyboardOverlapHeight > 0,
               newValue.count > oldValue.count {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .typing(.gratitudeSection)
                )
            }
            let newCount = newValue.filter { $0 == "\n" }.count
            if newCount > gratitudeInputNewlineCount {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .newlineAdded(.gratitudeSection)
                )
            }
            gratitudeInputNewlineCount = newCount
        }
        .onChange(of: needInput) { oldValue, newValue in
            if isNeedInputFocused,
               keyboardOverlapHeight > 0,
               newValue.count > oldValue.count {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .typing(.needInputArea)
                )
            }
            let newCount = newValue.filter { $0 == "\n" }.count
            if newCount > needInputNewlineCount {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .newlineAdded(.needInputArea)
                )
            }
            needInputNewlineCount = newCount
        }
        .onChange(of: personInput) { oldValue, newValue in
            if isPersonInputFocused,
               keyboardOverlapHeight > 0,
               newValue.count > oldValue.count {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .typing(.peopleInputArea)
                )
            }
            let newCount = newValue.filter { $0 == "\n" }.count
            if newCount > personInputNewlineCount {
                scheduleJournalKeyboardScroll(
                    proxy: proxy,
                    reason: .newlineAdded(.peopleInputArea)
                )
            }
            personInputNewlineCount = newCount
        }
    }

    private var gratitudesSequentialSection: some View {
        SequentialSectionView(
            title: String(localized: "Gratitudes"),
            addButtonTitle: viewModel.gratitudes.isEmpty
                ? String(localized: "Add gratitude")
                : String(localized: "Add another gratitude"),
            addButtonAccessibilityHint: String(localized: "Opens a text field so you can add another item."),
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .gratitude)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .gratitude)?.message,
            guidanceMessageSecondary: onboardingPresentation.sectionGuidance(for: .gratitude)?
                .messageSecondary,
            items: viewModel.gratitudes,
            placeholder: String(localized: "What's one thing you're grateful for?"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Gratitude 1",
            stripAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalGratitudeStrip"
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
            onRequestDismissInlineEditing: { dismissInlineChipEditingSession() }
        )
    }

    private var needsSequentialSection: some View {
        SequentialSectionView(
            title: String(localized: "Needs"),
            addButtonTitle: viewModel.needs.isEmpty
                ? String(localized: "Add need")
                : String(localized: "Add another need"),
            addButtonAccessibilityHint: String(localized: "Opens a text field so you can add another item."),
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .need)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .need)?.message,
            items: viewModel.needs,
            placeholder: String(localized: "What do you need today?"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Need 1",
            stripAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalNeedStrip"
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
            title: String(localized: "People in Mind"),
            addButtonTitle: viewModel.people.isEmpty
                ? String(localized: "Add person")
                : String(localized: "Add another person"),
            addButtonAccessibilityHint: String(localized: "Opens a text field so you can add another item."),
            showsTrailingChevronOnAddRow: false,
            guidanceTitle: onboardingPresentation.sectionGuidance(for: .person)?.title,
            guidanceMessage: onboardingPresentation.sectionGuidance(for: .person)?.message,
            items: viewModel.people,
            placeholder: String(localized: "Who are you thinking of today?"),
            slotCount: JournalViewModel.slotCount,
            inputAccessibilityIdentifier: "Person 1",
            stripAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                ? "JournalPersonStrip"
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
                title: String(localized: "Reading Notes"),
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
                onMultilineLineAdded: {
                    scheduleJournalKeyboardScroll(
                        proxy: proxy,
                        reason: .newlineAdded(.readingNotes)
                    )
                }
            )
            .id(JournalScrollTarget.readingNotes)
            EditableTextSection(
                title: String(localized: "Reflections"),
                text: Binding(
                    get: { viewModel.reflections },
                    set: { viewModel.updateReflections($0) }
                ),
                onboardingState: onboardingPresentation.state(for: .reflections),
                inputFocus: $isReflectionsFocused,
                onMultilineLineAdded: {
                    scheduleJournalKeyboardScroll(
                        proxy: proxy,
                        reason: .newlineAdded(.reflections)
                    )
                }
            )
            .id(JournalScrollTarget.reflections)
        }
        .padding(.top, AppTheme.spacingTight)
    }

    private func scheduleJournalKeyboardScroll(
        proxy: ScrollViewProxy,
        reason: JournalKeyboardScrollReason
    ) {
        let resolvedTarget = reason.explicitTarget ?? currentJournalScrollTarget()
        guard keyboardOverlapHeight > 0 else { return }
        let scrollTarget = resolvedTarget
        guard let scrollTarget else { return }
        journalKeyboardScrollTask?.cancel()
        let usesTypingDrivenScroll = reason.usesTypingDrivenScroll
        let animation: Animation? = usesTypingDrivenScroll ? nil : (reduceMotion ? nil : .easeOut(duration: 0.25))
        let anchor: UnitPoint
        switch scrollTarget {
        case .gratitudeSection, .needInputArea, .peopleInputArea:
            // Needs/People scroll targets chip list + input only (not full section), so gratitude-style anchors apply.
            anchor = usesTypingDrivenScroll ? .bottom : .center
        default:
            anchor = .bottom
        }
        journalKeyboardScrollTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            guard !showPostSeedJourney else { return }
            if let animation {
                withAnimation(animation) {
                    proxy.scrollTo(scrollTarget, anchor: anchor)
                }
            } else {
                proxy.scrollTo(scrollTarget, anchor: anchor)
            }
        }
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
                if let toastLevel = unlockToastLevel {
                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            dismissUnlockToastIfNeeded()
                        } label: {
                            JournalUnlockToastView(level: toastLevel, milestoneHighlight: unlockToastMilestone)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(String(localized: "Dismiss"))
                        .transition(unlockToastTransition(for: toastLevel))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppTheme.todayHorizontalPadding)
                }
                if showSavedToPhotosToast {
                    SavedToPhotosToastView()
                }
            }
            .padding(.bottom, AppTheme.spacingSection)
        }
    }

    func dismissAllJournalFocusIfPostSeedJourneyPresented(_ isPresented: Bool) {
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
        evaluatePostSeedJourneyIfNeeded()
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
                hasCelebratedFirstBalanced: tutorialProgress.hasCelebratedFirstBalanced,
                hasCelebratedFirstFull: tutorialProgress.hasCelebratedFirstFull
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
            syncGuidedAndPostSeedOnTodayIfNeeded(for: newLevel)
            return
        }

        let rankUp = newRank > prevRank && newLevel != .empty

        if milestoneOutcome == nil && !rankUp {
            syncGuidedAndPostSeedOnTodayIfNeeded(for: newLevel)
            return
        }

        if let milestoneOutcome {
            applyMilestoneUnlockToast(milestoneOutcome, newLevel: newLevel)
        } else if rankUp {
            applyGenericRankUpUnlockToast(newLevel: newLevel)
        }

        syncGuidedAndPostSeedOnTodayIfNeeded(for: newLevel)
    }

    private func dismissUnlockToastAndCelebrationForRankDown() {
        statusCelebrationDismissTask?.cancel()
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

    private func syncGuidedAndPostSeedOnTodayIfNeeded(for newLevel: JournalCompletionLevel) {
        guard entryDate == nil else { return }
        syncGuidedJournalCompletionIfNeeded()
        evaluatePostSeedJourneyIfNeeded()
    }

    private func applyMilestoneUnlockToast(
        _ milestoneOutcome: JournalTutorialUnlockEvaluator.MilestoneOutcome,
        newLevel: JournalCompletionLevel
    ) {
        tutorialProgress.applyRecording(from: milestoneOutcome)
        triggerStatusCelebration(for: newLevel)
        let suppress = JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
            isTodayEntry: entryDate == nil,
            newLevel: newLevel,
            hasSeenPostSeedJourney: hasSeenPostSeedJourney,
            milestoneHighlight: milestoneOutcome.milestoneHighlight,
            hasAtLeastOneInEachChipSection: viewModel.hasAtLeastOneInEachChipSection
        )
        if !suppress {
            presentUnlockToast(for: newLevel, milestoneHighlight: milestoneOutcome.milestoneHighlight)
        }
    }

    private func applyGenericRankUpUnlockToast(newLevel: JournalCompletionLevel) {
        triggerStatusCelebration(for: newLevel)
        let suppress = JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
            isTodayEntry: entryDate == nil,
            newLevel: newLevel,
            hasSeenPostSeedJourney: hasSeenPostSeedJourney,
            milestoneHighlight: .none,
            hasAtLeastOneInEachChipSection: viewModel.hasAtLeastOneInEachChipSection
        )
        if !suppress {
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
        previousCompletionLevel = viewModel.completionLevel
        previousGratitudesCount = viewModel.gratitudes.count
        previousNeedsCount = viewModel.needs.count
        previousPeopleCount = viewModel.people.count
        hasInitializedCompletionTracking = true
        syncGuidedJournalCompletionIfNeeded()
        focusOnboardingStepIfNeeded(onboardingPresentation.step)
        evaluatePostSeedJourneyIfNeeded()
        PerformanceTrace.end("JournalScreen.loadTask", startedAt: loadTrace)
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
            hasCelebratedFirstFull: tutorialProgress.hasCelebratedFirstFull,
            dismissedRemindersSuggestion: dismissedRemindersSuggestion,
            openedRemindersSuggestion: openedRemindersSuggestion,
            hasConfiguredReminderTime: hasConfiguredReminderTime,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            dismissedICloudSuggestion: dismissedICloudSuggestion,
            openedICloudSuggestion: openedICloudSuggestion,
            isICloudSyncEnabled: isICloudSyncEnabled
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
        let payload = viewModel.exportSnapshot()
        if let image = JournalShareRenderer.renderImage(from: payload) {
            shareableImage = ShareableImage(image: image)
        } else {
            showShareError = true
        }
    }

    func syncGuidedJournalCompletionIfNeeded() {
        guard entryDate == nil else { return }
        guard viewModel.completedToday else { return }
        guard !hasCompletedGuidedJournal else { return }
        hasCompletedGuidedJournal = true
    }

    /// One-time post-Seed journey on Today when each chip section has at least one item and journey C not yet seen.
    func evaluatePostSeedJourneyIfNeeded() {
        guard let outcome = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: todayOrientationInputs()
        ) else { return }

        postSeedJourneySkipsCongratulations = outcome.skipsCongratulationsPage
        showPostSeedJourney = true
    }

    func todayOrientationInputs() -> JournalTodayOrientationPolicy.Inputs {
        JournalTodayOrientationPolicy.Inputs(
            isTodayEntry: entryDate == nil,
            isRunningUITests: ProcessInfo.graceNotesIsRunningUITests,
            hasSeenPostSeedJourney: hasSeenPostSeedJourney,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            hasAtLeastOneInEachChipSection: viewModel.hasAtLeastOneInEachChipSection
        )
    }

    func completePostSeedJourney() {
        JournalOnboardingProgress.applyAppTourCompletion(using: .standard)
        showPostSeedJourney = false
    }

    func focusOnboardingStepIfNeeded(_ step: JournalOnboardingStep?) {
        guard entryDate == nil else { return }
        guard !hasCompletedGuidedJournal else { return }
        guard !showPostSeedJourney else { return }
        guard !isAnyJournalFieldFocused else { return }
        focusOnboardingStepForced(step)
    }

    /// Applies onboarding keyboard focus even when another field still claims focus (e.g. after first-chip submit).
    func focusOnboardingStepForced(_ step: JournalOnboardingStep?) {
        guard entryDate == nil else { return }
        guard !hasCompletedGuidedJournal else { return }
        guard !showPostSeedJourney else { return }

        switch step {
        case .gratitude:
            restoreInputFocus($isGratitudeInputFocused)
        case .need:
            restoreInputFocus($isNeedInputFocused)
        case .person:
            restoreInputFocus($isPersonInputFocused)
        case .ripening:
            focusOnboardingChipStep(.ripening)
        case .harvest:
            focusOnboardingChipStep(.harvest)
        case .none:
            break
        }
    }

    func shouldAdvanceGuidedFocusAfterChipSubmit(section: ChipSection) -> Bool {
        guard entryDate == nil, !hasCompletedGuidedJournal else { return false }
        switch onboardingPresentation.step {
        case .need where section == .gratitude:
            return viewModel.gratitudes.count == 1
        case .person where section == .need:
            return viewModel.needs.count == 1
        case .ripening where section == .person:
            return viewModel.people.count == 1
        default:
            return false
        }
    }

    func clearChipInputFocus() {
        isGratitudeInputFocused = false
        isNeedInputFocused = false
        isPersonInputFocused = false
    }

    func focusOnboardingChipStep(_ step: JournalOnboardingStep) {
        switch step {
        case .ripening:
            focusFirstIncompleteChipSection(targetCount: 3)
        case .harvest:
            focusFirstIncompleteChipSection(targetCount: JournalViewModel.slotCount)
        case .gratitude, .need, .person:
            break
        }
    }

    func focusFirstIncompleteChipSection(targetCount: Int) {
        if viewModel.gratitudes.count < targetCount {
            restoreInputFocus($isGratitudeInputFocused)
            return
        }
        if viewModel.needs.count < targetCount {
            restoreInputFocus($isNeedInputFocused)
            return
        }
        if viewModel.people.count < targetCount {
            restoreInputFocus($isPersonInputFocused)
        }
    }

    func suggestionTitle(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "Keep the rhythm close")
        case .iCloudSync:
            return String(localized: "Keep Grace Notes with you")
        }
    }

    func suggestionMessage(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "If you'd like, you can turn on a daily reminder in Settings.")
        case .iCloudSync:
            return String(localized: "You can turn on iCloud sync in Settings whenever you're ready.")
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

    enum ChipSection {
        case gratitude, need, person
    }
    struct ChipSectionAdapter {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let move: (Int, Int) -> Bool
        let remove: (Int) -> Bool
        let operations: ChipSectionOperations

        var chipInteractionContext: JournalChipInteractionCoordinator.SectionContext {
            JournalChipInteractionCoordinator.SectionContext(
                input: input,
                editingIndex: editingIndex,
                isTransitioning: isTransitioning,
                inputFocus: inputFocus,
                operations: operations
            )
        }
    }
    func chipSectionAdapter(for section: ChipSection) -> ChipSectionAdapter {
        switch section {
        case .gratitude:
            return makeGratitudeAdapter()
        case .need:
            return makeNeedAdapter()
        case .person:
            return makePersonAdapter()
        }
    }
    func makeGratitudeAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $gratitudeInput,
            editingIndex: $editingGratitudeIndex,
            isTransitioning: $isGratitudeTransitioning,
            inputFocus: $isGratitudeInputFocused,
            move: { from, toOffset in viewModel.moveGratitude(from: from, to: toOffset) },
            remove: { index in viewModel.removeGratitude(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateGratitudeImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addGratitudeImmediate,
                remove: { index in viewModel.removeGratitude(at: index) },
                fullText: { index in viewModel.fullTextForGratitude(at: index) },
                count: viewModel.gratitudes.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .gratitude, index: index)
                }
            )
        )
    }
    func makeNeedAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $needInput,
            editingIndex: $editingNeedIndex,
            isTransitioning: $isNeedTransitioning,
            inputFocus: $isNeedInputFocused,
            move: { from, toOffset in viewModel.moveNeed(from: from, to: toOffset) },
            remove: { index in viewModel.removeNeed(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateNeedImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addNeedImmediate,
                remove: { index in viewModel.removeNeed(at: index) },
                fullText: { index in viewModel.fullTextForNeed(at: index) },
                count: viewModel.needs.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .need, index: index)
                }
            )
        )
    }
    func makePersonAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $personInput,
            editingIndex: $editingPersonIndex,
            isTransitioning: $isPersonTransitioning,
            inputFocus: $isPersonInputFocused,
            move: { from, toOffset in viewModel.movePerson(from: from, to: toOffset) },
            remove: { index in viewModel.removePerson(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updatePersonImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addPersonImmediate,
                remove: { index in viewModel.removePerson(at: index) },
                fullText: { index in viewModel.fullTextForPerson(at: index) },
                count: viewModel.people.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .person, index: index)
                }
            )
        )
    }
    func addNewTapped(section: ChipSection) {
        let adapter = chipSectionAdapter(for: section)
        JournalChipInteractionCoordinator.addNewTapped(
            context: adapter.chipInteractionContext,
            restoreInputFocus: restoreInputFocus
        )
    }

    func deleteChip(section: ChipSection, index: Int) {
        let adapter = chipSectionAdapter(for: section)
        JournalScreenChipHandling.performDelete(
            index: index,
            remove: adapter.remove,
            input: adapter.input,
            editingIndex: adapter.editingIndex
        )
    }

    func moveChip(section: ChipSection, from sourceIndex: Int, toOffset destinationOffset: Int) {
        let adapter = chipSectionAdapter(for: section)
        JournalScreenChipHandling.performMove(
            from: sourceIndex,
            to: destinationOffset,
            move: adapter.move,
            editingIndex: adapter.editingIndex
        )
    }

    func chipTapped(section: ChipSection, index: Int) {
        let adapter = chipSectionAdapter(for: section)
        JournalChipInteractionCoordinator.chipTapped(
            context: adapter.chipInteractionContext,
            tapIndex: index,
            restoreInputFocus: restoreInputFocus
        )
    }

    func scheduleSummarization(for section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            gratitudeSummarizationTask?.cancel()
            gratitudeSummarizationTask = Task {
                await viewModel.summarizeAndUpdateChip(section: .gratitude, index: index)
            }
        case .need:
            needSummarizationTask?.cancel()
            needSummarizationTask = Task {
                await viewModel.summarizeAndUpdateChip(section: .need, index: index)
            }
        case .person:
            personSummarizationTask?.cancel()
            personSummarizationTask = Task {
                await viewModel.summarizeAndUpdateChip(section: .person, index: index)
            }
        }
    }

    func submit(section: ChipSection, restoreFocusAfterSubmit: Bool = true) {
        let adapter = chipSectionAdapter(for: section)
        let wasEditingExistingItem = adapter.editingIndex.wrappedValue != nil
        let shouldClearAddMorphAfterSubmit =
            adapter.editingIndex.wrappedValue == nil && isAddMorphComposerVisible(for: section)
        let didSubmit = JournalScreenChipHandling.submitChipSection(
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

    private func clearInlineChipEditingState(adapter: ChipSectionAdapter) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
            adapter.editingIndex.wrappedValue = nil
            adapter.input.wrappedValue = ""
        }
    }

    func commitChipDraftOnInputFocusLost(section: ChipSection) {
        let adapter = chipSectionAdapter(for: section)
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
        let didSubmit = JournalScreenChipHandling.submitChipSection(
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
        guard !showPostSeedJourney else { return false }
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
        guard !showPostSeedJourney else { return }
        guard !isClearingFocusAfterScrollDismiss else { return }
        // Apply focus immediately so keyboard spin-up starts without waiting a turn.
        focus.wrappedValue = true

        Task { @MainActor in
            await Task.yield()
            guard !showPostSeedJourney else { return }
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
        let entrance = reduceMotion ? nil : AppTheme.unlockToastEntranceAnimation(for: level)
        withAnimation(entrance) {
            unlockToastLevel = level
            unlockToastMilestone = milestoneHighlight
            unlockToastScrollBaseline = journalScrollOffsetY
        }
    }

    func dismissUnlockToastIfNeeded() {
        guard unlockToastLevel != nil else { return }
        dismissUnlockToast()
    }

    func dismissUnlockToast() {
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
        return String(localized: "Today")
    }

    func unlockToastTransition(for level: JournalCompletionLevel) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        switch level {
        case .empty:
            return .opacity
        case .started:
            return .move(edge: .bottom).combined(with: .opacity)
        case .growing:
            return .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.97, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            )
        case .balanced:
            return .asymmetric(
                insertion: .move(edge: .bottom)
                    .combined(with: .opacity)
                    .combined(with: .scale(scale: 0.96, anchor: .bottom)),
                removal: .opacity.combined(with: .move(edge: .bottom))
            )
        case .full:
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
        case .empty:
            break
        case .started:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.45 : 0.65)
        case .growing:
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: reduceMotion ? 0.5 : 0.72)
        case .balanced:
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)

            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                medium.impactOccurred(intensity: self.reduceMotion ? 0.6 : 0.85)
            }
        case .full:
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

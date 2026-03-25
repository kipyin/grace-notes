import SwiftUI
import SwiftData
import UIKit

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

private extension View {
    @ViewBuilder
    func journalDismissUnlockToastOnTapOutside(_ isPresented: Bool, dismiss: @escaping () -> Void) -> some View {
        if isPresented {
            self.simultaneousGesture(TapGesture().onEnded { _ in dismiss() })
        } else {
            self
        }
    }
}

// Chip sections and modifiers keep this type large; further extraction would split `body` across files.
// swiftlint:disable type_body_length
struct JournalScreen: View {
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var previousCompletionLevel: JournalCompletionLevel = .soil
    @State private var unlockToastLevel: JournalCompletionLevel?
    @State private var unlockToastMilestone: JournalUnlockMilestoneHighlight = .none
    @State private var journalScrollOffsetY: CGFloat = 0
    @State private var unlockToastScrollBaseline: CGFloat?
    @State private var tutorialProgress = JournalTutorialProgress()
    @State private var showPostSeedJourney = false
    @State private var postSeedJourneySkipsCongratulations = false
    @AppStorage(JournalOnboardingStorageKeys.completedGuidedJournal) private var hasCompletedGuidedJournal = false
    @AppStorage(JournalOnboardingStorageKeys.hasSeenPostSeedJourney) private var hasSeenPostSeedJourney = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedRemindersSuggestion)
    private var dismissedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedAISuggestion)
    private var dismissedAISuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.dismissedICloudSuggestion)
    private var dismissedICloudSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedRemindersSuggestion)
    private var openedRemindersSuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedAISuggestion)
    private var openedAISuggestion = false
    @AppStorage(JournalOnboardingStorageKeys.openedICloudSuggestion)
    private var openedICloudSuggestion = false
    @AppStorage(SummarizerProvider.useCloudUserDefaultsKey) private var useCloudSummarization = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = false
    @AppStorage(JournalTutorialStorageKeys.dismissedSeedGuidance) private var dismissedSeedGuidance = false
    @AppStorage(JournalTutorialStorageKeys.dismissedHarvestGuidance) private var dismissedHarvestGuidance = false

    @State private var gratitudeInput = ""
    @State private var needInput = ""
    @State private var personInput = ""

    @State private var editingGratitudeIndex: Int?
    @State private var editingNeedIndex: Int?
    @State private var editingPersonIndex: Int?
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
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.todaySectionSpacing) {
                DateSectionView(
                    completionLevel: viewModel.completionLevel,
                    celebratingLevel: celebratingLevel
                )

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

                VStack(alignment: .leading, spacing: AppTheme.todayClusterSpacing) {
                    SequentialSectionView(
                        title: String(localized: "Gratitudes"),
                        guidanceTitle: onboardingPresentation.sectionGuidance(for: .gratitude)?.title,
                        guidanceMessage: onboardingPresentation.sectionGuidance(for: .gratitude)?.message,
                        guidanceMessageSecondary: onboardingPresentation.sectionGuidance(for: .gratitude)?
                            .messageSecondary,
                        items: viewModel.gratitudes,
                        placeholder: String(localized: "What's one thing you're grateful for?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Gratitude 1",
                        chipAccessibilityIdentifierPrefix: ProcessInfo.graceNotesIsRunningUITests
                            ? "JournalGratitudeChip"
                            : nil,
                        addChipAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                            ? "JournalSectionAdd.gratitude"
                            : nil,
                        onboardingState: onboardingPresentation.state(for: .gratitude),
                        isTransitioning: isGratitudeTransitioning,
                        inputText: $gratitudeInput,
                        editingIndex: editingGratitudeIndex,
                        inputFocus: $isGratitudeInputFocused,
                        onInputFocusLost: { commitChipDraftOnInputFocusLost(section: .gratitude) },
                        onSubmit: submitGratitude,
                        onChipTap: { index in chipTapped(section: .gratitude, index: index) },
                        onRenameChip: { index, label in renameChip(section: .gratitude, index: index, label: label) },
                        onMoveChip: { from, toOffset in moveChip(section: .gratitude, from: from, toOffset: toOffset) },
                        onDeleteChip: { index in deleteChip(section: .gratitude, index: index) },
                        onAddNew: { addNewTapped(section: .gratitude) }
                    )

                    SequentialSectionView(
                        title: String(localized: "Needs"),
                        guidanceTitle: onboardingPresentation.sectionGuidance(for: .need)?.title,
                        guidanceMessage: onboardingPresentation.sectionGuidance(for: .need)?.message,
                        items: viewModel.needs,
                        placeholder: String(localized: "What do you need today?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Need 1",
                        addChipAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                            ? "JournalSectionAdd.need"
                            : nil,
                        onboardingState: onboardingPresentation.state(for: .need),
                        isTransitioning: isNeedTransitioning,
                        inputText: $needInput,
                        editingIndex: editingNeedIndex,
                        inputFocus: $isNeedInputFocused,
                        onInputFocusLost: { commitChipDraftOnInputFocusLost(section: .need) },
                        onSubmit: submitNeed,
                        onChipTap: { index in chipTapped(section: .need, index: index) },
                        onRenameChip: { index, label in renameChip(section: .need, index: index, label: label) },
                        onMoveChip: { from, toOffset in moveChip(section: .need, from: from, toOffset: toOffset) },
                        onDeleteChip: { index in deleteChip(section: .need, index: index) },
                        onAddNew: { addNewTapped(section: .need) }
                    )

                    SequentialSectionView(
                        title: String(localized: "People in Mind"),
                        guidanceTitle: onboardingPresentation.sectionGuidance(for: .person)?.title,
                        guidanceMessage: onboardingPresentation.sectionGuidance(for: .person)?.message,
                        items: viewModel.people,
                        placeholder: String(localized: "Who are you thinking of today?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Person 1",
                        addChipAccessibilityIdentifier: ProcessInfo.graceNotesIsRunningUITests
                            ? "JournalSectionAdd.person"
                            : nil,
                        onboardingState: onboardingPresentation.state(for: .person),
                        isTransitioning: isPersonTransitioning,
                        inputText: $personInput,
                        editingIndex: editingPersonIndex,
                        inputFocus: $isPersonInputFocused,
                        onInputFocusLost: { commitChipDraftOnInputFocusLost(section: .person) },
                        onSubmit: submitPerson,
                        onChipTap: { index in chipTapped(section: .person, index: index) },
                        onRenameChip: { index, label in renameChip(section: .person, index: index, label: label) },
                        onMoveChip: { from, toOffset in moveChip(section: .person, from: from, toOffset: toOffset) },
                        onDeleteChip: { index in deleteChip(section: .person, index: index) },
                        onAddNew: { addNewTapped(section: .person) }
                    )
                }
                .padding(.top, AppTheme.spacingTight)

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
                        inputFocus: $isReadingNotesFocused
                    )
                    EditableTextSection(
                        title: String(localized: "Reflections"),
                        text: Binding(
                            get: { viewModel.reflections },
                            set: { viewModel.updateReflections($0) }
                        ),
                        onboardingState: onboardingPresentation.state(for: .reflections),
                        inputFocus: $isReflectionsFocused
                    )
                }
                .padding(.top, AppTheme.spacingTight)

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.journalError)
                }
            }
            .padding(.horizontal, AppTheme.todayHorizontalPadding)
            .padding(.top, AppTheme.todayTopPadding)
            .padding(.bottom, AppTheme.todayBottomPadding)
            .background(journalScrollOffsetReader)
            .journalDismissUnlockToastOnTapOutside(unlockToastLevel != nil) {
                dismissUnlockToastIfNeeded()
            }
        }
        .coordinateSpace(name: JournalScreenLayout.journalScrollCoordinateSpaceName)
        .onPreferenceChange(JournalScrollOffsetPreferenceKey.self) { offsetY in
            journalScrollOffsetY = offsetY
            if unlockToastLevel != nil, let baseline = unlockToastScrollBaseline {
                if abs(offsetY - baseline) > JournalScreenLayout.unlockToastScrollDismissThreshold {
                    dismissUnlockToastIfNeeded()
                }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(AppTheme.journalBackground)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareTapped()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(AppTheme.outfitSemiboldHeadline)
                }
                .accessibilityLabel("Share")
                .accessibilityIdentifier("Share")
            }
        }
        .sheet(item: $shareableImage) { item in
            ShareSheet(
                activityItems: [item.image],
                applicationActivities: [SaveToPhotosActivity(image: item.image)]
            )
        }
        .alert("Unable to share", isPresented: $showShareError) {
            Button("Dismiss") {
                showShareError = false
            }
        } message: {
            Text("We couldn't create a share image right now. Please try again.")
        }
        .fullScreenCover(isPresented: $showPostSeedJourney) {
            PostSeedJourneyView(
                onFinish: completePostSeedJourney,
                skipsCongratulationsPage: postSeedJourneySkipsCongratulations
            )
        }
        .onChange(of: showPostSeedJourney) { _, isPresented in
            guard isPresented else { return }
            isGratitudeInputFocused = false
            isNeedInputFocused = false
            isPersonInputFocused = false
            isReadingNotesFocused = false
            isReflectionsFocused = false
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil,
                from: nil,
                for: nil
            )
        }
        .overlay {
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
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection)
        }
        .onReceive(NotificationCenter.default.publisher(for: .photoSavedToLibrary)) { _ in
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
        .onDisappear {
            gratitudeSummarizationTask?.cancel()
            needSummarizationTask?.cancel()
            personSummarizationTask?.cancel()
            statusCelebrationDismissTask?.cancel()
        }
        .onChange(of: onboardingPresentation.step) { _, newStep in
            focusOnboardingStepIfNeeded(newStep)
        }
        .onChange(of: viewModel.completionLevel) { _, newLevel in
            if !hasInitializedCompletionTracking {
                previousCompletionLevel = newLevel
                hasInitializedCompletionTracking = true
                syncGuidedJournalCompletionIfNeeded(for: newLevel)
                evaluatePostSeedJourneyIfNeeded(for: newLevel)
                return
            }

            let previousRank = previousCompletionLevel.tutorialCompletionRank
            let newRank = newLevel.tutorialCompletionRank

            if newRank > previousRank, newLevel != .soil {
                let unlockOutcome = JournalTutorialUnlockEvaluator.outcome(
                    previousRank: previousRank,
                    newRank: newRank,
                    newLevel: newLevel,
                    hasCelebratedFirstSeed: tutorialProgress.hasCelebratedFirstSeed,
                    hasCelebratedFirstHarvest: tutorialProgress.hasCelebratedFirstHarvest
                )
                triggerStatusCelebration(for: newLevel)
                let suppressSeedUnlockToast = JournalTodayOrientationPolicy.shouldSuppressSeedUnlockToast(
                    isTodayEntry: entryDate == nil,
                    newLevel: newLevel,
                    hasSeenPostSeedJourney: hasSeenPostSeedJourney
                )
                if !suppressSeedUnlockToast {
                    presentUnlockToast(for: newLevel, milestoneHighlight: unlockOutcome.milestoneHighlight)
                }
                tutorialProgress.applyRecording(from: unlockOutcome)
            } else if newRank < previousRank {
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

            previousCompletionLevel = newLevel
            syncGuidedJournalCompletionIfNeeded(for: newLevel)
            evaluatePostSeedJourneyIfNeeded(for: newLevel)
        }
        .task {
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
            hasInitializedCompletionTracking = true
            syncGuidedJournalCompletionIfNeeded(for: viewModel.completionLevel)
            focusOnboardingStepIfNeeded(onboardingPresentation.step)
            evaluatePostSeedJourneyIfNeeded(for: viewModel.completionLevel)
            PerformanceTrace.end("JournalScreen.loadTask", startedAt: loadTrace)
        }
    }
}
// swiftlint:enable type_body_length

extension JournalScreen {
    init(entryDate: Date? = nil) {
        self.entryDate = entryDate
    }

    fileprivate var navigationTitle: String {
        if let date = entryDate {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return String(localized: "Today's entry")
    }
}

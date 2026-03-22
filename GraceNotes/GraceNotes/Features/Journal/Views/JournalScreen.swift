// swiftlint:disable file_length
import Combine
import SwiftUI
import SwiftData
import UIKit

// swiftlint:disable type_body_length
struct JournalScreen: View {
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
    @State private var unlockToastDismissTask: Task<Void, Never>?
    @State private var tutorialProgress = JournalTutorialProgress()
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

    init(entryDate: Date? = nil) {
        self.entryDate = entryDate
    }

    private var navigationTitle: String {
        if let date = entryDate {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return String(localized: "Today's entry")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.todaySectionSpacing) {
                DateSectionView(
                    completionLevel: viewModel.completionLevel,
                    celebratingLevel: celebratingLevel
                )

                if let hintKind = JournalTutorialHintPresentation.hintKind(
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

                VStack(alignment: .leading, spacing: AppTheme.todayClusterSpacing) {
                    SequentialSectionView(
                        title: String(localized: "Gratitudes"),
                        items: viewModel.gratitudes,
                        placeholder: String(localized: "What's one thing you're grateful for?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Gratitude 1",
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
                        items: viewModel.needs,
                        placeholder: String(localized: "What do you need today?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Need 1",
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
                        items: viewModel.people,
                        placeholder: String(localized: "Who are you thinking of today?"),
                        slotCount: JournalViewModel.slotCount,
                        inputAccessibilityIdentifier: "Person 1",
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
                        text: Binding(
                            get: { viewModel.readingNotes },
                            set: { viewModel.updateReadingNotes($0) }
                        ),
                        inputFocus: $isReadingNotesFocused
                    )
                    EditableTextSection(
                        title: String(localized: "Reflections"),
                        text: Binding(
                            get: { viewModel.reflections },
                            set: { viewModel.updateReflections($0) }
                        ),
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
        .overlay {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                VStack(spacing: AppTheme.spacingTight) {
                    if let toastLevel = unlockToastLevel {
                        HStack {
                            Spacer(minLength: 0)
                            JournalUnlockToastView(level: toastLevel, milestoneHighlight: unlockToastMilestone)
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
            unlockToastDismissTask?.cancel()
        }
        .onChange(of: viewModel.completionLevel) { _, newLevel in
            if !hasInitializedCompletionTracking {
                previousCompletionLevel = newLevel
                hasInitializedCompletionTracking = true
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
                presentUnlockToast(for: newLevel, milestoneHighlight: unlockOutcome.milestoneHighlight)
                tutorialProgress.applyRecording(from: unlockOutcome)
            } else if newRank < previousRank {
                statusCelebrationDismissTask?.cancel()
                celebratingLevel = nil
                unlockToastDismissTask?.cancel()
                let dismissingLevel = unlockToastLevel
                let fallbackExit = Animation.easeOut(duration: 0.16)
                let toastExit = reduceMotion
                    ? nil
                    : dismissingLevel.map { AppTheme.unlockToastExitAnimation(for: $0) } ?? fallbackExit
                withAnimation(toastExit) {
                    unlockToastLevel = nil
                    unlockToastMilestone = .none
                }
            }

            previousCompletionLevel = newLevel
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
            }
            previousCompletionLevel = viewModel.completionLevel
            hasInitializedCompletionTracking = true
            PerformanceTrace.end("JournalScreen.loadTask", startedAt: loadTrace)
        }
    }
}
// swiftlint:enable type_body_length

private extension JournalScreen {
    private func submitGratitude() {
        submit(section: .gratitude)
    }
    private func submitNeed() {
        submit(section: .need)
    }
    private func submitPerson() {
        submit(section: .person)
    }
    private func shareTapped() {
        let payload = viewModel.exportSnapshot()
        if let image = JournalShareRenderer.renderImage(from: payload) {
            shareableImage = ShareableImage(image: image)
        } else {
            showShareError = true
        }
    }
    private enum ChipSection {
        case gratitude, need, person
    }
    private struct ChipSectionAdapter {
        let input: Binding<String>
        let editingIndex: Binding<Int?>
        let isTransitioning: Binding<Bool>
        let inputFocus: FocusState<Bool>.Binding
        let renameLabel: (Int, String) -> Bool
        let move: (Int, Int) -> Bool
        let remove: (Int) -> Bool
        let operations: ChipSectionOperations
    }
    private func chipSectionAdapter(for section: ChipSection) -> ChipSectionAdapter {
        switch section {
        case .gratitude:
            return makeGratitudeAdapter()
        case .need:
            return makeNeedAdapter()
        case .person:
            return makePersonAdapter()
        }
    }
    private func makeGratitudeAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $gratitudeInput,
            editingIndex: $editingGratitudeIndex,
            isTransitioning: $isGratitudeTransitioning,
            inputFocus: $isGratitudeInputFocused,
            renameLabel: { index, label in viewModel.renameGratitudeLabel(at: index, to: label) },
            move: { from, toOffset in viewModel.moveGratitude(from: from, to: toOffset) },
            remove: { index in viewModel.removeGratitude(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateGratitudeImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addGratitudeImmediate,
                fullText: { index in viewModel.fullTextForGratitude(at: index) },
                count: viewModel.gratitudes.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .gratitude, index: index)
                }
            )
        )
    }
    private func makeNeedAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $needInput,
            editingIndex: $editingNeedIndex,
            isTransitioning: $isNeedTransitioning,
            inputFocus: $isNeedInputFocused,
            renameLabel: { index, label in viewModel.renameNeedLabel(at: index, to: label) },
            move: { from, toOffset in viewModel.moveNeed(from: from, to: toOffset) },
            remove: { index in viewModel.removeNeed(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updateNeedImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addNeedImmediate,
                fullText: { index in viewModel.fullTextForNeed(at: index) },
                count: viewModel.needs.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .need, index: index)
                }
            )
        )
    }
    private func makePersonAdapter() -> ChipSectionAdapter {
        ChipSectionAdapter(
            input: $personInput,
            editingIndex: $editingPersonIndex,
            isTransitioning: $isPersonTransitioning,
            inputFocus: $isPersonInputFocused,
            renameLabel: { index, label in viewModel.renamePersonLabel(at: index, to: label) },
            move: { from, toOffset in viewModel.movePerson(from: from, to: toOffset) },
            remove: { index in viewModel.removePerson(at: index) },
            operations: ChipSectionOperations(
                updateImmediate: { index, text in
                    viewModel.updatePersonImmediate(at: index, fullText: text)
                },
                addImmediate: viewModel.addPersonImmediate,
                fullText: { index in viewModel.fullTextForPerson(at: index) },
                count: viewModel.people.count,
                summarizeAndUpdateChip: { index in
                    scheduleSummarization(for: .person, index: index)
                }
            )
        )
    }
    private func addNewTapped(section: ChipSection) {
        let adapter = chipSectionAdapter(for: section)
        let handled = JournalScreenChipHandling.handleAddChipTap(
            input: adapter.input,
            editingIndex: adapter.editingIndex,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        if handled {
            restoreInputFocus(adapter.inputFocus)
        }
    }

    private func deleteChip(section: ChipSection, index: Int) {
        let adapter = chipSectionAdapter(for: section)
        JournalScreenChipHandling.performDelete(
            index: index,
            remove: adapter.remove,
            input: adapter.input,
            editingIndex: adapter.editingIndex
        )
    }

    private func renameChip(section: ChipSection, index: Int, label: String) {
        let adapter = chipSectionAdapter(for: section)
        _ = adapter.renameLabel(index, label)
    }

    private func moveChip(section: ChipSection, from sourceIndex: Int, toOffset destinationOffset: Int) {
        let adapter = chipSectionAdapter(for: section)
        JournalScreenChipHandling.performMove(
            from: sourceIndex,
            to: destinationOffset,
            move: adapter.move,
            editingIndex: adapter.editingIndex
        )
    }

    private func chipTapped(section: ChipSection, index: Int) {
        let adapter = chipSectionAdapter(for: section)
        let handled = JournalScreenChipHandling.performChipTap(
            tapIndex: index,
            input: adapter.input,
            editingIndex: adapter.editingIndex,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        if handled {
            restoreInputFocus(adapter.inputFocus)
        }
    }

    private func scheduleSummarization(for section: ChipSection, index: Int) {
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

    private func submit(section: ChipSection) {
        let adapter = chipSectionAdapter(for: section)
        let didSubmit = JournalScreenChipHandling.submitChipSection(
            editingIndex: adapter.editingIndex,
            input: adapter.input,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        if didSubmit {
            restoreInputFocus(adapter.inputFocus)
        }
    }

    private func commitChipDraftOnInputFocusLost(section: ChipSection) {
        let adapter = chipSectionAdapter(for: section)
        let didSubmit = JournalScreenChipHandling.submitChipSection(
            editingIndex: adapter.editingIndex,
            input: adapter.input,
            operations: adapter.operations,
            isTransitioning: adapter.isTransitioning
        )
        guard didSubmit else { return }
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
    private func restoreKeyboardFocusIfAnotherJournalTextFieldIsActive() -> Bool {
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

    private func restoreInputFocus(_ focus: FocusState<Bool>.Binding) {
        // Apply focus immediately so keyboard spin-up starts without waiting a turn.
        focus.wrappedValue = true

        Task { @MainActor in
            await Task.yield()
            if !focus.wrappedValue {
                focus.wrappedValue = true
            }
        }
    }

    private func presentUnlockToast(
        for level: JournalCompletionLevel,
        milestoneHighlight: JournalUnlockMilestoneHighlight
    ) {
        unlockToastDismissTask?.cancel()
        let entrance = reduceMotion ? nil : AppTheme.unlockToastEntranceAnimation(for: level)
        withAnimation(entrance) {
            unlockToastLevel = level
            unlockToastMilestone = milestoneHighlight
        }
        let visibleSeconds = unlockToastVisibleSeconds(for: level, milestone: milestoneHighlight)
        unlockToastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(visibleSeconds))
            guard !Task.isCancelled else { return }
            let exit = reduceMotion ? nil : AppTheme.unlockToastExitAnimation(for: level)
            withAnimation(exit) {
                unlockToastLevel = nil
                unlockToastMilestone = .none
            }
        }
    }

    private func unlockToastTransition(for level: JournalCompletionLevel) -> AnyTransition {
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

    private func unlockToastVisibleSeconds(
        for level: JournalCompletionLevel,
        milestone: JournalUnlockMilestoneHighlight
    ) -> Double {
        let base: Double
        switch level {
        case .soil:
            base = 0
        case .seed:
            base = 2.2
        case .ripening:
            base = 2.45
        case .harvest:
            base = 2.75
        case .abundance:
            base = 3.05
        }
        switch milestone {
        case .none:
            return base
        case .firstSeed, .firstFifteenChipHarvest, .firstFifteenChipHarvestWithFullRhythm:
            return base + 0.6
        }
    }

    private func triggerStatusCelebration(for level: JournalCompletionLevel) {
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

    private func triggerStatusHaptics(for level: JournalCompletionLevel) {
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

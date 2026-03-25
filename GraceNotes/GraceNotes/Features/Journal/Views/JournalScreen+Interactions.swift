import Combine
import SwiftUI
import SwiftData
import UIKit

private extension JournalScreen {
    private var onboardingPresentation: JournalOnboardingPresentation {
        JournalOnboardingFlowEvaluator.presentation(
            for: JournalOnboardingContext(
                entryDate: entryDate,
                gratitudesCount: viewModel.gratitudes.count,
                needsCount: viewModel.needs.count,
                peopleCount: viewModel.people.count,
                readingNotes: viewModel.readingNotes,
                reflections: viewModel.reflections,
                hasCompletedGuidedJournal: hasCompletedGuidedJournal
            )
        )
    }

    private var isAnyJournalFieldFocused: Bool {
        isGratitudeInputFocused ||
            isNeedInputFocused ||
            isPersonInputFocused ||
            isReadingNotesFocused ||
            isReflectionsFocused
    }

    private var onboardingSuggestionContext: JournalOnboardingSuggestionContext {
        JournalOnboardingSuggestionContext(
            entryDate: entryDate,
            hasCelebratedFirstSeed: tutorialProgress.hasCelebratedFirstSeed,
            hasCelebratedFirstHarvest: tutorialProgress.hasCelebratedFirstHarvest,
            dismissedRemindersSuggestion: dismissedRemindersSuggestion,
            openedRemindersSuggestion: openedRemindersSuggestion,
            hasConfiguredReminderTime: hasConfiguredReminderTime,
            dismissedAISuggestion: dismissedAISuggestion,
            openedAISuggestion: openedAISuggestion,
            aiFeaturesEnabled: aiFeaturesEnabled,
            isCloudApiKeyConfigured: ApiSecrets.isCloudApiKeyConfigured,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            dismissedICloudSuggestion: dismissedICloudSuggestion,
            openedICloudSuggestion: openedICloudSuggestion,
            isICloudSyncEnabled: isICloudSyncEnabled
        )
    }

    private var onboardingSuggestion: JournalOnboardingSuggestion? {
        JournalOnboardingSuggestionEvaluator.currentSuggestion(context: onboardingSuggestionContext)
    }

    private var aiFeaturesEnabled: Bool {
        useCloudSummarization
    }

    private var hasConfiguredReminderTime: Bool {
        UserDefaults.standard.object(forKey: ReminderSettings.timeIntervalKey) != nil
    }

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

    private func syncGuidedJournalCompletionIfNeeded(for level: JournalCompletionLevel) {
        guard entryDate == nil else { return }
        guard level == .abundance else { return }
        guard !hasCompletedGuidedJournal else { return }
        hasCompletedGuidedJournal = true
    }

    /// One-time post-Seed journey on Today when at or above Seed and journey C not yet seen.
    private func evaluatePostSeedJourneyIfNeeded(for level: JournalCompletionLevel) {
        guard let outcome = JournalTodayOrientationPolicy.postSeedJourneyOutcome(
            for: todayOrientationInputs(completionLevel: level)
        ) else { return }

        postSeedJourneySkipsCongratulations = outcome.skipsCongratulationsPage
        showPostSeedJourney = true
    }

    private func todayOrientationInputs(
        completionLevel: JournalCompletionLevel
    ) -> JournalTodayOrientationPolicy.Inputs {
        JournalTodayOrientationPolicy.Inputs(
            isTodayEntry: entryDate == nil,
            isRunningUITests: ProcessInfo.graceNotesIsRunningUITests,
            hasSeenPostSeedJourney: hasSeenPostSeedJourney,
            hasCompletedGuidedJournal: hasCompletedGuidedJournal,
            completionLevel: completionLevel
        )
    }

    private func completePostSeedJourney() {
        hasSeenPostSeedJourney = true
        hasCompletedGuidedJournal = true
        showPostSeedJourney = false
    }

    private func focusOnboardingStepIfNeeded(_ step: JournalOnboardingStep?) {
        guard entryDate == nil else { return }
        guard !hasCompletedGuidedJournal else { return }
        guard !showPostSeedJourney else { return }
        guard !isAnyJournalFieldFocused else { return }
        focusOnboardingStepForced(step)
    }

    /// Applies onboarding keyboard focus even when another field still claims focus (e.g. after first-chip submit).
    private func focusOnboardingStepForced(_ step: JournalOnboardingStep?) {
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
        case .abundance:
            focusAbundanceInputsIfNeeded()
        case .none:
            break
        }
    }

    private func shouldAdvanceGuidedFocusAfterChipSubmit(section: ChipSection) -> Bool {
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

    private func clearChipInputFocus() {
        isGratitudeInputFocused = false
        isNeedInputFocused = false
        isPersonInputFocused = false
    }

    private func focusOnboardingChipStep(_ step: JournalOnboardingStep) {
        switch step {
        case .ripening:
            focusFirstIncompleteChipSection(targetCount: 3)
        case .harvest:
            focusFirstIncompleteChipSection(targetCount: JournalViewModel.slotCount)
        case .gratitude, .need, .person, .abundance:
            break
        }
    }

    private func focusAbundanceInputsIfNeeded() {
        let notesTrimmed = viewModel.readingNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let reflectionsTrimmed = viewModel.reflections.trimmingCharacters(in: .whitespacesAndNewlines)
        if notesTrimmed.isEmpty {
            restoreInputFocus($isReadingNotesFocused)
        } else if reflectionsTrimmed.isEmpty {
            restoreInputFocus($isReflectionsFocused)
        }
    }

    private func focusFirstIncompleteChipSection(targetCount: Int) {
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

    private func suggestionTitle(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "Keep the rhythm close")
        case .aiFeatures:
            return String(localized: "Make Review more specific")
        case .iCloudSync:
            return String(localized: "Keep Grace Notes with you")
        }
    }

    private func suggestionMessage(for suggestion: JournalOnboardingSuggestion) -> String {
        switch suggestion {
        case .reminders:
            return String(localized: "If you'd like, you can turn on a daily reminder in Settings.")
        case .aiFeatures:
            return String(
                // swiftlint:disable:next line_length
                localized: "AI features can help with short labels and Review insights when you want a little more support."
            )
        case .iCloudSync:
            return String(localized: "You can turn on iCloud sync in Settings whenever you're ready.")
        }
    }

    private func openSettings(for suggestion: JournalOnboardingSuggestion) {
        let authorized = JournalOnboardingSuggestionEvaluator.currentSuggestion(
            context: onboardingSuggestionContext
        )
        guard authorized == suggestion else { return }
        markSuggestionOpened(suggestion)
        appNavigation.openSettings(target: settingsTarget(for: suggestion))
    }

    private func dismissSuggestion(_ suggestion: JournalOnboardingSuggestion) {
        switch suggestion {
        case .reminders:
            dismissedRemindersSuggestion = true
        case .aiFeatures:
            dismissedAISuggestion = true
        case .iCloudSync:
            dismissedICloudSuggestion = true
        }
    }

    private func markSuggestionOpened(_ suggestion: JournalOnboardingSuggestion) {
        switch suggestion {
        case .reminders:
            openedRemindersSuggestion = true
        case .aiFeatures:
            openedAISuggestion = true
        case .iCloudSync:
            openedICloudSuggestion = true
        }
    }

    private func settingsTarget(for suggestion: JournalOnboardingSuggestion) -> SettingsScrollTarget {
        switch suggestion {
        case .reminders:
            return .reminders
        case .aiFeatures:
            return .aiFeatures
        case .iCloudSync:
            return .dataPrivacy
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
        guard didSubmit else { return }
        if shouldAdvanceGuidedFocusAfterChipSubmit(section: section) {
            clearChipInputFocus()
            Task { @MainActor in
                await Task.yield()
                focusOnboardingStepForced(onboardingPresentation.step)
            }
        } else {
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
    private func restoreKeyboardFocusIfAnotherJournalTextFieldIsActive() -> Bool {
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

    private func restoreInputFocus(_ focus: FocusState<Bool>.Binding) {
        guard !showPostSeedJourney else { return }
        // Apply focus immediately so keyboard spin-up starts without waiting a turn.
        focus.wrappedValue = true

        Task { @MainActor in
            await Task.yield()
            guard !showPostSeedJourney else { return }
            if !focus.wrappedValue {
                focus.wrappedValue = true
            }
        }
    }

    private func presentUnlockToast(
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

    private func dismissUnlockToastIfNeeded() {
        guard unlockToastLevel != nil else { return }
        dismissUnlockToast()
    }

    private func dismissUnlockToast() {
        guard let level = unlockToastLevel else { return }
        let exit = reduceMotion ? nil : AppTheme.unlockToastExitAnimation(for: level)
        withAnimation(exit) {
            unlockToastLevel = nil
            unlockToastMilestone = .none
            unlockToastScrollBaseline = nil
        }
    }

    private var journalScrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: JournalScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named(JournalScreenLayout.journalScrollCoordinateSpaceName)).minY
            )
        }
    }

}

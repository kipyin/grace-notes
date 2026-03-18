import Combine
import SwiftUI
import SwiftData
import UIKit

struct JournalScreen: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = JournalViewModel()
    @State private var shareableImage: ShareableImage?
    @State private var showShareError = false
    @State private var showSavedToPhotosToast = false
    @State private var savedToPhotosDismissTask: Task<Void, Never>?
    @State private var hasTrackedInitialLoad = false
    @State private var gratitudeSummarizationTask: Task<Void, Never>?
    @State private var needSummarizationTask: Task<Void, Never>?
    @State private var personSummarizationTask: Task<Void, Never>?

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
            VStack(alignment: .leading, spacing: 24) {
                DateSectionView(
                    entryDate: viewModel.entryDate,
                    completionLevel: viewModel.completionLevel
                )

                SequentialSectionView(
                    title: String(localized: "Gratitudes"),
                    items: viewModel.gratitudes,
                    placeholder: String(localized: "What's one thing you're grateful for?"),
                    slotCount: JournalViewModel.slotCount,
                    inputAccessibilityIdentifier: "Gratitude 1",
                    inputText: $gratitudeInput,
                    editingIndex: editingGratitudeIndex,
                    inputFocus: $isGratitudeInputFocused,
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
                    inputText: $needInput,
                    editingIndex: editingNeedIndex,
                    inputFocus: $isNeedInputFocused,
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
                    inputText: $personInput,
                    editingIndex: editingPersonIndex,
                    inputFocus: $isPersonInputFocused,
                    onSubmit: submitPerson,
                    onChipTap: { index in chipTapped(section: .person, index: index) },
                    onRenameChip: { index, label in renameChip(section: .person, index: index, label: label) },
                    onMoveChip: { from, toOffset in moveChip(section: .person, from: from, toOffset: toOffset) },
                    onDeleteChip: { index in deleteChip(section: .person, index: index) },
                    onAddNew: { addNewTapped(section: .person) }
                )

                EditableTextSection(
                    title: String(localized: "Reading Notes"),
                    text: Binding(
                        get: { viewModel.readingNotes },
                        set: { viewModel.updateReadingNotes($0) }
                    )
                )
                EditableTextSection(
                    title: String(localized: "Reflections"),
                    text: Binding(
                        get: { viewModel.reflections },
                        set: { viewModel.updateReflections($0) }
                    )
                )

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.immediately)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(navigationTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareTapped()
                } label: {
                    Image(systemName: "square.and.arrow.up")
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
            Button("OK") {
                showShareError = false
            }
        } message: {
            Text("Unable to create share image.")
        }
        .overlay {
            if showSavedToPhotosToast {
                VStack {
                    Spacer()
                    SavedToPhotosToastView()
                }
            }
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
            PerformanceTrace.end("JournalScreen.loadTask", startedAt: loadTrace)
        }
    }
}

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
}

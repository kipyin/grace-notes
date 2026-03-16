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

    @State private var gratitudeInput = ""
    @State private var needInput = ""
    @State private var personInput = ""

    @State private var editingGratitudeIndex: Int?
    @State private var editingNeedIndex: Int?
    @State private var editingPersonIndex: Int?

    var entryDate: Date?

    init(entryDate: Date? = nil) {
        self.entryDate = entryDate
    }

    private var navigationTitle: String {
        if let date = entryDate {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
        return String(localized: "Today's 5³")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                DateSectionView(
                    entryDate: viewModel.entryDate,
                    completedToday: viewModel.completedToday
                )

                SequentialSectionView(
                    title: String(localized: "Gratitudes"),
                    items: viewModel.gratitudes,
                    placeholder: String(localized: "What's one thing you're grateful for?"),
                    slotCount: JournalViewModel.slotCount,
                    inputAccessibilityIdentifier: "Gratitude 1",
                    inputText: $gratitudeInput,
                    editingIndex: editingGratitudeIndex,
                    onSubmit: { Task { await submitGratitude() } },
                    onChipTap: { index in chipTapped(section: .gratitude, index: index) },
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
                    onSubmit: { Task { await submitNeed() } },
                    onChipTap: { index in chipTapped(section: .need, index: index) },
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
                    onSubmit: { Task { await submitPerson() } },
                    onChipTap: { index in chipTapped(section: .person, index: index) },
                    onDeleteChip: { index in deleteChip(section: .person, index: index) },
                    onAddNew: { addNewTapped(section: .person) }
                )

                EditableTextSection(
                    title: String(localized: "Reading Notes"),
                    text: Binding(
                        get: { viewModel.bibleNotes },
                        set: { viewModel.updateBibleNotes($0) }
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
        .task {
            if let date = entryDate {
                viewModel.loadEntry(for: date, using: modelContext)
            } else {
                viewModel.loadTodayIfNeeded(using: modelContext)
            }
        }
    }

    private func submitGratitude() async {
        await JournalScreenChipHandling.submitChipSection(
            editingIndex: $editingGratitudeIndex,
            input: $gratitudeInput,
            update: viewModel.updateGratitude,
            add: viewModel.addGratitude
        )
    }

    private func submitNeed() async {
        await JournalScreenChipHandling.submitChipSection(
            editingIndex: $editingNeedIndex,
            input: $needInput,
            update: viewModel.updateNeed,
            add: viewModel.addNeed
        )
    }

    private func submitPerson() async {
        await JournalScreenChipHandling.submitChipSection(
            editingIndex: $editingPersonIndex,
            input: $personInput,
            update: viewModel.updatePerson,
            add: viewModel.addPerson
        )
    }

    private func shareTapped() {
        let payload = viewModel.exportSnapshot()
        if let image = JournalShareRenderer.renderImage(from: payload) {
            shareableImage = ShareableImage(image: image)
        } else {
            showShareError = true
        }
    }
}

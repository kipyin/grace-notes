import Combine
import SwiftUI
import SwiftData
import UIKit

struct JournalScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()
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
                dateSection

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

                bibleNotesSection
                reflectionsSection

                if let saveErrorMessage = viewModel.saveErrorMessage {
                    Text(saveErrorMessage)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(.red)
                }
            }
            .padding()
        }
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
                    savedToPhotosToast
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

    private var savedToPhotosToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.complete)
            Text(String(localized: "Saved to Photos"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.border, lineWidth: 1)
        )
        .padding(.bottom, 32)
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            HStack {
                Text(viewModel.entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                if viewModel.completedToday {
                    Label("Completed for today", systemImage: "checkmark.circle.fill")
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.complete)
                } else {
                    Label("In progress", systemImage: "pencil.circle")
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textMuted)
                }
            }
        }
    }

    private var bibleNotesSection: some View {
        let vm = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            Text("Reading Notes")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            TextEditor(text: Binding(
                get: { vm.bibleNotes },
                set: { vm.updateBibleNotes($0) }
            ))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .warmPaperInputStyle()
        }
    }

    private var reflectionsSection: some View {
        let vm = viewModel
        return VStack(alignment: .leading, spacing: 8) {
            Text("Reflections")
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            TextEditor(text: Binding(
                get: { vm.reflections },
                set: { vm.updateReflections($0) }
            ))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 120)
            .warmPaperInputStyle()
        }
    }

    private func submitGratitude() async {
        let succeeded: Bool
        if let index = editingGratitudeIndex {
            succeeded = await viewModel.updateGratitude(at: index, fullText: gratitudeInput)
            if succeeded { editingGratitudeIndex = nil }
        } else {
            succeeded = await viewModel.addGratitude(gratitudeInput)
        }
        if succeeded { gratitudeInput = "" }
    }

    private func submitNeed() async {
        let succeeded: Bool
        if let index = editingNeedIndex {
            succeeded = await viewModel.updateNeed(at: index, fullText: needInput)
            if succeeded { editingNeedIndex = nil }
        } else {
            succeeded = await viewModel.addNeed(needInput)
        }
        if succeeded { needInput = "" }
    }

    private func submitPerson() async {
        let succeeded: Bool
        if let index = editingPersonIndex {
            succeeded = await viewModel.updatePerson(at: index, fullText: personInput)
            if succeeded { editingPersonIndex = nil }
        } else {
            succeeded = await viewModel.addPerson(personInput)
        }
        if succeeded { personInput = "" }
    }

    private enum ChipSection {
        case gratitude, need, person
    }

    private func addNewTapped(section: ChipSection) {
        switch section {
        case .gratitude:
            editingGratitudeIndex = nil
            gratitudeInput = ""
        case .need:
            editingNeedIndex = nil
            needInput = ""
        case .person:
            editingPersonIndex = nil
            personInput = ""
        }
    }

    private func deleteChip(section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            _ = viewModel.removeGratitude(at: index)
            if editingGratitudeIndex == index {
                editingGratitudeIndex = nil
                gratitudeInput = ""
            } else if let editing = editingGratitudeIndex, editing > index {
                editingGratitudeIndex = editing - 1
            }
        case .need:
            _ = viewModel.removeNeed(at: index)
            if editingNeedIndex == index {
                editingNeedIndex = nil
                needInput = ""
            } else if let editing = editingNeedIndex, editing > index {
                editingNeedIndex = editing - 1
            }
        case .person:
            _ = viewModel.removePerson(at: index)
            if editingPersonIndex == index {
                editingPersonIndex = nil
                personInput = ""
            } else if let editing = editingPersonIndex, editing > index {
                editingPersonIndex = editing - 1
            }
        }
    }

    private func chipTapped(section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            Task {
                var canSwitch = true
                if let currentIndex = editingGratitudeIndex, !gratitudeInput.isEmpty {
                    let succeeded = await viewModel.updateGratitude(at: currentIndex, fullText: gratitudeInput)
                    canSwitch = succeeded
                    if succeeded { gratitudeInput = "" }
                } else if !gratitudeInput.isEmpty, viewModel.gratitudes.count < JournalViewModel.slotCount {
                    let succeeded = await viewModel.addGratitude(gratitudeInput)
                    canSwitch = succeeded
                    if succeeded { gratitudeInput = "" }
                }
                if canSwitch, let fullText = viewModel.fullTextForGratitude(at: index) {
                    gratitudeInput = fullText
                    editingGratitudeIndex = index
                }
            }

        case .need:
            Task {
                var canSwitch = true
                if let currentIndex = editingNeedIndex, !needInput.isEmpty {
                    let succeeded = await viewModel.updateNeed(at: currentIndex, fullText: needInput)
                    canSwitch = succeeded
                    if succeeded { needInput = "" }
                } else if !needInput.isEmpty, viewModel.needs.count < JournalViewModel.slotCount {
                    let succeeded = await viewModel.addNeed(needInput)
                    canSwitch = succeeded
                    if succeeded { needInput = "" }
                }
                if canSwitch, let fullText = viewModel.fullTextForNeed(at: index) {
                    needInput = fullText
                    editingNeedIndex = index
                }
            }

        case .person:
            Task {
                var canSwitch = true
                if let currentIndex = editingPersonIndex, !personInput.isEmpty {
                    let succeeded = await viewModel.updatePerson(at: currentIndex, fullText: personInput)
                    canSwitch = succeeded
                    if succeeded { personInput = "" }
                } else if !personInput.isEmpty, viewModel.people.count < JournalViewModel.slotCount {
                    let succeeded = await viewModel.addPerson(personInput)
                    canSwitch = succeeded
                    if succeeded { personInput = "" }
                }
                if canSwitch, let fullText = viewModel.fullTextForPerson(at: index) {
                    personInput = fullText
                    editingPersonIndex = index
                }
            }
        }
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

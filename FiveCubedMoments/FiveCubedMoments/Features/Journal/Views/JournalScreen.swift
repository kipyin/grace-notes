import SwiftUI
import SwiftData
import UIKit

struct JournalScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var showShareError = false

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
        return "Today's 5³"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dateSection

                SequentialSectionView(
                    title: "Gratitudes",
                    items: viewModel.gratitudes,
                    placeholder: "What's one thing you're grateful for?",
                    slotCount: JournalViewModel.slotCount,
                    inputAccessibilityIdentifier: "Gratitude 1",
                    inputText: $gratitudeInput,
                    editingIndex: editingGratitudeIndex,
                    onSubmit: { submitGratitude() },
                    onChipTap: { index in chipTapped(section: .gratitude, index: index) }
                )

                SequentialSectionView(
                    title: "Needs",
                    items: viewModel.needs,
                    placeholder: "What do you need today?",
                    slotCount: JournalViewModel.slotCount,
                    inputAccessibilityIdentifier: "Need 1",
                    inputText: $needInput,
                    editingIndex: editingNeedIndex,
                    onSubmit: { submitNeed() },
                    onChipTap: { index in chipTapped(section: .need, index: index) }
                )

                SequentialSectionView(
                    title: "People To Pray For",
                    items: viewModel.people,
                    placeholder: "Who would you like to pray for?",
                    slotCount: JournalViewModel.slotCount,
                    inputAccessibilityIdentifier: "Person 1",
                    inputText: $personInput,
                    editingIndex: editingPersonIndex,
                    onSubmit: { submitPerson() },
                    onChipTap: { index in chipTapped(section: .person, index: index) }
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
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        .alert("Unable to share", isPresented: $showShareError) {
            Button("OK") {
                showShareError = false
            }
        } message: {
            Text("Unable to create share image.")
        }
        .task {
            if let date = entryDate {
                viewModel.loadEntry(for: date, using: modelContext)
            } else {
                viewModel.loadTodayIfNeeded(using: modelContext)
            }
        }
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
            Text("Bible Notes")
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

    private func submitGratitude() {
        if let index = editingGratitudeIndex {
            viewModel.updateGratitude(at: index, fullText: gratitudeInput)
            editingGratitudeIndex = nil
        } else {
            viewModel.addGratitude(gratitudeInput)
        }
        gratitudeInput = ""
    }

    private func submitNeed() {
        if let index = editingNeedIndex {
            viewModel.updateNeed(at: index, fullText: needInput)
            editingNeedIndex = nil
        } else {
            viewModel.addNeed(needInput)
        }
        needInput = ""
    }

    private func submitPerson() {
        if let index = editingPersonIndex {
            viewModel.updatePerson(at: index, fullText: personInput)
            editingPersonIndex = nil
        } else {
            viewModel.addPerson(personInput)
        }
        personInput = ""
    }

    private enum ChipSection {
        case gratitude, need, person
    }

    private func chipTapped(section: ChipSection, index: Int) {
        switch section {
        case .gratitude:
            if let currentIndex = editingGratitudeIndex, !gratitudeInput.isEmpty {
                viewModel.updateGratitude(at: currentIndex, fullText: gratitudeInput)
                gratitudeInput = ""
            } else if !gratitudeInput.isEmpty, viewModel.gratitudes.count < JournalViewModel.slotCount {
                viewModel.addGratitude(gratitudeInput)
                gratitudeInput = ""
            }
            if let fullText = viewModel.fullTextForGratitude(at: index) {
                gratitudeInput = fullText
                editingGratitudeIndex = index
            }

        case .need:
            if let currentIndex = editingNeedIndex, !needInput.isEmpty {
                viewModel.updateNeed(at: currentIndex, fullText: needInput)
                needInput = ""
            } else if !needInput.isEmpty, viewModel.needs.count < JournalViewModel.slotCount {
                viewModel.addNeed(needInput)
                needInput = ""
            }
            if let fullText = viewModel.fullTextForNeed(at: index) {
                needInput = fullText
                editingNeedIndex = index
            }

        case .person:
            if let currentIndex = editingPersonIndex, !personInput.isEmpty {
                viewModel.updatePerson(at: currentIndex, fullText: personInput)
                personInput = ""
            } else if !personInput.isEmpty, viewModel.people.count < JournalViewModel.slotCount {
                viewModel.addPerson(personInput)
                personInput = ""
            }
            if let fullText = viewModel.fullTextForPerson(at: index) {
                personInput = fullText
                editingPersonIndex = index
            }
        }
    }

    private func shareTapped() {
        let payload = viewModel.exportSnapshot()
        if let image = JournalShareRenderer.renderImage(from: payload) {
            shareImage = image
            showShareSheet = true
        } else {
            showShareError = true
        }
    }
}

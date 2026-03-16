import SwiftUI
import SwiftData
import UIKit

struct JournalScreen: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = JournalViewModel()
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var showShareError = false

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
        Form {
            Section {
                Text(viewModel.entryDate.formatted(date: .abbreviated, time: .omitted))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
                    .listRowBackground(Color.clear)

                if viewModel.completedToday {
                    Label("Completed for today", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.complete)
                } else {
                    Label("In progress", systemImage: "pencil.circle")
                        .foregroundStyle(AppTheme.textMuted)
                }
            } header: {
                Text("Date")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                ForEach(0..<5, id: \.self) { index in
                    TextField("Gratitude \(index + 1)", text: slotBinding(for: viewModel.gratitudes, index: index) { updated in
                        viewModel.updateGratitudes(updated)
                    })
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .warmPaperInputStyle()
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Gratitudes")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                ForEach(0..<5, id: \.self) { index in
                    TextField("Need \(index + 1)", text: slotBinding(for: viewModel.needs, index: index) { updated in
                        viewModel.updateNeeds(updated)
                    })
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.sentences)
                    .warmPaperInputStyle()
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Needs")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                ForEach(0..<5, id: \.self) { index in
                    TextField("Person \(index + 1)", text: slotBinding(for: viewModel.people, index: index) { updated in
                        viewModel.updatePeople(updated)
                    })
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .textInputAutocapitalization(.words)
                    .warmPaperInputStyle()
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("People To Pray For")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                TextEditor(text: Binding(
                    get: { viewModel.bibleNotes },
                    set: { viewModel.updateBibleNotes($0) }
                ))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .warmPaperInputStyle()
                .listRowBackground(Color.clear)
            } header: {
                Text("Bible Notes")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                TextEditor(text: Binding(
                    get: { viewModel.reflections },
                    set: { viewModel.updateReflections($0) }
                ))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 120)
                .warmPaperInputStyle()
                .listRowBackground(Color.clear)
            } header: {
                Text("Reflections")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            if let saveErrorMessage = viewModel.saveErrorMessage {
                Section {
                    Text(saveErrorMessage)
                        .foregroundStyle(.red)
                }
            }
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

    private func shareTapped() {
        let payload = viewModel.exportSnapshot()
        if let image = JournalShareRenderer.renderImage(from: payload) {
            shareImage = image
            showShareSheet = true
        } else {
            showShareError = true
        }
    }

    private func slotBinding(
        for values: [String],
        index: Int,
        onChange: @escaping ([String]) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                guard index < values.count else { return "" }
                return values[index]
            },
            set: { newValue in
                var updated = values
                while updated.count <= index {
                    updated.append("")
                }
                updated[index] = newValue
                onChange(updated)
            }
        )
    }
}

// Preview
// struct JournalScreen_Previews: PreviewProvider {
//     static var previews: some View {
//         JournalScreen()
//     }
// }

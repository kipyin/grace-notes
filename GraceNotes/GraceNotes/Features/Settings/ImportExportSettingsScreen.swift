import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportExportSettingsScreen: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportFile: ShareableFile?
    @State private var isExportingData = false
    @State private var showImportPicker = false
    @State private var showImportConfirm = false
    @State private var pendingImportURL: URL?
    @State private var isImportingData = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var importSuccessSummary: JournalDataImportSummary?
    @State private var showImportSuccess = false

    private let dataExportService = JournalDataExportService()
    private let dataImportService = JournalDataImportService()

    var body: some View {
        List {
            Section {
                Button {
                    exportJournalData()
                } label: {
                    settingsRow(label: String(localized: "DataPrivacy.importExport.export.json"))
                }
                .buttonStyle(.plain)
                .disabled(isExportingData || isImportingData)
            } header: {
                Text(String(localized: "DataPrivacy.importExport.section.export"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }

            Section {
                Button {
                    showImportPicker = true
                } label: {
                    settingsRow(label: String(localized: "DataPrivacy.importExport.import.json"))
                }
                .buttonStyle(.plain)
                .disabled(isExportingData || isImportingData)
            } header: {
                Text(String(localized: "DataPrivacy.importExport.section.import"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }
        }
        .navigationTitle(String(localized: "DataPrivacy.importExport.title"))
        .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert(String(localized: "Unable to export data"), isPresented: $showExportError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? String(localized: "Please try again."))
        }
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                pendingImportURL = url
                showImportConfirm = true
            case .failure:
                importErrorMessage = String(localized: "DataPrivacy.import.error.readFailed")
                showImportError = true
            }
        }
        .alert(String(localized: "DataPrivacy.import.confirm.title"), isPresented: $showImportConfirm) {
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingImportURL = nil
            }
            Button(String(localized: "DataPrivacy.import.action")) {
                importJournalDataFromPendingURL()
            }
        } message: {
            Text(String(localized: "DataPrivacy.import.confirm.message"))
        }
        .alert(String(localized: "DataPrivacy.import.success.title"), isPresented: $showImportSuccess) {
            Button(String(localized: "OK"), role: .cancel) {
                importSuccessSummary = nil
            }
        } message: {
            if let summary = importSuccessSummary {
                Text(
                    String(
                        format: String(localized: "DataPrivacy.import.success.detail"),
                        summary.insertedCount,
                        summary.updatedCount
                    )
                )
            }
        }
        .alert(String(localized: "DataPrivacy.import.error.title"), isPresented: $showImportError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? String(localized: "DataPrivacy.import.error.generic"))
        }
        .overlay {
            if isExportingData {
                ProgressView(String(localized: "Exporting…"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isImportingData {
                ProgressView(String(localized: "Importing…"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private extension ImportExportSettingsScreen {
    func settingsRow(label: String) -> some View {
        HStack(spacing: AppTheme.spacingRegular) {
            Text(label)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
            Spacer(minLength: AppTheme.spacingRegular)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.settingsTextMuted)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    func exportJournalData() {
        guard !isExportingData else { return }
        isExportingData = true
        let container = modelContext.container
        let exportService = dataExportService

        Task {
            do {
                let fileURL = try await Task.detached(priority: .userInitiated) {
                    let backgroundContext = ModelContext(container)
                    return try exportService.exportArchiveFile(context: backgroundContext)
                }.value
                await MainActor.run {
                    exportFile = ShareableFile(url: fileURL)
                    isExportingData = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = String(localized: "Unable to export your Grace Notes data right now.")
                    showExportError = true
                    isExportingData = false
                }
            }
        }
    }

    func importJournalDataFromPendingURL() {
        guard let url = pendingImportURL else { return }
        pendingImportURL = nil
        guard !isImportingData else { return }
        isImportingData = true
        let container = modelContext.container
        let importService = dataImportService
        let calendar = Calendar.current

        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                // If we can read a byte length without loading the file, reject oversize imports early.
                if let byteCount = JournalDataImportService.resolvedFileByteCount(at: url) {
                    try JournalDataImportService.checkImportPayloadByteCount(byteCount)
                }
                let fileData = try Data(contentsOf: url)
                let summary = try await Task.detached(priority: .userInitiated) {
                    let backgroundContext = ModelContext(container)
                    return try importService.importData(fileData, context: backgroundContext, calendar: calendar)
                }.value
                await MainActor.run {
                    importSuccessSummary = summary
                    showImportSuccess = true
                    isImportingData = false
                }
            } catch {
                await MainActor.run {
                    importErrorMessage = importFailureMessage(for: error)
                    showImportError = true
                    isImportingData = false
                }
            }
        }
    }

    func importFailureMessage(for error: Error) -> String {
        if let importError = error as? JournalDataImportError {
            switch importError {
            case .invalidGraceNotesExport:
                return String(localized: "DataPrivacy.import.error.invalid")
            case .unsupportedSchemaVersion(let version):
                return String(
                    format: String(localized: "DataPrivacy.import.error.schema"),
                    version
                )
            case .fileTooLarge:
                return String(localized: "DataPrivacy.import.error.fileTooLarge")
            case .tooManyEntries:
                return String(localized: "DataPrivacy.import.error.tooManyEntries")
            }
        }
        return String(localized: "DataPrivacy.import.error.generic")
    }
}

private struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

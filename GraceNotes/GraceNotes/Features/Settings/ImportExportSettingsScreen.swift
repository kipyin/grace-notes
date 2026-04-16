import SwiftUI
import SwiftData

// Large settings surface: backup/import flows, sheets, and history.
// Split further cautiously to avoid navigation breakages.
// swiftlint:disable type_body_length file_length
struct ImportExportSettingsScreen: View {
    @Environment(\.modelContext) private var modelContext

    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportFile: ShareableFile?
    @State private var isExportingData = false
    @State private var showManualBackupDestinationDialog = false
    @State private var showImportPicker = false
    @State private var showImportReview = false
    @State private var pendingImportURL: URL?
    @State private var importMode: JournalImportMode = .merge
    @State private var isImportingData = false
    @State private var importErrorMessage: String?
    @State private var showImportError = false
    @State private var importSuccessSummary: JournalDataImportSummary?
    @State private var showImportSuccess = false
    @State private var mergeConflictDays: [Date] = []
    @State private var showMergeConflictResolution = false
    @State private var exportHistory: [BackupExportHistoryEntry] = []
    @State private var scheduledInterval: ScheduledBackupInterval = ScheduledBackupPreferences.interval
    @State private var backupRetention: BackupRetentionPeriod = ScheduledBackupPreferences.backupRetentionPeriod
    @State private var backupSizeCap: BackupFolderSizeCap = ScheduledBackupPreferences.backupFolderSizeCap
    @State private var showScheduledFolderPicker = false
    @State private var scheduledFolderError: String?
    @State private var showScheduledFolderError = false
    @State private var showExportHistorySheet = false
    /// Pushes the backup-file list using the same chevron as other settings rows (not `NavigationLink` disclosure).
    @State private var showBackupFolderFileList = false

    private let dataExportService = JournalDataExportService()
    private let dataImportService = JournalDataImportService()

    @ViewBuilder
    private var scheduledBackupIntervalPicker: some View {
        let title = String(localized: "settings.dataPrivacy.scheduledBackup.interval.title")
        Picker(title, selection: $scheduledInterval) {
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.interval.off"))
                .tag(ScheduledBackupInterval.off)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.interval.daily"))
                .tag(ScheduledBackupInterval.daily)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.interval.weekly"))
                .tag(ScheduledBackupInterval.weekly)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.interval.biweekly"))
                .tag(ScheduledBackupInterval.biweekly)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.interval.monthly"))
                .tag(ScheduledBackupInterval.monthly)
        }
        .font(AppTheme.warmPaperBody)
        .foregroundStyle(AppTheme.settingsTextPrimary)
        .onChange(of: scheduledInterval) { _, newValue in
            ScheduledBackupPreferences.interval = newValue
        }
    }

    @ViewBuilder
    private var scheduledBackupRetentionPicker: some View {
        let title = String(localized: "settings.dataPrivacy.scheduledBackup.retention.title")
        Picker(title, selection: $backupRetention) {
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.retention.days7"))
                .tag(BackupRetentionPeriod.days7)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.retention.days30"))
                .tag(BackupRetentionPeriod.days30)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.retention.days90"))
                .tag(BackupRetentionPeriod.days90)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.retention.days365"))
                .tag(BackupRetentionPeriod.days365)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.retention.forever"))
                .tag(BackupRetentionPeriod.forever)
        }
        .font(AppTheme.warmPaperBody)
        .foregroundStyle(AppTheme.settingsTextPrimary)
        .onChange(of: backupRetention) { _, newValue in
            ScheduledBackupPreferences.backupRetentionPeriod = newValue
        }
    }

    @ViewBuilder
    private var scheduledBackupSizeCapPicker: some View {
        let title = String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.title")
        Picker(title, selection: $backupSizeCap) {
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.mb25"))
                .tag(BackupFolderSizeCap.mb25)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.mb100"))
                .tag(BackupFolderSizeCap.mb100)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.mb500"))
                .tag(BackupFolderSizeCap.mb500)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.gb2"))
                .tag(BackupFolderSizeCap.gb2)
            Text(String(localized: "settings.dataPrivacy.scheduledBackup.sizeCap.unlimited"))
                .tag(BackupFolderSizeCap.unlimited)
        }
        .font(AppTheme.warmPaperBody)
        .foregroundStyle(AppTheme.settingsTextPrimary)
        .onChange(of: backupSizeCap) { _, newValue in
            ScheduledBackupPreferences.backupFolderSizeCap = newValue
        }
    }

    var body: some View {
        ZStack {
            List {
            Section {
                scheduledBackupIntervalPicker

                scheduledBackupRetentionPicker

                scheduledBackupSizeCapPicker

                Button {
                    showScheduledFolderPicker = true
                } label: {
                    settingsRow(
                        title: String(localized: "settings.dataPrivacy.scheduledBackup.chooseFolder"),
                        subtitle: scheduledBackupFolderSubtitle,
                        showTrailingChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chooseBackupFolderAccessibilityLabel())
            } header: {
                Text(String(localized: "settings.dataPrivacy.scheduledBackup.section"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .textCase(nil)
            } footer: {
                VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                    Text(String(localized: "settings.dataPrivacy.scheduledBackup.footer"))
                    Text(String(localized: "settings.dataPrivacy.scheduledBackup.retentionPolicy.footer"))
                }
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Button {
                    if ScheduledBackupPreferences.folderBookmarkData != nil {
                        showManualBackupDestinationDialog = true
                    } else {
                        exportJournalDataShareOnly()
                    }
                } label: {
                    settingsRow(label: String(localized: "settings.dataPrivacy.importExport.export.json"))
                }
                .buttonStyle(.plain)
                .disabled(isExportingData || isImportingData)

                if let latest = exportHistory.first {
                    Button {
                        showExportHistorySheet = true
                    } label: {
                        HStack(alignment: .top, spacing: AppTheme.spacingRegular) {
                            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                                Text(String(localized: "settings.dataPrivacy.importExport.latestExport.title"))
                                    .font(AppTheme.warmPaperMeta)
                                    .foregroundStyle(AppTheme.settingsTextMuted)
                                Text(latest.finishedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(AppTheme.warmPaperBody)
                                    .foregroundStyle(AppTheme.settingsTextPrimary)
                                exportHistoryDetailText(for: latest)
                            }
                            Spacer(minLength: AppTheme.spacingRegular)
                            Image(systemName: "chevron.right")
                                .font(AppTheme.outfitSemiboldCaption)
                                .foregroundStyle(AppTheme.settingsTextMuted)
                                .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(latestExportAccessibilityLabel(for: latest))
                    .accessibilityHint(
                        String(localized: "settings.dataPrivacy.importExport.latestBackup.accessibilityHint")
                    )
                }
            } header: {
                Text(String(localized: "settings.dataPrivacy.importExport.section.export"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .textCase(nil)
            }

            Section {
                Button {
                    showImportPicker = true
                } label: {
                    settingsRow(label: String(localized: "settings.dataPrivacy.importExport.import.json"))
                }
                .buttonStyle(.plain)
                .disabled(isExportingData || isImportingData)

                Group {
                    Button {
                        showBackupFolderFileList = true
                    } label: {
                        settingsRow(
                            label: String(localized: "settings.dataPrivacy.importExport.import.fromBackupFolder"),
                            showTrailingChevron: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .disabled(scheduledFolderMissing)
                .modifier(BackupFolderLinkHint(showDisabledHint: scheduledFolderMissing))
            } header: {
                Text(String(localized: "settings.dataPrivacy.importExport.section.import"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .textCase(nil)
            }
            }
            .navigationTitle(String(localized: "settings.dataPrivacy.importExport.title"))
            .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(AppTheme.settingsBackground)
            .navigationDestination(isPresented: $showBackupFolderFileList) {
                BackupFolderImportFileListView { url in
                    pendingImportURL = url
                    importMode = .merge
                    showBackupFolderFileList = false
                    showImportReview = true
                }
            }

            JSONImportFileImporterAnchor(isPresented: $showImportPicker) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        importErrorMessage = String(localized: "settings.dataPrivacy.import.error.readFailed")
                        showImportError = true
                        return
                    }
                    pendingImportURL = url
                    importMode = .merge
                    showImportReview = true
                case .failure:
                    importErrorMessage = String(localized: "settings.dataPrivacy.import.error.readFailed")
                    showImportError = true
                }
            }

            ScheduledFolderFileImporterAnchor(isPresented: $showScheduledFolderPicker) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        let folderForBookmark = try BackupFolderPickerResolution.resolvedFolderURL(userPicked: url)
                        try ScheduledBackupPreferences.storeFolderBookmark(for: folderForBookmark)
                    } catch {
                        scheduledFolderError = String(localized: "settings.dataPrivacy.scheduledBackup.folderError")
                        showScheduledFolderError = true
                    }
                case .failure:
                    scheduledFolderError = String(localized: "settings.dataPrivacy.scheduledBackup.folderError")
                    showScheduledFolderError = true
                }
            }
        }
        .onAppear {
            refreshHistory()
            scheduledInterval = ScheduledBackupPreferences.interval
            backupRetention = ScheduledBackupPreferences.backupRetentionPeriod
            backupSizeCap = ScheduledBackupPreferences.backupFolderSizeCap
        }
        .sheet(isPresented: $showImportReview) {
            importReviewSheet
        }
        .sheet(isPresented: $showExportHistorySheet) {
            exportHistorySheet
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .alert(String(localized: "data.export.errorTitle"), isPresented: $showExportError) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? String(localized: "common.tryAgainGeneric"))
        }
        .alert(
            String(localized: "settings.dataPrivacy.import.mergeConflict.title"),
            isPresented: $showMergeConflictResolution
        ) {
            Button(String(localized: "settings.dataPrivacy.import.mergeConflict.useBackup")) {
                runConflictResolution(.preferImported)
            }
            Button(String(localized: "settings.dataPrivacy.import.mergeConflict.keepDevice")) {
                runConflictResolution(.preferLocal)
            }
            Button(String(localized: "common.cancel"), role: .cancel) {
                pendingImportURL = nil
                mergeConflictDays = []
                showMergeConflictResolution = false
            }
        } message: {
            Text(mergeConflictAlertMessage(count: mergeConflictDays.count))
        }
        .alert(String(localized: "settings.dataPrivacy.import.success.title"), isPresented: $showImportSuccess) {
            Button(String(localized: "common.ok"), role: .cancel) {
                importSuccessSummary = nil
            }
        } message: {
            if let summary = importSuccessSummary {
                Text(
                    String(
                        format: String(localized: "settings.dataPrivacy.import.success.detail"),
                        summary.insertedCount,
                        summary.updatedCount
                    )
                )
            }
        }
        .alert(String(localized: "settings.dataPrivacy.import.error.title"), isPresented: $showImportError) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? String(localized: "settings.dataPrivacy.import.error.generic"))
        }
        .alert(
            String(localized: "settings.dataPrivacy.scheduledBackup.folderError.title"),
            isPresented: $showScheduledFolderError
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(scheduledFolderError ?? String(localized: "common.tryAgainGeneric"))
        }
        .overlay {
            if isExportingData {
                ProgressView(String(localized: "data.exporting.progress"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if isImportingData {
                ProgressView(String(localized: "data.importing.progress"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .confirmationDialog(
            String(localized: "settings.dataPrivacy.importExport.manualBackupDestination.title"),
            isPresented: $showManualBackupDestinationDialog,
            titleVisibility: .visible
        ) {
            Button(String(localized: "settings.dataPrivacy.importExport.manualBackupDestination.saveToFolder")) {
                exportJournalDataToBackupFolder()
            }
            Button(String(localized: "settings.dataPrivacy.importExport.manualBackupDestination.share")) {
                exportJournalDataShareOnly()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    private var scheduledBackupFolderSubtitle: String? {
        guard ScheduledBackupPreferences.folderBookmarkData != nil,
              let name = ScheduledBackupPreferences.folderDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return nil
        }
        return name
    }

    private func chooseBackupFolderAccessibilityLabel() -> String {
        if let name = scheduledBackupFolderSubtitle {
            return String(
                format: String(localized: "settings.dataPrivacy.scheduledBackup.chooseFolderAccessibilityFormat"),
                name
            )
        }
        return String(localized: "settings.dataPrivacy.scheduledBackup.chooseFolder")
    }

    private var scheduledFolderMissing: Bool {
        ScheduledBackupPreferences.folderBookmarkData == nil
    }

    @ViewBuilder
    private var exportHistorySheet: some View {
        NavigationStack {
            List {
                ForEach(exportHistory) { entry in
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                        Text(entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                        exportHistoryDetailText(for: entry)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(AppTheme.settingsBackground)
            .navigationTitle(String(localized: "settings.dataPrivacy.importExport.section.history"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showExportHistorySheet = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(AppTheme.warmPaperBody.weight(.semibold))
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                    }
                    .accessibilityLabel(String(localized: "common.done"))
                }
            }
        }
    }

    @ViewBuilder
    private var importReviewSheet: some View {
        NavigationStack {
            List {
                Section {
                    Picker(
                        String(localized: "settings.dataPrivacy.import.mode.title"),
                        selection: $importMode
                    ) {
                        Text(String(localized: "settings.dataPrivacy.import.mode.merge"))
                            .tag(JournalImportMode.merge)
                        Text(String(localized: "settings.dataPrivacy.import.mode.replace"))
                            .tag(JournalImportMode.replace)
                    }
                    .font(AppTheme.warmPaperBody)

                    Text(
                        importMode == .merge
                            ? String(localized: "settings.dataPrivacy.import.mode.merge.detail")
                            : String(localized: "settings.dataPrivacy.import.mode.replace.detail")
                    )
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Button(String(localized: "settings.dataPrivacy.import.action")) {
                        performManualImport(conflictResolution: nil)
                    }
                    .font(AppTheme.warmPaperBody)
                    .disabled(pendingImportURL == nil || isImportingData)
                }
            }
            .navigationTitle(String(localized: "settings.dataPrivacy.import.review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        showImportReview = false
                        pendingImportURL = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func refreshHistory() {
        exportHistory = BackupExportHistoryStore.load()
    }

    private func latestExportAccessibilityLabel(for entry: BackupExportHistoryEntry) -> String {
        let when = entry.finishedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(when). \(historyDetailLabel(for: entry))"
    }

    private func exportHistoryDetailText(for entry: BackupExportHistoryEntry) -> Text {
        let parts = ImportExportTechnicalDetailFormatting.exportHistoryLineParts(for: entry)
        let sep = Text(" · ")
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.settingsTextMuted)
        let kindText = Text(parts.kindLabel)
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.settingsTextMuted)
        let statusText = Text(parts.statusLabel)
            .font(AppTheme.warmPaperMeta)
            .foregroundStyle(AppTheme.settingsTextMuted)
        if let detail = parts.detail {
            let detailFont: Font = ImportExportTechnicalDetailFormatting.detailLooksLikeFileName(detail)
                ? AppTheme.settingsTechnicalMeta
                : AppTheme.warmPaperMeta
            let detailText = Text(detail)
                .font(detailFont)
                .foregroundStyle(AppTheme.settingsTextMuted)
            return kindText + sep + statusText + sep + detailText
        }
        return kindText + sep + statusText
    }

    private func historyDetailLabel(for entry: BackupExportHistoryEntry) -> String {
        ImportExportTechnicalDetailFormatting.exportHistoryPlainLabel(for: entry)
    }
}

// swiftlint:enable type_body_length

private extension ImportExportSettingsScreen {
    func settingsRow(label: String, showTrailingChevron: Bool = true) -> some View {
        settingsRow(title: label, subtitle: nil, showTrailingChevron: showTrailingChevron)
    }

    func settingsRow(
        title: String,
        subtitle: String?,
        showTrailingChevron: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: AppTheme.spacingRegular) {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                Text(title)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.settingsTechnicalMeta)
                        .foregroundStyle(AppTheme.settingsTextMuted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showTrailingChevron {
                Image(systemName: "chevron.right")
                    .font(AppTheme.outfitSemiboldCaption)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    func exportJournalDataShareOnly() {
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
                    BackupExportHistoryStore.record(
                        success: true,
                        kind: .manualShare,
                        detail: fileURL.lastPathComponent
                    )
                    refreshHistory()
                    exportFile = ShareableFile(url: fileURL)
                    isExportingData = false
                }
            } catch {
                await MainActor.run {
                    BackupExportHistoryStore.record(
                        success: false,
                        kind: .manualShare,
                        detail: nil
                    )
                    refreshHistory()
                    exportErrorMessage = String(localized: "data.export.errorDetail")
                    showExportError = true
                    isExportingData = false
                }
            }
        }
    }

    func exportJournalDataToBackupFolder() {
        guard !isExportingData else { return }
        isExportingData = true
        let container = modelContext.container
        let exportService = dataExportService
        Task {
            await runBackupFolderExport(container: container, exportService: exportService)
        }
    }

    private func copyExportedArchiveToBackupFolder(fileURL: URL) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            defer {
                try? FileManager.default.removeItem(at: fileURL)
            }
            return try ScheduledBackupPreferences.withFolderSecurityScopedAccess { folderURL in
                try BackupFolderJSONExport.copyTempFile(
                    fileURL,
                    into: folderURL,
                    destinationFileName: fileURL.lastPathComponent,
                    fileManager: .default
                )
            }
        }.value
    }

    private func runBackupFolderExport(
        container: ModelContainer,
        exportService: JournalDataExportService
    ) async {
        do {
            let fileURL = try await Task.detached(priority: .userInitiated) {
                let backgroundContext = ModelContext(container)
                return try exportService.exportArchiveFile(context: backgroundContext)
            }.value
            do {
                let written = try await copyExportedArchiveToBackupFolder(fileURL: fileURL)
                await MainActor.run {
                    BackupExportHistoryStore.record(
                        success: true,
                        kind: .manualFolder,
                        detail: written
                    )
                    refreshHistory()
                    isExportingData = false
                }
            } catch {
                await MainActor.run {
                    BackupExportHistoryStore.record(
                        success: false,
                        kind: .manualFolder,
                        detail: nil
                    )
                    refreshHistory()
                    exportErrorMessage = String(localized: "data.export.errorDetail")
                    showExportError = true
                    isExportingData = false
                }
            }
        } catch {
            await MainActor.run {
                BackupExportHistoryStore.record(
                    success: false,
                    kind: .manualFolder,
                    detail: nil
                )
                refreshHistory()
                exportErrorMessage = String(localized: "data.export.errorDetail")
                showExportError = true
                isExportingData = false
            }
        }
    }

    func performManualImport(conflictResolution: JournalImportMergeConflictResolution?) {
        guard let url = pendingImportURL else { return }
        guard !isImportingData else { return }
        isImportingData = true
        let container = modelContext.container
        Task {
            await runManualImport(from: url, container: container, conflictResolution: conflictResolution)
        }
    }

    @MainActor
    private func runManualImport(
        from url: URL,
        container: ModelContainer,
        conflictResolution: JournalImportMergeConflictResolution?
    ) async {
        let importService = dataImportService
        let mode = importMode
        let calendar = Calendar.current
        do {
            let fileData = try await Task.detached(priority: .userInitiated) {
                try Self.loadManualImportFileData(from: url)
            }.value
            let summary = try await Task.detached(priority: .userInitiated) {
                let backgroundContext = ModelContext(container)
                return try importService.importData(
                    fileData,
                    context: backgroundContext,
                    calendar: calendar,
                    mode: mode,
                    mergeConflictResolution: conflictResolution
                )
            }.value
            showImportReview = false
            pendingImportURL = nil
            importSuccessSummary = summary
            showImportSuccess = true
            isImportingData = false
        } catch let error as JournalDataImportError {
            if case .mergeConflicts(let days) = error {
                mergeConflictDays = days
                showImportReview = false
                showMergeConflictResolution = true
            } else {
                importErrorMessage = importFailureMessage(for: error)
                showImportError = true
                showImportReview = false
                pendingImportURL = nil
            }
            isImportingData = false
        } catch {
            importErrorMessage = importFailureMessage(for: error)
            showImportError = true
            showImportReview = false
            pendingImportURL = nil
            isImportingData = false
        }
    }

    func runConflictResolution(_ resolution: JournalImportMergeConflictResolution) {
        showMergeConflictResolution = false
        performManualImport(conflictResolution: resolution)
    }

    func importFailureMessage(for error: Error) -> String {
        if let importError = error as? JournalDataImportError {
            switch importError {
            case .invalidGraceNotesExport:
                return String(localized: "settings.dataPrivacy.import.error.invalid")
            case .unsupportedSchemaVersion(let version):
                return String(
                    format: String(localized: "settings.dataPrivacy.import.error.schema"),
                    version
                )
            case .fileTooLarge:
                return String(localized: "settings.dataPrivacy.import.error.fileTooLarge")
            case .tooManyEntries:
                return String(localized: "settings.dataPrivacy.import.error.tooManyEntries")
            case .mergeConflicts:
                return String(localized: "settings.dataPrivacy.import.error.generic")
            }
        }
        return String(localized: "settings.dataPrivacy.import.error.generic")
    }

    private static func loadManualImportFileData(from url: URL) throws -> Data {
        if ScheduledBackupPreferences.fileURLIsUnderScheduledBackupFolder(url) {
            return try ScheduledBackupPreferences.withFolderSecurityScopedAccess { _ in
                try readImportFileData(from: url)
            }
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try readImportFileData(from: url)
    }

    private static func readImportFileData(from url: URL) throws -> Data {
        if let byteCount = JournalDataImportService.resolvedFileByteCount(at: url) {
            try JournalDataImportService.checkImportPayloadByteCount(byteCount)
        }
        return try Data(contentsOf: url)
    }

    private func mergeConflictAlertMessage(count: Int) -> String {
        let template = count == 1
            ? String(localized: "settings.dataPrivacy.import.mergeConflict.message.one")
            : String(localized: "settings.dataPrivacy.import.mergeConflict.message.other")
        return String(format: template, locale: .current, count)
    }
}

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = true
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.persistenceRuntimeSnapshot) private var persistenceRuntimeSnapshot

    @StateObject private var reminderState = ReminderSettingsFlowModel()
    @StateObject private var iCloudAccountState = ICloudAccountStatusModel()
    @StateObject private var aiCloudStatus = AISettingsCloudStatusModel()
    @State private var isReminderPickerExpanded = false
    @State private var isReminderToggleOn = false
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
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                    aiConnectionControlRow
                }
                .padding(.vertical, AppTheme.spacingTight / 2)
            } header: {
                Text(String(localized: "AI"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
            } footer: {
                aiSectionFooter
            }

            Section {
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                    Text(String(localized: "Get one local reminder each day to complete today's entry."))
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    reminderTimeControlRow
                    if reminderState.isReminderEnabled && isReminderPickerExpanded {
                        reminderTimePicker
                    }
                    if reminderState.isPermissionDenied {
                        reminderPermissionDeniedGuidance
                    } else if reminderState.liveStatus == .unavailable {
                        reminderUnavailableGuidance
                    }
                }
                .padding(.vertical, AppTheme.spacingTight / 2)
                .alert(
                    String(localized: "Unable to update reminder"),
                    isPresented: reminderErrorIsPresented
                ) {
                    Button(String(localized: "OK"), role: .cancel) {
                        reminderState.clearTransientError()
                    }
                } message: {
                    Text(reminderState.transientErrorMessage ?? String(localized: "Please try again."))
                }
            } header: {
                Text(String(localized: "Reminders"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
            }

            DataPrivacySettingsSection(
                isICloudSyncEnabled: $isICloudSyncEnabled,
                iCloudAccountState: iCloudAccountState,
                persistenceRuntimeSnapshot: persistenceRuntimeSnapshot,
                isExportingData: isExportingData,
                isImportingData: isImportingData,
                onExport: { exportJournalData() },
                onImport: { showImportPicker = true },
                openSystemSettings: { openSystemSettings() }
            )
        }
        .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
        }
        .navigationTitle(String(localized: "Settings"))
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .task {
            await reminderState.refreshStatus()
            syncReminderControlState(with: reminderState.liveStatus)
            iCloudAccountState.refresh()
            syncAICloudStatusModel()
            aiCloudStatus.scheduleThrottledAutoCheckIfNeeded()
        }
        .onDisappear {
            aiCloudStatus.onSettingsDisappear()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
            iCloudAccountState.refresh()
            aiCloudStatus.sceneDidBecomeActive()
            syncAICloudStatusModel()
        }
        .onChange(of: useCloudSummarization) { _, _ in
            syncAICloudStatusModel()
        }
        .onChange(of: useAIReviewInsights) { _, _ in
            syncAICloudStatusModel()
        }
        .onChange(of: reminderState.selectedTime) { _, _ in
            reminderState.handleSelectedTimeChanged()
        }
        .onChange(of: reminderState.liveStatus) { _, newValue in
            syncReminderControlState(with: newValue)
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

private extension SettingsScreen {
    var aiFeaturesOn: Bool {
        useCloudSummarization || useAIReviewInsights
    }

    var canRunAIConnectivityCheck: Bool {
        aiFeaturesOn && ApiSecrets.isCloudApiKeyConfigured
    }

    func syncAICloudStatusModel() {
        aiCloudStatus.refresh(aiFeaturesEnabled: aiFeaturesOn)
    }

    var aiConnectionSubtitle: String? {
        guard aiFeaturesOn else { return nil }
        if let row = aiCloudStatus.statusRow {
            return aiCloudStatusMessage(row)
        }
        if canRunAIConnectivityCheck {
            return String(localized: "Tap for connection status")
        }
        return nil
    }

    var aiConnectionControlRow: some View {
        HStack(spacing: AppTheme.spacingRegular) {
            Button {
                guard canRunAIConnectivityCheck else { return }
                aiCloudStatus.requestManualConnectivityCheck()
            } label: {
                HStack(spacing: AppTheme.spacingRegular) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                        Text(String(localized: "AI features"))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                        if let subtitle = aiConnectionSubtitle {
                            Text(subtitle)
                                .font(AppTheme.warmPaperMeta)
                                .foregroundStyle(AppTheme.settingsTextMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: AppTheme.spacingRegular)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRunAIConnectivityCheck)
            .accessibilityLabel(String(localized: "AI connection status"))
            .accessibilityValue(aiConnectionAccessibilityValue)
            .accessibilityHint(aiConnectionAccessibilityHint)

            Toggle("", isOn: aiFeaturesToggleBinding)
                .labelsHidden()
                .tint(AppTheme.accent)
                .accessibilityLabel(String(localized: "AI features"))
        }
        .frame(minHeight: 44)
    }

    var aiFeaturesToggleBinding: Binding<Bool> {
        Binding(
            get: { aiFeaturesOn },
            set: { enabled in
                useCloudSummarization = enabled
                useAIReviewInsights = enabled
                syncAICloudStatusModel()
            }
        )
    }

    @ViewBuilder
    var aiSectionFooter: some View {
        Text(
            String(
                localized: """
                On: cloud summarization and AI review insights are enabled. \
                Off: labels and review insights stay on-device.
                """
            )
        )
        .font(AppTheme.warmPaperBody)
        .foregroundStyle(AppTheme.settingsTextMuted)
    }

    var aiConnectionAccessibilityValue: String {
        guard aiFeaturesOn else {
            return String(localized: "Off")
        }
        return aiConnectionSubtitle ?? ""
    }

    var aiConnectionAccessibilityHint: String {
        if canRunAIConnectivityCheck {
            return String(localized: "Runs a cloud AI reachability check when activated.")
        }
        if !aiFeaturesOn {
            return String(localized: "Enable AI features to check cloud AI connection status.")
        }
        return String(localized: "Cloud AI isn’t set up on this build.")
    }

    func aiCloudStatusMessage(_ row: AISettingsCloudStatusRow) -> String {
        switch row {
        case .misconfigured:
            return String(localized: "Cloud AI isn’t set up on this build.")
        case .checking:
            return String(localized: "Checking…")
        case .offline:
            return String(localized: "No internet connection")
        case .checkFailed:
            return String(localized: "Couldn’t verify—try again")
        case .connectionVerified:
            return String(localized: "Connection looks good.")
        }
    }

    var shouldUseCompactReminderPicker: Bool {
        dynamicTypeSize >= .accessibility1 || verticalSizeClass == .compact
    }

    var reminderToggleBinding: Binding<Bool> {
        Binding(
            get: { isReminderToggleOn },
            set: { newValue in
                guard !reminderState.isPermissionDenied else { return }
                isReminderToggleOn = newValue
                isReminderPickerExpanded = newValue
                Task {
                    await reminderState.setReminderEnabled(newValue)
                }
            }
        )
    }

    var reminderTimeControlRow: some View {
        HStack(spacing: AppTheme.spacingRegular) {
            Button {
                guard reminderState.isReminderEnabled else { return }
                isReminderPickerExpanded.toggle()
            } label: {
                HStack(spacing: AppTheme.spacingRegular) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                        Text(String(localized: "Daily reminder"))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                        Text(reminderState.summaryText)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.settingsTextMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: AppTheme.spacingRegular)

                    if reminderState.isReminderEnabled {
                        Image(systemName: isReminderPickerExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.settingsTextMuted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!reminderState.isReminderEnabled || reminderState.isWorking)
            .accessibilityLabel(String(localized: "Reminder time"))
            .accessibilityValue(
                reminderState.isReminderEnabled
                    ? reminderState.selectedTime.formatted(date: .omitted, time: .shortened)
                    : String(localized: "Off")
            )

            Toggle("", isOn: reminderToggleBinding)
                .labelsHidden()
                .tint(AppTheme.accent)
                .disabled(reminderState.isPermissionDenied || reminderState.isWorking)
                .accessibilityLabel(String(localized: "Daily reminder"))
        }
        .frame(minHeight: 44)
    }

    var reminderPermissionDeniedGuidance: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "Allow notifications in Settings to enable daily reminders."))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)

            SettingsOpenSystemSettingsButton(
                action: openSystemSettings,
                accessibilityHint: String(localized: "Open iOS Settings for notification permissions.")
            )
        }
    }

    var reminderUnavailableGuidance: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "Unavailable. Check notification permissions and try again."))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)

            HStack(spacing: AppTheme.spacingRegular) {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    Text(String(localized: "Try again"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.reminderPrimaryActionBackground)
                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Retry scheduling your daily reminder."))

                Button {
                    Task {
                        await reminderState.refreshStatus()
                    }
                } label: {
                    Text(String(localized: "Refresh"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.reminderSecondaryActionTint)
                .foregroundStyle(AppTheme.reminderSecondaryActionTint)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Check if notification permissions have changed."))
            }
        }
    }

    @ViewBuilder
    var reminderTimePicker: some View {
        if shouldUseCompactReminderPicker {
            DatePicker(
                "",
                selection: $reminderState.selectedTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextPrimary)
            .tint(AppTheme.reminderSecondaryActionTint)
            .accessibilityLabel(String(localized: "Reminder time"))
            .accessibilityHint(String(localized: "Choose a reminder time."))
        } else {
            DatePicker(
                "",
                selection: $reminderState.selectedTime,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .datePickerStyle(.wheel)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextPrimary)
            .accessibilityLabel(String(localized: "Reminder time"))
            .accessibilityHint(String(localized: "Choose a reminder time."))
        }
    }

    func syncReminderControlState(with status: ReminderLiveStatus) {
        isReminderToggleOn = status == .enabled
        if status != .enabled {
            isReminderPickerExpanded = false
        }
    }

    var reminderErrorIsPresented: Binding<Bool> {
        Binding(
            get: { reminderState.transientErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    reminderState.clearTransientError()
                }
            }
        )
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
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
            }
        }
        return String(localized: "DataPrivacy.import.error.generic")
    }
}

private struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

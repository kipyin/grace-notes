import SwiftUI
import SwiftData
import UIKit

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
    @State private var isReminderPickerExpanded = false
    @State private var isReminderToggleOn = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportFile: ShareableFile?
    @State private var isExportingData = false

    private let dataExportService = JournalDataExportService()

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "AI features"), isOn: aiFeaturesEnabled)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .tint(AppTheme.accent)
            } header: {
                Text(String(localized: "AI"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
            } footer: {
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

            Section {
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
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
            } footer: {
                Text(String(localized: "Get one local reminder each day to complete today's entry."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }

            DataPrivacySettingsSection(
                isICloudSyncEnabled: $isICloudSyncEnabled,
                iCloudAccountState: iCloudAccountState,
                persistenceRuntimeSnapshot: persistenceRuntimeSnapshot,
                isExportingData: isExportingData,
                onExport: { exportJournalData() },
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
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
            iCloudAccountState.refresh()
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
        .overlay {
            if isExportingData {
                ProgressView(String(localized: "Exporting…"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

}

private extension SettingsScreen {
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

            Button {
                openSystemSettings()
            } label: {
                Text(String(localized: "Open Settings"))
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.reminderPrimaryActionBackground)
            .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
            .font(AppTheme.warmPaperBody)
            .accessibilityHint(String(localized: "Open iOS Settings for notification permissions."))
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

    var aiFeaturesEnabled: Binding<Bool> {
        Binding(
            get: { useCloudSummarization || useAIReviewInsights },
            set: { isEnabled in
                useCloudSummarization = isEnabled
                useAIReviewInsights = isEnabled
            }
        )
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
}

private struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

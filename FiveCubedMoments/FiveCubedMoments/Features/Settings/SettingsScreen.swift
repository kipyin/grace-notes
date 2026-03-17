import SwiftUI
import SwiftData

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var iCloudSyncEnabled = true
    @AppStorage("confirmChipDeletion") private var confirmChipDeletion = true
    @AppStorage(ReminderSettings.enabledKey) private var dailyReminderEnabled = false
    @AppStorage(ReminderSettings.timeIntervalKey)
    private var dailyReminderTimeInterval = ReminderSettings.defaultTimeInterval
    @Environment(\.modelContext) private var modelContext

    @State private var reminderDraftTime = ReminderSettings.date(from: ReminderSettings.defaultTimeInterval)
    @State private var isReminderTimePickerExpanded = false
    @State private var isSavingReminderTime = false
    @State private var reminderErrorMessage: String?
    @State private var showReminderError = false
    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportFile: ShareableFile?
    @State private var isExportingData = false

    private let reminderScheduler = ReminderScheduler()
    private let dataExportService = JournalDataExportService()
    private let isCloudSyncAvailable = !PersistenceController.isDemoDatabaseEnabled

    var body: some View {
        List {
            Section {
                Toggle("Confirm chip deletion", isOn: $confirmChipDeletion)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text("Chips")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text("When on, long-pressing a chip shows a confirmation before deleting. "
                    + "When off, long-press deletes immediately.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle("Use cloud summarization", isOn: $useCloudSummarization)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text("Summarization")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text("When on, chip labels use an online service for better summaries. "
                    + "When off, labels use on-device processing only.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle("Use AI review insights", isOn: $useAIReviewInsights)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text("Review Insights")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text("When on, weekly review insights may send your recent journal text "
                    + "to the configured cloud AI service. When off, review insights stay on-device.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle("Daily reminder", isOn: $dailyReminderEnabled)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                if dailyReminderEnabled {
                    Button {
                        if !isReminderTimePickerExpanded {
                            reminderDraftTime = savedReminderTime
                        }
                        isReminderTimePickerExpanded.toggle()
                    } label: {
                        HStack {
                            Text("Reminder time")
                            Spacer()
                            Text(savedReminderTime, style: .time)
                                .foregroundStyle(AppTheme.textMuted)
                            Image(systemName: isReminderTimePickerExpanded ? "chevron.up" : "chevron.down")
                                .foregroundStyle(AppTheme.textMuted)
                        }
                        .font(AppTheme.warmPaperBody)
                    }
                    .buttonStyle(.plain)

                    if isReminderTimePickerExpanded {
                        DatePicker(
                            "Reminder time",
                            selection: $reminderDraftTime,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.textPrimary)

                        Button {
                            Task {
                                await confirmReminderTime()
                            }
                        } label: {
                            if isSavingReminderTime {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Done")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .font(AppTheme.warmPaperBody)
                        .disabled(isSavingReminderTime)
                    }
                }
            } header: {
                Text("Reminders")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text("Get one daily local reminder to complete today's 5³.")
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle("Sync with iCloud", isOn: $iCloudSyncEnabled)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .disabled(!isCloudSyncAvailable)

                Button("Export journal data (JSON)") {
                    exportJournalData()
                }
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.accent)
                .disabled(isExportingData)
            } header: {
                Text("Data & Privacy")
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(dataPrivacyFooterText)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Settings")
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .task {
            reminderDraftTime = savedReminderTime
            await syncReminderSchedule()
        }
        .onChange(of: dailyReminderEnabled) { _, newValue in
            Task {
                await updateReminderEnabledState(isEnabled: newValue)
            }
        }
        .alert("Unable to update reminder", isPresented: $showReminderError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reminderErrorMessage ?? "Please try again.")
        }
        .alert("Unable to export data", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Please try again.")
        }
        .overlay {
            if isExportingData {
                ProgressView("Exporting…")
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var savedReminderTime: Date {
        ReminderSettings.date(from: dailyReminderTimeInterval)
    }

    private var dataPrivacyFooterText: String {
        if !isCloudSyncAvailable {
            return "This demo build keeps journal entries on this device only. Export creates a full JSON backup you can keep."
        }

        return "Journal entries are stored locally and can sync through your iCloud private "
            + "database when enabled. Sync changes apply on next app launch. "
            + "Export creates a full JSON backup you can keep."
    }

    private func syncReminderSchedule() async {
        _ = await reminderScheduler.syncDailyReminder(
            enabled: dailyReminderEnabled,
            time: savedReminderTime
        )
    }

    private func updateReminderEnabledState(isEnabled: Bool) async {
        if !isEnabled {
            isReminderTimePickerExpanded = false
            await syncReminderSchedule()
            return
        }

        reminderDraftTime = savedReminderTime
        let result = await reminderScheduler.syncDailyReminder(enabled: true, time: savedReminderTime)
        if case .permissionDenied = result {
            reminderErrorMessage = "Allow notifications in Settings to enable daily reminders."
            showReminderError = true
            dailyReminderEnabled = false
        } else if case .failed = result {
            reminderErrorMessage = "Unable to schedule your reminder right now."
            showReminderError = true
            dailyReminderEnabled = false
        }
    }

    private func confirmReminderTime() async {
        guard !isSavingReminderTime else {
            return
        }
        isSavingReminderTime = true
        defer { isSavingReminderTime = false }

        let result = await reminderScheduler.syncDailyReminder(enabled: true, time: reminderDraftTime)
        switch result {
        case .scheduled:
            dailyReminderTimeInterval = reminderDraftTime.timeIntervalSinceReferenceDate
            isReminderTimePickerExpanded = false
        case .permissionDenied:
            reminderErrorMessage = "Allow notifications in Settings to confirm a reminder time."
            showReminderError = true
        case .failed:
            reminderErrorMessage = "Unable to save that reminder time right now."
            showReminderError = true
        case .disabled:
            break
        }
    }

    private func exportJournalData() {
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
                    exportErrorMessage = "Unable to export your journal data right now."
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

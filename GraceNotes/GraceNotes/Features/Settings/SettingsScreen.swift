import SwiftUI
import SwiftData

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var iCloudSyncEnabled = true
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
                Toggle(String(localized: "Use cloud summarization"), isOn: $useCloudSummarization)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text(String(localized: "Summarization"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(
                    String(
                        localized: "When on, chip labels use an online service for better summaries. \
                        When off, labels use on-device processing only."
                    )
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle(String(localized: "Use AI review insights"), isOn: $useAIReviewInsights)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text(String(localized: "Review Insights"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(
                    String(
                        localized: "When on, weekly review insights may send your recent journal text to \
                        the configured cloud AI service. When off, review insights stay on-device."
                    )
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle(String(localized: "Daily reminder"), isOn: $dailyReminderEnabled)
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
                            Text(String(localized: "Reminder time"))
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
                            String(localized: "Reminder time"),
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
                                Text(String(localized: "Done"))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .font(AppTheme.warmPaperBody)
                        .disabled(isSavingReminderTime)
                    }
                }
            } header: {
                Text(String(localized: "Reminders"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(String(localized: "Get one daily local reminder to complete today's entry."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle(String(localized: "Sync with iCloud"), isOn: $iCloudSyncEnabled)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
                    .disabled(!isCloudSyncAvailable)

                Button(String(localized: "Export journal data (JSON)")) {
                    exportJournalData()
                }
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.accent)
                .disabled(isExportingData)
            } header: {
                Text(String(localized: "Data & Privacy"))
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
        .navigationTitle(String(localized: "Settings"))
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
        .alert(String(localized: "Unable to update reminder"), isPresented: $showReminderError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(reminderErrorMessage ?? String(localized: "Please try again."))
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

    private var savedReminderTime: Date {
        ReminderSettings.date(from: dailyReminderTimeInterval)
    }

    private var dataPrivacyFooterText: String {
        if !isCloudSyncAvailable {
            return String(
                localized: "This demo build keeps journal entries on this device only. \
                Export creates a full JSON backup you can keep."
            )
        }

        return String(
            localized: "Journal entries are stored locally and can sync through your iCloud private \
            database when enabled. Sync changes apply on next app launch. Export creates a full JSON \
            backup you can keep."
        )
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
            reminderErrorMessage = String(localized: "Allow notifications in Settings to enable daily reminders.")
            showReminderError = true
            dailyReminderEnabled = false
        } else if case .failed = result {
            reminderErrorMessage = String(localized: "Unable to schedule your reminder right now.")
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
            reminderErrorMessage = String(localized: "Allow notifications in Settings to confirm a reminder time.")
            showReminderError = true
        case .failed:
            reminderErrorMessage = String(localized: "Unable to save that reminder time right now.")
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
                    exportErrorMessage = String(localized: "Unable to export your journal data right now.")
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

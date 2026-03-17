import SwiftUI

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage("confirmChipDeletion") private var confirmChipDeletion = true
    @AppStorage(ReminderSettings.enabledKey) private var dailyReminderEnabled = false
    @AppStorage(ReminderSettings.timeIntervalKey)
    private var dailyReminderTimeInterval = ReminderSettings.defaultTimeInterval

    @State private var reminderDraftTime = ReminderSettings.date(from: ReminderSettings.defaultTimeInterval)
    @State private var isReminderTimePickerExpanded = false
    @State private var isSavingReminderTime = false
    @State private var reminderErrorMessage: String?
    @State private var showReminderError = false

    private let reminderScheduler = ReminderScheduler()

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
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Settings")
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
    }

    private var savedReminderTime: Date {
        ReminderSettings.date(from: dailyReminderTimeInterval)
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
}

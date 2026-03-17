import SwiftUI

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage("confirmChipDeletion") private var confirmChipDeletion = true
    @AppStorage(ReminderSettings.enabledKey) private var dailyReminderEnabled = false
    @AppStorage(ReminderSettings.timeIntervalKey) private var dailyReminderTimeInterval = ReminderSettings.defaultTimeInterval

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
                    DatePicker(
                        "Reminder time",
                        selection: reminderTimeBinding,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
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
            await syncReminderSchedule()
        }
        .onChange(of: dailyReminderEnabled) { _, _ in
            Task {
                await syncReminderSchedule()
            }
        }
        .onChange(of: dailyReminderTimeInterval) { _, _ in
            Task {
                await syncReminderSchedule()
            }
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: { ReminderSettings.date(from: dailyReminderTimeInterval) },
            set: { dailyReminderTimeInterval = $0.timeIntervalSinceReferenceDate }
        )
    }

    private func syncReminderSchedule() async {
        await reminderScheduler.syncDailyReminder(
            enabled: dailyReminderEnabled,
            time: ReminderSettings.date(from: dailyReminderTimeInterval)
        )
    }
}

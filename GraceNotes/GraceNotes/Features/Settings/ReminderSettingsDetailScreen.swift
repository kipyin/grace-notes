import SwiftUI
import UIKit

struct ReminderSettingsDetailScreen: View {
    @ObservedObject var reminderState: ReminderSettingsFlowModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                statusContent
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(String(localized: "Daily reminder"))
        .task {
            await reminderState.refreshStatus()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
        }
        .onChange(of: reminderState.selectedTime) { _, _ in
            reminderState.handleSelectedTimeChanged()
        }
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
    }
}

private extension ReminderSettingsDetailScreen {
    @ViewBuilder
    var statusContent: some View {
        switch reminderState.liveStatus {
        case .enabled:
            enabledContent
        case .off:
            offContent(showPrePromptCopy: false)
        case .notDetermined:
            offContent(showPrePromptCopy: true)
        case .denied:
            deniedContent
        case .unavailable:
            unavailableContent
        }
    }

    var enabledContent: some View {
        Group {
            Text(String(localized: "Reminder is on."))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)

            DatePicker(
                String(localized: "Reminder time"),
                selection: $reminderState.selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Button(role: .destructive) {
                    Task {
                        await reminderState.disableReminders()
                    }
                } label: {
                    if reminderState.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "Turn off"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
            }
        }
    }

    func offContent(showPrePromptCopy: Bool) -> some View {
        Group {
            if showPrePromptCopy {
                Text(String(localized: "Turn on a daily reminder."))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
            } else {
                Text(String(localized: "Reminder is off."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            }

            HStack(spacing: 12) {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    if reminderState.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "Enable"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
            }
        }
    }

    var deniedContent: some View {
        Group {
            Text(String(localized: "Notifications are denied."))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Button {
                    openSystemSettings()
                } label: {
                    Text(String(localized: "Open Settings"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    Task {
                        await reminderState.refreshStatus()
                    }
                } label: {
                    Text(String(localized: "Refresh"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(reminderState.isWorking)
            }
            .font(AppTheme.warmPaperBody)
        }
    }

    var unavailableContent: some View {
        Group {
            Text(String(localized: "Reminder is unavailable right now."))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    if reminderState.isWorking {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "Try again"))
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
            }
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
}

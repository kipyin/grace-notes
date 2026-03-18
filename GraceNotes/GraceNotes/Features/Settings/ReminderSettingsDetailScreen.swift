import SwiftUI
import UIKit

struct ReminderSettingsDetailScreen: View {
    @ObservedObject var reminderState: ReminderSettingsFlowModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                    Text(String(localized: "Reminder status"))
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.settingsTextMuted)

                    statusContent
                }
                .padding(.vertical, AppTheme.spacingTight / 2)
                .listRowBackground(AppTheme.settingsPaper.opacity(0.92))
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
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
    var shouldStackActionButtonsVertically: Bool {
        dynamicTypeSize.isAccessibilitySize || verticalSizeClass == .compact
    }

    var shouldUseCompactPicker: Bool {
        dynamicTypeSize >= .accessibility1 || verticalSizeClass == .compact
    }

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
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "Reminder is on."))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityLabel(String(localized: "Reminder status"))
                .accessibilityValue(String(localized: "Reminder is on."))

            reminderTimePicker

            actionButtonsContainer {
                Button(role: .destructive) {
                    Task {
                        await reminderState.disableReminders()
                    }
                } label: {
                    loadingButtonLabel(
                        defaultText: String(localized: "Turn off"),
                        loadingText: String(localized: "Turning reminder off…")
                    )
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.reminderDestructiveActionTint)
                .foregroundStyle(AppTheme.reminderDestructiveActionTint)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Disable your daily reminder notification."))
            }
        }
    }

    func offContent(showPrePromptCopy: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            if showPrePromptCopy {
                Text(String(localized: "Turn on a daily reminder."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .accessibilityLabel(String(localized: "Reminder status"))
                    .accessibilityValue(String(localized: "Reminder is off."))
            } else {
                Text(String(localized: "Reminder is off."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .accessibilityLabel(String(localized: "Reminder status"))
                    .accessibilityValue(String(localized: "Reminder is off."))
            }

            actionButtonsContainer {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    loadingButtonLabel(
                        defaultText: String(localized: "Enable"),
                        loadingText: String(localized: "Enabling reminder…")
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.reminderPrimaryActionBackground)
                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Enable one notification every day."))
            }
        }
    }

    var deniedContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "Notifications are denied."))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityLabel(String(localized: "Reminder status"))
                .accessibilityValue(String(localized: "Notifications are denied."))

            Text(String(localized: "Open iOS Settings, allow notifications for Grace Notes, then return here and refresh."))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)

            actionButtonsContainer {
                Button {
                    openSystemSettings()
                } label: {
                    Text(String(localized: "Open Settings"))
                        .frame(maxWidth: .infinity, minHeight: 24)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.reminderPrimaryActionBackground)
                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                .accessibilityHint(String(localized: "Open iOS Settings for notification permissions."))

                Button {
                    Task {
                        await reminderState.refreshStatus()
                    }
                } label: {
                    loadingButtonLabel(
                        defaultText: String(localized: "Refresh"),
                        loadingText: String(localized: "Refreshing reminder status…")
                    )
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.reminderSecondaryActionTint)
                .foregroundStyle(AppTheme.reminderSecondaryActionTint)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Check if notification permissions have changed."))
            }
            .font(AppTheme.warmPaperBody)
        }
    }

    var unavailableContent: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "Reminder unavailable. Check notification permissions and try again."))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityLabel(String(localized: "Reminder status"))
                .accessibilityValue(
                    String(localized: "Reminder unavailable. Check notification permissions and try again.")
                )

            actionButtonsContainer {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    loadingButtonLabel(
                        defaultText: String(localized: "Try again"),
                        loadingText: String(localized: "Retrying reminder setup…")
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.reminderPrimaryActionBackground)
                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "Retry scheduling your daily reminder."))
            }
        }
    }

    @ViewBuilder
    var reminderTimePicker: some View {
        if shouldUseCompactPicker {
            DatePicker(
                String(localized: "Reminder time"),
                selection: $reminderState.selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextPrimary)
            .tint(AppTheme.reminderSecondaryActionTint)
            .accessibilityLabel(String(localized: "Reminder time"))
            .accessibilityHint(String(localized: "Choose the time for your daily reminder."))
        } else {
            DatePicker(
                String(localized: "Reminder time"),
                selection: $reminderState.selectedTime,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextPrimary)
            .accessibilityLabel(String(localized: "Reminder time"))
            .accessibilityHint(String(localized: "Choose the time for your daily reminder."))
        }
    }

    @ViewBuilder
    func actionButtonsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if shouldStackActionButtonsVertically {
            VStack(spacing: AppTheme.spacingRegular) {
                content()
            }
        } else {
            HStack(spacing: AppTheme.spacingRegular) {
                content()
            }
        }
    }

    @ViewBuilder
    func loadingButtonLabel(defaultText: String, loadingText: String) -> some View {
        HStack(spacing: AppTheme.spacingTight) {
            if reminderState.isWorking {
                ProgressView()
                    .controlSize(.small)
            }
            Text(reminderState.isWorking ? loadingText : defaultText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 24)
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

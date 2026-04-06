import SwiftUI
import UIKit

extension AppTourView {
    // MARK: - Reminders (aligned with Settings)

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
                        Text(String(localized: "notifications.reminder.dailyLabel"))
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
                            .font(AppTheme.outfitSemiboldCaption)
                            .foregroundStyle(AppTheme.settingsTextMuted)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!reminderState.isReminderEnabled || reminderState.isWorking)
            .accessibilityLabel(String(localized: "notifications.reminder.timeLabel"))
            .accessibilityValue(
                reminderState.isReminderEnabled
                    ? reminderState.selectedTime.formatted(date: .omitted, time: .shortened)
                    : String(localized: "common.off")
            )

            Toggle("", isOn: reminderToggleBinding)
                .labelsHidden()
                .tint(AppTheme.reviewAccent)
                .disabled(reminderState.isPermissionDenied || reminderState.isWorking)
                .accessibilityLabel(String(localized: "notifications.reminder.dailyLabel"))
        }
        .frame(minHeight: 44)
    }

    var reminderPermissionDeniedGuidance: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "notifications.reminder.enableInSettings"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)

            SettingsOpenSystemSettingsButton(
                action: openSystemSettings,
                accessibilityHint: String(localized: "notifications.reminder.openIOSSettingsHint")
            )
        }
    }

    var reminderUnavailableGuidance: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
            Text(String(localized: "notifications.reminder.unavailablePermissions"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)

            HStack(spacing: AppTheme.spacingRegular) {
                Button {
                    Task {
                        await reminderState.enableReminders()
                    }
                } label: {
                    Text(String(localized: "common.tryAgain"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.reminderPrimaryActionBackground)
                .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "notifications.reminder.retrySchedulingHint"))

                Button {
                    Task {
                        await reminderState.refreshStatus()
                    }
                } label: {
                    Text(String(localized: "common.refresh"))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.reminderSecondaryActionTint)
                .foregroundStyle(AppTheme.reminderSecondaryActionTint)
                .font(AppTheme.warmPaperBody)
                .disabled(reminderState.isWorking)
                .accessibilityHint(String(localized: "notifications.reminder.checkPermissionsHint"))
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
            .accessibilityLabel(String(localized: "notifications.reminder.timeLabel"))
            .accessibilityHint(String(localized: "notifications.reminder.chooseTimeHint"))
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
            .accessibilityLabel(String(localized: "notifications.reminder.timeLabel"))
            .accessibilityHint(String(localized: "notifications.reminder.chooseTimeHint"))
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

}

import SwiftUI
import UIKit

extension PostSeedJourneyView {
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
                            .font(AppTheme.outfitSemiboldCaption)
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

    // MARK: - AI (aligned with Settings)

    var aiFeaturesOn: Bool {
        useCloudSummarization
    }

    var canRunAIConnectivityCheck: Bool {
        aiFeaturesOn && ApiSecrets.isCloudApiKeyConfigured
    }

    func syncAICloudStatusModel() {
        aiCloudStatus.refresh(aiFeaturesEnabled: aiFeaturesOn)
    }

    func clampCloudAIFeaturesIfApiKeyMissing() {
        guard !ApiSecrets.isCloudApiKeyConfigured, aiFeaturesOn else { return }
        useCloudSummarization = false
        syncAICloudStatusModel()
    }

    var aiRowStatusText: String {
        if !ApiSecrets.isCloudApiKeyConfigured {
            return String(localized: "Cloud AI isn’t set up on this build.")
        }
        if !aiFeaturesOn {
            return String(localized: "Off")
        }
        if let row = aiCloudStatus.statusRow {
            return aiCloudStatusMessage(row)
        }
        return String(localized: "Tap for connection status")
    }

    var aiFeaturesToggleBinding: Binding<Bool> {
        Binding(
            get: { aiFeaturesOn },
            set: { enabled in
                useCloudSummarization = enabled
                syncAICloudStatusModel()
            }
        )
    }

    var aiToggleAccessibilityHint: String {
        guard !ApiSecrets.isCloudApiKeyConfigured else { return "" }
        return String(localized: "Cloud AI isn’t set up on this build.")
    }

    var aiConnectionAccessibilityHint: String {
        if !ApiSecrets.isCloudApiKeyConfigured {
            return String(localized: "Cloud AI isn’t set up on this build.")
        }
        if canRunAIConnectivityCheck {
            return String(localized: "Runs a cloud AI reachability check when activated.")
        }
        if !aiFeaturesOn {
            return String(localized: "Settings.ai.a11y.enableForConnectionCheck")
        }
        return String(localized: "Cloud AI isn’t set up on this build.")
    }

    var aiConnectionControlRow: some View {
        HStack(spacing: AppTheme.spacingRegular) {
            Button {
                guard canRunAIConnectivityCheck else { return }
                aiCloudStatus.requestManualConnectivityCheck()
            } label: {
                HStack(spacing: AppTheme.spacingRegular) {
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                        Text(String(localized: "Settings.ai.toggleLabel"))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                        Text(aiRowStatusText)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.settingsTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: AppTheme.spacingRegular)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canRunAIConnectivityCheck)
            .accessibilityLabel(String(localized: "AI connection status"))
            .accessibilityValue(aiRowStatusText)
            .accessibilityHint(aiConnectionAccessibilityHint)

            Toggle("", isOn: aiFeaturesToggleBinding)
                .labelsHidden()
                .tint(AppTheme.accent)
                .disabled(!ApiSecrets.isCloudApiKeyConfigured)
                .accessibilityLabel(String(localized: "Settings.ai.toggleLabel"))
                .accessibilityHint(aiToggleAccessibilityHint)
        }
        .frame(minHeight: 44)
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
}

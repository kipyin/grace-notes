import SwiftUI
import UIKit

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = false
    @EnvironmentObject private var appNavigation: AppNavigationModel
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
    @State private var highlightedTarget: SettingsScrollTarget?
    @State private var settingsHighlightDismissTask: Task<Void, Never>?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                        aiConnectionControlRow
                    }
                    .padding(.vertical, AppTheme.spacingTight / 2)
                    .id(SettingsScrollTarget.aiFeatures)
                    .settingsTargetHighlight(highlightedTarget == .aiFeatures)
                } header: {
                    Text(String(localized: "Settings.ai.sectionTitle"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
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
                    .id(SettingsScrollTarget.reminders)
                    .settingsTargetHighlight(highlightedTarget == .reminders)
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
                    highlightedTarget: highlightedTarget,
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
            .onAppear {
                clampCloudAIFeaturesIfApiKeyMissing()
            }
            .task {
                clampCloudAIFeaturesIfApiKeyMissing()
                await reminderState.refreshStatus()
                syncReminderControlState(with: reminderState.liveStatus)
                iCloudAccountState.refresh()
                syncAICloudStatusModel()
                aiCloudStatus.scheduleThrottledAutoCheckIfNeeded()
                if let target = appNavigation.settingsScrollTarget {
                    focusSettingsTarget(target, proxy: proxy)
                }
            }
            .onDisappear {
                aiCloudStatus.onSettingsDisappear()
                settingsHighlightDismissTask?.cancel()
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
            .onChange(of: appNavigation.settingsScrollTarget) { _, newValue in
                guard let target = newValue else { return }
                focusSettingsTarget(target, proxy: proxy)
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

    /// Cloud AI toggles require a non-placeholder API key; keep AppStorage consistent with that constraint.
    func clampCloudAIFeaturesIfApiKeyMissing() {
        guard !ApiSecrets.isCloudApiKeyConfigured, aiFeaturesOn else { return }
        useCloudSummarization = false
        useAIReviewInsights = false
        syncAICloudStatusModel()
    }

    /// Inline status under the toggle label (visible in every state: misconfigured, off, or on + connectivity).
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
            .accessibilityValue(aiConnectionAccessibilityValue)
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

    var aiConnectionAccessibilityValue: String {
        aiRowStatusText
    }

    /// Empty when the default toggle behavior needs no extra VoiceOver context.
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

    /// Scroll targets from `AppNavigationModel` are expected to be set by validated callers (e.g. journal onboarding).
    func focusSettingsTarget(_ target: SettingsScrollTarget, proxy: ScrollViewProxy) {
        settingsHighlightDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.24)) {
            proxy.scrollTo(target, anchor: .center)
            highlightedTarget = target
        }
        appNavigation.clearSettingsTarget(target)
        settingsHighlightDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                if highlightedTarget == target {
                    highlightedTarget = nil
                }
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

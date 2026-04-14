import SwiftUI
import UIKit

struct SettingsScreen: View {
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) private var isICloudSyncEnabled = false
    @EnvironmentObject private var appNavigation: AppNavigationModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.persistenceRuntimeSnapshot) private var persistenceRuntimeSnapshot

    @StateObject private var reminderState = ReminderSettingsFlowModel()
    @StateObject private var iCloudAccountState = ICloudAccountStatusModel()
    @StateObject private var iCloudSyncActivity = ICloudSyncActivityModel()
    @State private var isReminderPickerExpanded = false
    @State private var isReminderToggleOn = false
    @State private var highlightedTarget: SettingsScrollTarget?
    @State private var settingsHighlightDismissTask: Task<Void, Never>?
    @State private var showAppTourFromSettings = false
    @AppStorage(JournalOnboardingStorageKeys.completedGuidedJournal) private var hasCompletedGuidedJournal = false
    /// Same storage as first Full/Harvest celebration; unlocks Bloom in Advanced settings.
    @AppStorage(JournalTutorialStorageKeys.celebratedFirstBloom) private var hasCelebratedFirstBloom = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
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
                        String(localized: "notifications.reminder.updateFailedTitle"),
                        isPresented: reminderErrorIsPresented
                    ) {
                        Button(String(localized: "common.ok"), role: .cancel) {
                            reminderState.clearTransientError()
                        }
                    } message: {
                        Text(reminderState.transientErrorMessage ?? String(localized: "common.tryAgainGeneric"))
                    }
                } header: {
                    Text(String(localized: "settings.reminders.sectionTitle"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .textCase(nil)
                }

                DataPrivacySettingsSection(
                    isICloudSyncEnabled: $isICloudSyncEnabled,
                    iCloudAccountState: iCloudAccountState,
                    persistenceRuntimeSnapshot: persistenceRuntimeSnapshot,
                    lastICloudSyncSubtitle: iCloudSyncSubtitle,
                    highlightedTarget: highlightedTarget,
                    openSystemSettings: { openSystemSettings() }
                )

                Section {
                    Button {
                        showAppTourFromSettings = true
                    } label: {
                        HStack(spacing: AppTheme.spacingRegular) {
                            Text(String(localized: "settings.showAppTour"))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.settingsTextPrimary)
                            Spacer(minLength: AppTheme.spacingRegular)
                            Image(systemName: "chevron.right")
                                .font(AppTheme.outfitRegularCaption2)
                                .foregroundStyle(AppTheme.settingsTextMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .accessibilityHint(String(localized: "settings.showAppTour.a11yHint"))
                } header: {
                    Text(String(localized: "settings.help.sectionTitle"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .textCase(nil)
                }

                Section {
                    NavigationLink {
                        AdvancedSettingsScreen()
                    } label: {
                        HStack(spacing: AppTheme.spacingRegular) {
                            Text(String(localized: "settings.advanced.navTitle"))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.settingsTextPrimary)
                            Spacer(minLength: AppTheme.spacingRegular)
                        }
                        .contentShape(Rectangle())
                    }
                    .frame(minHeight: 44)
                }
            }
            .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
            .scrollContentBackground(.hidden)
            .background(AppTheme.settingsBackground)
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: AppTheme.spacingSection + AppTheme.floatingTabBarClearance)
            }
            .navigationTitle(String(localized: "shell.tab.settings"))
            .task {
                backfillBloomUnlockIfNeeded()
                reminderState.reminderNotificationBody = { reminderTime in
                    (try? ReminderNotificationBodyBuilder.localizedBody(
                        modelContext: modelContext,
                        reminderTime: reminderTime
                    )) ?? String(localized: String.LocalizationValue("notifications.reminder.body.fallback"))
                }
                await reminderState.refreshStatus()
                syncReminderControlState(with: reminderState.liveStatus)
                iCloudAccountState.refresh()
                if let target = appNavigation.settingsScrollTarget {
                    focusSettingsTarget(target, proxy: proxy)
                }
            }
            .onAppear {
                iCloudSyncActivity.startMonitoring()
            }
            .onDisappear {
                settingsHighlightDismissTask?.cancel()
                settingsHighlightDismissTask = nil
                highlightedTarget = nil
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
            .onChange(of: appNavigation.settingsScrollTarget) { _, newValue in
                guard let target = newValue else { return }
                focusSettingsTarget(target, proxy: proxy)
            }
            .fullScreenCover(isPresented: $showAppTourFromSettings) {
                AppTourView(
                    onFinish: {
                        JournalOnboardingProgress.applyAppTourCompletion(using: .standard)
                        showAppTourFromSettings = false
                    },
                    skipsCongratulationsPage: hasCompletedGuidedJournal
                )
            }
            .onChange(of: showAppTourFromSettings) { _, isPresented in
                guard isPresented else { return }
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
    }

}

private extension SettingsScreen {
    var iCloudSyncSubtitle: String? {
        let snapshot = persistenceRuntimeSnapshot
        guard snapshot.storeUsesCloudKit, !snapshot.startupUsedCloudKitFallback else {
            return nil
        }
        if let date = iCloudSyncActivity.lastRemoteChangeAt {
            return ICloudSyncLastActivityFormatting.lastActivitySubtitle(
                lastActivity: date,
                referenceNow: Date()
            )
        }
        return String(localized: "DataPrivacy.iCloudSync.lastActivity.pending")
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
                .tint(AppTheme.accent)
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

    func backfillBloomUnlockIfNeeded() {
        guard !hasCelebratedFirstBloom else { return }
        let repository = JournalRepository()
        guard (try? repository.hasUserEverReachedBloom(context: modelContext)) == true else { return }
        hasCelebratedFirstBloom = true
    }
}

import SwiftUI

struct DataPrivacySettingsSection: View {
    @Binding var isICloudSyncEnabled: Bool
    @ObservedObject var iCloudAccountState: ICloudAccountStatusModel
    let persistenceRuntimeSnapshot: PersistenceRuntimeSnapshot
    let isExportingData: Bool
    let onExport: () -> Void
    let openSystemSettings: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                dataPrivacyPrimaryRow
                dataPrivacySecondaryRow
                dataPrivacyAccountRow

                if shouldOfferICloudSettingsLink {
                    Button {
                        openSystemSettings()
                    } label: {
                        Text(String(localized: "Open Settings"))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.reminderPrimaryActionBackground)
                    .foregroundStyle(AppTheme.reminderPrimaryActionForeground)
                    .font(AppTheme.warmPaperBody)
                    .accessibilityHint(
                        String(
                            localized:
                                "Opens iOS Settings where you can sign in to iCloud or review restrictions."
                        )
                    )
                }

                if shouldShowCloseAppRecoveryCopy {
                    Text(closeAppRecoveryBody)
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.settingsTextMuted)
                }

                if shouldShowICloudSyncToggle {
                    Toggle(String(localized: "iCloud sync"), isOn: $isICloudSyncEnabled)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .tint(AppTheme.accent)
                        .frame(minHeight: 44)
                }

                Button(String(localized: "Export Grace Notes data (JSON)")) {
                    onExport()
                }
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.accentText)
                .disabled(isExportingData)
                .frame(minHeight: 44)
            }
            .padding(.vertical, AppTheme.spacingTight / 2)
        } header: {
            Text(String(localized: "Data & Privacy"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)
        } footer: {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                Text(
                    String(
                        localized:
                            "Export creates a JSON file of your Grace Notes that you can keep as your own backup."
                    )
                )
                Text(
                    String(
                        localized: "Importing or restoring Grace Notes from a file in the app is not available yet."
                    )
                )
                Text(String(localized: "iCloud sync uses Apple iCloud when your account and network allow."))
                Text(String(localized: "It is not a complete backup by itself."))
                if shouldShowICloudSyncToggle {
                    Text(String(localized: "Changes to the sync switch apply the next time you open the app."))
                } else {
                    Text(String(localized:
                        "When iCloud is available again, your stored preference applies the next time you open the app."
                    ))
                }
            }
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.settingsTextMuted)
        }
    }
}

private extension DataPrivacySettingsSection {
    var preferenceMatchesEffectiveStore: Bool {
        isICloudSyncEnabled == persistenceRuntimeSnapshot.storeUsesCloudKit
    }

    var shouldOfferICloudSettingsLink: Bool {
        guard let bucket = iCloudAccountState.displayedBucket else { return false }
        switch bucket {
        case .noAccount, .restricted:
            return true
        case .available, .temporarilyUnavailable, .couldNotDetermine:
            return false
        }
    }

    /// `nil` bucket (still checking) keeps the toggle visible to avoid an empty first paint.
    var shouldShowICloudSyncToggle: Bool {
        iCloudAccountState.displayedBucket?.showsICloudSyncToggle ?? true
    }

    var closeAppRecoveryBody: String {
        if shouldShowICloudSyncToggle {
            return String(
                localized:
                    "Fully close the app and reopen it to apply your sync setting or retry iCloud storage."
            )
        }
        return String(localized:
            "When iCloud is available, fully close the app and reopen to retry storage or apply your stored preference."
        )
    }

    var shouldShowCloseAppRecoveryCopy: Bool {
        !preferenceMatchesEffectiveStore || persistenceRuntimeSnapshot.startupUsedCloudKitFallback
    }

    var dataPrivacyPrimaryRow: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "Grace Notes on this device"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Text(primaryJournalStorageBody)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Grace Notes storage on this device"))
    }

    var dataPrivacySecondaryRow: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "iCloud sync preference"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Text(secondarySyncPreferenceBody)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "iCloud sync preference"))
    }

    var dataPrivacyAccountRow: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "iCloud account"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Text(iCloudAccountStatusDetail)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "iCloud account"))
        .accessibilityValue(iCloudAccountStatusDetail)
    }

    var primaryJournalStorageBody: String {
        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback {
            return String(localized: "Stored on this device only. iCloud was not available when the app opened,")
                + " "
                + String(localized: "so your Grace Notes aren't using iCloud for this session.")
        }
        if persistenceRuntimeSnapshot.storeUsesCloudKit {
            return String(localized: "Your Grace Notes sync to iCloud from this device when iCloud is available.")
                + " "
                + String(localized: "Sync is not immediate and does not guarantee the same moment on every device.")
        }
        return String(localized: "Your Grace Notes stay on this device only and are not synced to iCloud.")
    }

    var secondarySyncPreferenceBody: String {
        if preferenceMatchesEffectiveStore {
            if shouldShowICloudSyncToggle {
                return String(
                    localized: "Your iCloud sync switch matches how data is stored for this session."
                )
            }
            return String(
                localized:
                    "Your stored iCloud sync preference matches how data is stored for this session."
            )
        }
        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback, isICloudSyncEnabled {
            return String(localized: "iCloud was unavailable when the app opened.")
                + " "
                + String(localized: "Fully close the app and reopen it to try iCloud storage again.")
        }
        if shouldShowICloudSyncToggle {
            return String(localized: "You changed iCloud sync here.")
                + " "
                + String(localized: "Fully close the app and reopen it for the new setting to take effect.")
        }
        return String(
            localized:
                "Your stored iCloud sync preference does not match how data is stored for this session."
        )
        + " "
        + String(
            localized:
                "Fully close the app and reopen when iCloud is available for your stored preference to take effect."
        )
    }

    var iCloudAccountStatusDetail: String {
        guard let bucket = iCloudAccountState.displayedBucket else {
            return String(localized: "Checking…")
        }
        switch bucket {
        case .available:
            return String(localized: "Available for iCloud.")
        case .noAccount:
            return String(localized: "No Apple ID signed in for iCloud on this device.")
        case .restricted:
            return String(localized: "Restricted on this device.")
        case .temporarilyUnavailable:
            return String(localized: "Temporarily unavailable. Try again later.")
        case .couldNotDetermine:
            return String(localized: "Could not determine. Try again later.")
        }
    }
}

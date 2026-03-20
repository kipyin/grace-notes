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
                storageSummaryBlock

                if let attentionMessage {
                    attentionBlock(message: attentionMessage)
                }

                if shouldShowICloudSyncToggle {
                    Toggle(String(localized: "iCloud sync"), isOn: $isICloudSyncEnabled)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .tint(AppTheme.accent)
                        .frame(minHeight: 44)
                }

                backupBlock
            }
            .padding(.vertical, AppTheme.spacingTight / 2)
        } header: {
            Text(String(localized: "Data & Privacy"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)
        } footer: {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                Text(String(localized: "DataPrivacy.footer.exportAndImport"))
                Text(String(localized: "DataPrivacy.footer.iCloudNotFullBackup"))
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

    var primaryStorageBody: String {
        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback {
            return String(localized: "DataPrivacy.storage.fallbackLocal")
        }
        if persistenceRuntimeSnapshot.storeUsesCloudKit {
            return String(localized: "DataPrivacy.storage.iCloudOn")
        }
        return String(localized: "DataPrivacy.storage.localOnly")
    }

    var attentionMessage: String? {
        if let bucket = iCloudAccountState.displayedBucket {
            switch bucket {
            case .noAccount:
                return String(localized: "DataPrivacy.attention.noAccount")
            case .restricted:
                return String(localized: "DataPrivacy.attention.restricted")
            case .temporarilyUnavailable:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "DataPrivacy.attention.tempUnavailableMismatch")
                }
                return String(localized: "DataPrivacy.attention.tempUnavailable")
            case .couldNotDetermine:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "DataPrivacy.attention.unknownMismatch")
                }
                return String(localized: "DataPrivacy.attention.unknown")
            case .available:
                break
            }
        }

        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback, isICloudSyncEnabled {
            return String(localized: "DataPrivacy.attention.retryICloudAfterRelaunch")
        }

        if !preferenceMatchesEffectiveStore {
            if shouldShowICloudSyncToggle {
                return String(localized: "DataPrivacy.attention.toggleChangedRelaunch")
            }
            return String(localized: "DataPrivacy.attention.preferenceMismatchRelaunch")
        }

        return nil
    }

    var storageSummaryBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "DataPrivacy.storage.heading"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Text(primaryStorageBody)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "DataPrivacy.a11y.storage"))
    }

    func attentionBlock(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if shouldOfferICloudSettingsLink {
                SettingsOpenSystemSettingsButton(
                    action: openSystemSettings,
                    accessibilityHint: String(
                        localized:
                            "Opens iOS Settings where you can sign in to iCloud or review restrictions."
                    )
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "DataPrivacy.a11y.nextSteps"))
    }

    var backupBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "DataPrivacy.backup.heading"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Button(String(localized: "Export Grace Notes data (JSON)")) {
                onExport()
            }
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.accentText)
            .disabled(isExportingData)
            .frame(minHeight: 44)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "DataPrivacy.a11y.backup"))
    }
}

import SwiftUI

struct DataPrivacySettingsSection: View {
    @Binding var isICloudSyncEnabled: Bool
    @ObservedObject var iCloudAccountState: ICloudAccountStatusModel
    let persistenceRuntimeSnapshot: PersistenceRuntimeSnapshot
    /// Shown below the iCloud sync toggle when CloudKit is the live store (best-effort remote activity).
    let lastICloudSyncSubtitle: String?
    let highlightedTarget: SettingsScrollTarget?
    let openSystemSettings: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                storageSummaryBlock

                if let attentionMessage {
                    attentionBlock(message: attentionMessage)
                }

                if shouldShowICloudSyncToggle {
                    Toggle(String(localized: "settings.dataPrivacy.iCloudSyncToggle"), isOn: $isICloudSyncEnabled)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .tint(AppTheme.accent)
                        .frame(minHeight: 44)

                    if isJournalOnCloudKitStore, let lastICloudSyncSubtitle {
                        Text(lastICloudSyncSubtitle)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.settingsTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.vertical, AppTheme.spacingTight / 2)
            .id(SettingsScrollTarget.dataPrivacy)
            .settingsTargetHighlight(highlightedTarget == .dataPrivacy)
            importExportRow
                .padding(.vertical, AppTheme.spacingTight / 2)
        } header: {
            Text(String(localized: "settings.dataPrivacy.navTitle"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .textCase(nil)
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

    /// Journal data is on the CloudKit-backed store (not the startup local fallback).
    private var isJournalOnCloudKitStore: Bool {
        persistenceRuntimeSnapshot.storeUsesCloudKit && !persistenceRuntimeSnapshot.startupUsedCloudKitFallback
    }

    var primaryStorageBody: String {
        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback {
            return String(localized: "settings.dataPrivacy.storage.fallbackLocal")
        }
        return String(localized: "settings.dataPrivacy.storage.localOnly")
    }

    var attentionMessage: String? {
        if let bucket = iCloudAccountState.displayedBucket {
            switch bucket {
            case .noAccount:
                return String(localized: "settings.dataPrivacy.attention.noAccount.summary")
            case .restricted:
                return String(localized: "settings.dataPrivacy.attention.restricted.summary")
            case .temporarilyUnavailable:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "settings.dataPrivacy.attention.tempUnavailableMismatch.summary")
                }
                return String(localized: "settings.dataPrivacy.attention.tempUnavailable")
            case .couldNotDetermine:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "settings.dataPrivacy.attention.unknownMismatch.summary")
                }
                return String(localized: "settings.dataPrivacy.attention.unknown")
            case .available:
                break
            }
        }

        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback, isICloudSyncEnabled {
            return String(localized: "settings.dataPrivacy.attention.retryICloudAfterRelaunch.summary")
        }

        if !preferenceMatchesEffectiveStore {
            if shouldShowICloudSyncToggle {
                return String(localized: "settings.dataPrivacy.attention.toggleChangedRelaunch.summary")
            }
            return String(localized: "settings.dataPrivacy.attention.preferenceMismatchRelaunch.summary")
        }

        return nil
    }

    var storageSummaryBlock: some View {
        Group {
            if isJournalOnCloudKitStore {
                storageHeadingOnlyBlock
            } else {
                storageHeadingWithLocalDescriptionBlock
            }
        }
    }

    /// No Storage body for CloudKit store; status copy is in `attentionBlock`.
    private var storageHeadingOnlyBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "settings.dataPrivacy.storage.heading"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.storage.cloudActive"))
    }

    private var storageHeadingWithLocalDescriptionBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
            Text(String(localized: "settings.dataPrivacy.storage.heading"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.settingsTextMuted)
            Text(primaryStorageBody)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.storage"))
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
                        localized: "settings.dataPrivacy.openIOSSettingsICloudHint"
                    ),
                    emphasis: .prominent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.nextSteps"))
    }

    var importExportRow: some View {
        NavigationLink {
            ImportExportSettingsScreen()
        } label: {
            HStack(spacing: AppTheme.spacingRegular) {
                Text(String(localized: "settings.dataPrivacy.importExport.rowTitle"))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                Spacer(minLength: AppTheme.spacingRegular)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.backup"))
    }
}

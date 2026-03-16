import SwiftUI

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage("confirmChipDeletion") private var confirmChipDeletion = true

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
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("Settings")
    }
}

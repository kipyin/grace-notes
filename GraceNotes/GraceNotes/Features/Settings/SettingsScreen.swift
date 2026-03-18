import SwiftUI
import SwiftData

struct SettingsScreen: View {
    /// Default false to align with SummarizerProvider; first launch uses on-device NL summarization.
    @AppStorage("useCloudSummarization") private var useCloudSummarization = false
    @AppStorage(ReviewInsightsProvider.useAIReviewInsightsKey) private var useAIReviewInsights = false
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var reminderState = ReminderSettingsFlowModel()
    @State private var exportErrorMessage: String?
    @State private var showExportError = false
    @State private var exportFile: ShareableFile?
    @State private var isExportingData = false

    private let dataExportService = JournalDataExportService()

    var body: some View {
        List {
            Section {
                Toggle(String(localized: "Use cloud summarization"), isOn: $useCloudSummarization)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text(String(localized: "Summarization"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(
                    String(
                        localized: """
                        When on, chip labels use an online service for better summaries. \
                        When off, labels use on-device processing only.
                        """
                    )
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Toggle(String(localized: "Use AI review insights"), isOn: $useAIReviewInsights)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textPrimary)
            } header: {
                Text(String(localized: "Review Insights"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(
                    String(
                        localized: """
                        When on, weekly review insights may send your recent journal text \
                        to the configured cloud AI service. \
                        When off, review insights stay on-device.
                        """
                    )
                )
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                NavigationLink {
                    ReminderSettingsDetailScreen(reminderState: reminderState)
                } label: {
                    HStack {
                        Text(String(localized: "Daily reminder"))
                        Spacer()
                        Text(reminderState.summaryText)
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    .font(AppTheme.warmPaperBody)
                }
            } header: {
                Text(String(localized: "Reminders"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(String(localized: "Get one daily local reminder to complete today's entry."))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }

            Section {
                Button(String(localized: "Export journal data (JSON)")) {
                    exportJournalData()
                }
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.accent)
                .disabled(isExportingData)
            } header: {
                Text(String(localized: "Data & Privacy"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.textPrimary)
            } footer: {
                Text(dataPrivacyFooterText)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle(String(localized: "Settings"))
        .sheet(item: $exportFile) { file in
            ShareSheet(activityItems: [file.url])
        }
        .task {
            await reminderState.refreshStatus()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
        }
        .alert(String(localized: "Unable to export data"), isPresented: $showExportError) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? String(localized: "Please try again."))
        }
        .overlay {
            if isExportingData {
                ProgressView(String(localized: "Exporting…"))
                    .font(AppTheme.warmPaperBody)
                    .padding(16)
                    .background(AppTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

}

private extension SettingsScreen {
    var dataPrivacyFooterText: String {
        return String(
            localized: """
            Journal entries stay private to your devices and account. \
            Export creates a full JSON backup you can keep.
            """
        )
    }

    func exportJournalData() {
        guard !isExportingData else { return }
        isExportingData = true
        let container = modelContext.container
        let exportService = dataExportService

        Task {
            do {
                let fileURL = try await Task.detached(priority: .userInitiated) {
                    let backgroundContext = ModelContext(container)
                    return try exportService.exportArchiveFile(context: backgroundContext)
                }.value
                await MainActor.run {
                    exportFile = ShareableFile(url: fileURL)
                    isExportingData = false
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = String(localized: "Unable to export your journal data right now.")
                    showExportError = true
                    isExportingData = false
                }
            }
        }
    }
}

private struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

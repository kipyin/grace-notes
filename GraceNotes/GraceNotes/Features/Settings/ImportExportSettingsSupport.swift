import SwiftUI
import UniformTypeIdentifiers

/// iOS combines multiple `fileImporter` modifiers on one view; host each importer on its own minimal view.
struct JSONImportFileImporterAnchor: View {
    @Binding var isPresented: Bool
    var onComplete: (Result<[URL], Error>) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false,
                onCompletion: onComplete
            )
    }
}

struct ScheduledFolderFileImporterAnchor: View {
    @Binding var isPresented: Bool
    var onComplete: (Result<[URL], Error>) -> Void

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .fileImporter(
                isPresented: $isPresented,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false,
                onCompletion: onComplete
            )
    }
}

struct BackupFolderLinkHint: ViewModifier {
    let showDisabledHint: Bool

    func body(content: Content) -> some View {
        if showDisabledHint {
            content.accessibilityHint(String(localized: "settings.dataPrivacy.importExport.backupFolder.disabledHint"))
        } else {
            content
        }
    }
}

struct ShareableFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

// MARK: - Backup folder file list

struct BackupFolderImportFileListView: View {
    let onSelect: (URL) -> Void

    @State private var files: [URL] = []
    @State private var listError: String?

    var body: some View {
        Group {
            if let listError {
                Text(listError)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .padding()
            } else if files.isEmpty {
                Text(String(localized: "settings.dataPrivacy.importExport.backupFolder.empty"))
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .padding()
            } else {
                List(files, id: \.path) { url in
                    Button {
                        onSelect(url)
                    } label: {
                        Text(url.lastPathComponent)
                            .font(AppTheme.settingsTechnicalBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
                .scrollContentBackground(.hidden)
                .background(AppTheme.settingsBackground)
            }
        }
        .navigationTitle(String(localized: "settings.dataPrivacy.importExport.backupFolder.title"))
        .background(AppTheme.settingsBackground)
        .task {
            load()
        }
    }

    private func load() {
        let folderURL: URL
        do {
            folderURL = try ScheduledBackupPreferences.resolveFolderURL()
        } catch {
            listError = String(localized: "settings.dataPrivacy.importExport.backupFolder.unreachable")
            return
        }
        guard folderURL.startAccessingSecurityScopedResource() else {
            listError = String(localized: "settings.dataPrivacy.importExport.backupFolder.unreachable")
            return
        }
        defer {
            folderURL.stopAccessingSecurityScopedResource()
        }
        do {
            files = try BackupFolderLibrary.listExportFiles(in: folderURL)
        } catch {
            listError = String(localized: "settings.dataPrivacy.importExport.backupFolder.unreachable")
        }
    }
}

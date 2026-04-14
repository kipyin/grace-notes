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
    @State private var isSelecting = false
    @State private var selection = Set<String>()
    @State private var showDeleteConfirm = false
    @State private var deleteErrorMessage: String?
    @State private var showDeleteError = false

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
            } else if isSelecting {
                List(selection: $selection) {
                    ForEach(files, id: \.path) { url in
                        Text(url.lastPathComponent)
                            .font(AppTheme.settingsTechnicalBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                            .tag(url.path)
                    }
                }
                .environment(\.editMode, .constant(.active))
                .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
                .scrollContentBackground(.hidden)
                .background(AppTheme.settingsBackground)
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
        .toolbar {
            if !files.isEmpty, listError == nil {
                if isSelecting {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "common.cancel")) {
                            isSelecting = false
                            selection.removeAll()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(String(localized: "common.delete"), role: .destructive) {
                            showDeleteConfirm = true
                        }
                        .disabled(selection.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button(String(localized: "settings.dataPrivacy.importExport.backupFolder.select")) {
                            isSelecting = true
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            String(localized: "settings.dataPrivacy.importExport.backupFolder.deleteConfirm.title"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                performDelete()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String.localizedStringWithFormat(
                String(localized: "settings.dataPrivacy.importExport.backupFolder.deleteConfirm.messageFormat"),
                selection.count
            ))
        }
        .alert(
            String(localized: "settings.dataPrivacy.importExport.backupFolder.deleteError.title"),
            isPresented: $showDeleteError
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? String(localized: "common.tryAgainGeneric"))
        }
        .task {
            load()
        }
        .onChange(of: files) { _, newFiles in
            let validPaths = Set(newFiles.map(\.path))
            selection = selection.intersection(validPaths)
            if newFiles.isEmpty {
                isSelecting = false
            }
        }
    }

    private func performDelete() {
        let urls = files.filter { selection.contains($0.path) }
        guard !urls.isEmpty else { return }
        do {
            try ScheduledBackupPreferences.withFolderSecurityScopedAccess { _ in
                try BackupFolderLibrary.deleteFiles(at: urls)
            }
        } catch {
            deleteErrorMessage = String(localized: "settings.dataPrivacy.importExport.backupFolder.deleteError.message")
            showDeleteError = true
            return
        }
        selection.removeAll()
        isSelecting = false
        load()
    }

    private func load() {
        do {
            files = try ScheduledBackupPreferences.withFolderSecurityScopedAccess { folderURL in
                try BackupFolderLibrary.listExportFiles(in: folderURL)
            }
            listError = nil
        } catch {
            listError = String(localized: "settings.dataPrivacy.importExport.backupFolder.unreachable")
        }
    }
}

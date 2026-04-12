import SwiftUI
import UIKit

/// Share surface: live preview with redaction, section visibility, style presets, then share bitmap.
struct JournalShareComposerView: View {
    let basePayload: JournalExportPayload
    let onDismiss: () -> Void
    let onShare: (UIImage) -> Void

    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue
    @State private var draft: ShareCardDraft
    @State private var showRenderError = false
    @State private var isShareCommitInProgress = false

    /// Bloom matches main tab chrome (forced light); otherwise inherit system light/dark like the rest of the app.
    private var appPreferredColorScheme: ColorScheme? {
        JournalAppearanceMode.resolveStored(rawValue: journalTodayAppearanceRaw) == .bloom
            ? .light
            : nil
    }

    init(
        basePayload: JournalExportPayload,
        onDismiss: @escaping () -> Void,
        onShare: @escaping (UIImage) -> Void
    ) {
        self.basePayload = basePayload
        self.onDismiss = onDismiss
        self.onShare = onShare
        _draft = State(initialValue: ShareCardDraft.initial(from: basePayload))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sharePreview
                    hintBlock
                    styleSection
                    togglesSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.settingsBackground.ignoresSafeArea())
            .navigationTitle(String(localized: "sharing.composer.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel"), role: .cancel) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "sharing.composer.share")) {
                        commitShare()
                    }
                    .fontWeight(.semibold)
                    .disabled(isShareCommitInProgress)
                    .accessibilityIdentifier("ShareComposerConfirm")
                }
            }
        }
        .toolbarBackground(AppTheme.settingsBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .presentationBackground(AppTheme.settingsBackground)
        .preferredColorScheme(appPreferredColorScheme)
        .alert(String(localized: "sharing.error.unable"), isPresented: $showRenderError) {
            Button(String(localized: "common.dismiss")) {
                showRenderError = false
            }
        } message: {
            Text(String(localized: "sharing.error.createImage"))
        }
    }

    private var previewPayload: ShareRenderPayload {
        ShareRenderPayloadBuilder.build(
            full: basePayload,
            draft: draft,
            includePreviewStubs: true
        )
    }

    private var sharePreview: some View {
        JournalShareCardView(
            payload: previewPayload,
            onLineTap: { identity in
                var next = draft
                next.toggleRedaction(for: identity)
                draft = next
            },
            onSectionToggle: { kind in
                var next = draft
                next.toggleSectionVisibility(kind)
                draft = next
            },
            usesFixedExportWidth: false
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "sharing.composer.previewA11y"))
    }

    private var hintBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "sharing.composer.hintRedact"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "sharing.composer.hintSections"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "sharing.composer.styleHeading"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.settingsTextPrimary)
            HStack(spacing: 10) {
                ForEach(ShareCardStyle.allCases) { style in
                    styleChip(style)
                }
            }
        }
    }

    private var togglesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(String(localized: "sharing.composer.watermark"), isOn: watermarkBinding)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityIdentifier("ShareComposerWatermarkToggle")
            Toggle(String(localized: "sharing.composer.completionBadge"), isOn: completionBadgeBinding)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityIdentifier("ShareComposerBadgeToggle")
            Toggle(String(localized: "sharing.composer.darkShareCard"), isOn: darkShareCardBinding)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityIdentifier("ShareComposerDarkCardToggle")
        }
        .tint(AppTheme.reviewAccent)
    }

    private var watermarkBinding: Binding<Bool> {
        Binding(
            get: { draft.showWatermark },
            set: { newValue in
                var next = draft
                next.showWatermark = newValue
                draft = next
            }
        )
    }

    private var completionBadgeBinding: Binding<Bool> {
        Binding(
            get: { draft.showCompletionBadge },
            set: { newValue in
                var next = draft
                next.showCompletionBadge = newValue
                draft = next
            }
        )
    }

    private var darkShareCardBinding: Binding<Bool> {
        Binding(
            get: { draft.shareCardUsesDarkTheme },
            set: { newValue in
                var next = draft
                next.shareCardUsesDarkTheme = newValue
                draft = next
            }
        )
    }

    private func styleChip(_ style: ShareCardStyle) -> some View {
        let selected = draft.style == style
        return Button {
            draft.style = style
        } label: {
            Text(style.localizedTitle)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(selected ? AppTheme.reviewOnAccent : AppTheme.settingsTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? AppTheme.reviewAccent : AppTheme.settingsPaper)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(AppTheme.shareComposerChipBorder, lineWidth: selected ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func commitShare() {
        guard !isShareCommitInProgress else { return }
        isShareCommitInProgress = true
        defer { isShareCommitInProgress = false }

        let built = ShareRenderPayloadBuilder.build(
            full: basePayload,
            draft: draft,
            includePreviewStubs: false
        )
        guard let image = JournalShareRenderer.renderImage(from: built) else {
            showRenderError = true
            return
        }
        onShare(image)
    }
}

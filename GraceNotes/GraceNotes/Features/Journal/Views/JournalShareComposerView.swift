import SwiftUI
import UIKit

/// Share surface: live preview with redaction, section visibility, style presets, then share bitmap.
struct JournalShareComposerView: View {
    let basePayload: JournalExportPayload
    let onDismiss: () -> Void
    let onShare: (UIImage) -> Void

    @State private var draft: ShareCardDraft
    @State private var showRenderError = false

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
                    .accessibilityIdentifier("ShareComposerConfirm")
                }
            }
        }
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
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "sharing.composer.hintSections"))
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var styleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "sharing.composer.styleHeading"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
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
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityIdentifier("ShareComposerWatermarkToggle")
            Toggle(String(localized: "sharing.composer.completionBadge"), isOn: completionBadgeBinding)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.textPrimary)
                .accessibilityIdentifier("ShareComposerBadgeToggle")
        }
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

    private func styleChip(_ style: ShareCardStyle) -> some View {
        let selected = draft.style == style
        return Button {
            draft.style = style
        } label: {
            Text(style.localizedTitle)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(selected ? Color.white : AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? AppTheme.accent : AppTheme.paper)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(AppTheme.inputBorder, lineWidth: selected ? 0 : 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func commitShare() {
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

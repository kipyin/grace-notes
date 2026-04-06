import Foundation
import SwiftUI

struct JournalShareCardView: View {
    let payload: ShareRenderPayload
    var onLineTap: ((ShareLineIdentity) -> Void)?
    var onSectionToggle: ((ShareSectionKind) -> Void)?
    private let usesFixedExportWidth: Bool

    private static let cardWidth: CGFloat = 400
    private static let padding: CGFloat = 24

    init(
        payload: ShareRenderPayload,
        onLineTap: ((ShareLineIdentity) -> Void)? = nil,
        onSectionToggle: ((ShareSectionKind) -> Void)? = nil,
        usesFixedExportWidth: Bool = true
    ) {
        self.payload = payload
        self.onLineTap = onLineTap
        self.onSectionToggle = onSectionToggle
        self.usesFixedExportWidth = usesFixedExportWidth
    }

    var body: some View {
        Group {
            if usesFixedExportWidth {
                cardColumn
                    .frame(width: Self.cardWidth)
            } else {
                cardColumn
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(JournalShareCardView.padding)
        .background {
            payload.style.cardBackgroundLayer()
        }
        .shadow(
            color: payload.style.showsPaperShadow ? AppTheme.border.opacity(0.42) : .clear,
            radius: payload.style.showsPaperShadow ? 10 : 0,
            y: payload.style.showsPaperShadow ? 4 : 0
        )
        .preferredColorScheme(.light)
        .environment(\.todayJournalPalette, .standard)
    }

    private var cardColumn: some View {
        VStack(alignment: .leading, spacing: 20) {
            if payload.style.showsTopAccentRule {
                accentRule(height: payload.style.topAccentHeight())
            }

            dateBlock

            ForEach(Array(payload.sections.enumerated()), id: \.offset) { index, section in
                if payload.style.showsSectionDividers, index > 0 {
                    Rectangle()
                        .fill(AppTheme.border.opacity(0.55))
                        .frame(height: 1)
                }
                sectionBlock(section)
            }

            if payload.showWatermark {
                Text(String(localized: "sharing.card.footer"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(payload.style.footerInk)
            }
        }
    }

    @ViewBuilder
    private var dateBlock: some View {
        let style = payload.style
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(payload.dateFormatted)
                    .font(style.dateFont)
                    .foregroundStyle(style.bodyInk)
                    .fixedSize(horizontal: false, vertical: true)
                if payload.showCompletionBadge {
                    Spacer(minLength: 8)
                    completionBadge
                }
            }
            if style.showsAccentRuleUnderDate {
                accentRule(height: style.topAccentHeight())
            }
        }
    }

    private var completionBadge: some View {
        JournalCompletionPill(completionLevel: payload.completionLevel, celebratingLevel: nil)
            .scaleEffect(0.92)
            .accessibilityLabel(String(localized: "sharing.a11y.completionBadge"))
    }

    private func accentRule(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(AppTheme.accent.opacity(payload.style.topAccentOpacity()))
            .frame(height: height)
    }

    @ViewBuilder
    private func sectionBlock(_ section: ShareSectionRenderModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(section)
            ForEach(Array(section.lines.enumerated()), id: \.offset) { _, item in
                lineRow(item)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ section: ShareSectionRenderModel) -> some View {
        let style = payload.style
        if let onSectionToggle {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(section.title)
                    .font(style.sectionTitleFont)
                    .foregroundStyle(style.sectionTitleInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    onSectionToggle(section.kind)
                } label: {
                    Image(systemName: section.isPreviewStub ? "plus" : "xmark")
                        .font(.caption.weight(.regular))
                        .foregroundStyle(style.sectionControlInk)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    section.isPreviewStub
                    ? String(localized: "sharing.a11y.sectionRestore")
                    : String(localized: "sharing.a11y.sectionExclude")
                )
            }
        } else {
            Text(section.title)
                .font(style.sectionTitleFont)
                .foregroundStyle(style.sectionTitleInk)
        }
    }

    @ViewBuilder
    private func lineRow(_ item: ShareLineDisplayItem) -> some View {
        let ink = payload.style.bodyInk
        switch item {
        case .visible(let display, let identity):
            if let onLineTap {
                Button {
                    onLineTap(identity)
                } label: {
                    Text(display)
                        .font(payload.style.bodyFont)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(display)
                .accessibilityHint(String(localized: "sharing.a11y.lineTapToHide"))
            } else {
                Text(display)
                    .font(payload.style.bodyFont)
                    .foregroundStyle(ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .redacted(let identity):
            if let onLineTap {
                Button {
                    onLineTap(identity)
                } label: {
                    redactionBar
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "sharing.a11y.lineRedacted"))
                .accessibilityHint(String(localized: "sharing.a11y.lineTapToShow"))
            } else {
                redactionBar
            }
        case .previewStub(let message):
            Text(message)
                .font(payload.style.metaFont)
                .italic()
                .foregroundStyle(payload.style.stubInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(String(localized: "sharing.a11y.sectionStub"))
        }
    }

    private var redactionBar: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(AppTheme.textMuted.opacity(0.35))
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(onLineTap == nil)
    }
}

import Foundation
import SwiftUI

struct JournalShareCardView: View {
    let payload: ShareRenderPayload
    var onLineTap: ((ShareLineIdentity) -> Void)?
    var onSectionToggle: ((ShareSectionKind) -> Void)?
    private let usesFixedExportWidth: Bool

    private static let cardWidth: CGFloat = 448
    private static let padding: CGFloat = 24

    private var script: ShareTypographyScript { payload.typographyScript }

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
        let style = payload.style
        return Group {
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
            style.cardBackgroundLayer()
        }
        .shadow(color: style.cardShadowColor, radius: style.cardShadowRadius, x: 0, y: style.cardShadowOffsetY)
        .preferredColorScheme(.light)
        .environment(\.todayJournalPalette, .standard)
    }

    private var cardColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if payload.style.showsTopAccentRule {
                topAccentBar
                    .padding(.bottom, 24)
            }

            dateBlock
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 24) {
                ForEach(Array(payload.sections.enumerated()), id: \.offset) { index, section in
                    if payload.style.showsSectionDividers, index > 0 {
                        Rectangle()
                            .fill(payload.style.sectionDividerColor)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                    sectionBlock(section)
                }
            }

            if payload.showWatermark {
                Text(String(localized: "sharing.card.footer"))
                    .font(payload.style.metaFont(for: script))
                    .foregroundStyle(payload.style.footerInk)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 40)
            }
        }
    }

    @ViewBuilder
    private var dateBlock: some View {
        let style = payload.style
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(payload.dateFormatted)
                .font(style.dateFont(for: script))
                .tracking(style.dateTracking(for: script) ?? 0)
                .foregroundStyle(style.bodyInk)
                .fixedSize(horizontal: false, vertical: true)
            if payload.showCompletionBadge {
                Spacer(minLength: 8)
                ShareCompletionChip(completionLevel: payload.completionLevel, style: style)
            }
        }
    }

    private var topAccentBar: some View {
        Capsule(style: .continuous)
            .fill(payload.style.topAccentGradient())
            .frame(height: payload.style.topAccentHeight())
            .frame(maxWidth: .infinity)
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
        let titleCase = style.sectionTitleTextCase(for: script)
        if let onSectionToggle {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(section.title)
                    .font(style.sectionTitleFont(for: script))
                    .foregroundStyle(style.sectionTitleInk)
                    .textCase(titleCase)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    onSectionToggle(section.kind)
                } label: {
                    Text(section.isPreviewStub ? "+" : "×")
                        .font(.system(size: 13, weight: .regular))
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
                .font(style.sectionTitleFont(for: script))
                .foregroundStyle(style.sectionTitleInk)
                .textCase(titleCase)
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
                        .font(payload.style.bodyFont(for: script))
                        .lineSpacing(3)
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(display)
                .accessibilityHint(String(localized: "sharing.a11y.lineTapToHide"))
            } else {
                Text(display)
                    .font(payload.style.bodyFont(for: script))
                    .lineSpacing(3)
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
                .font(payload.style.metaFont(for: script))
                .italic()
                .foregroundStyle(payload.style.stubInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(String(localized: "sharing.a11y.sectionStub"))
        }
    }

    private var redactionBar: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(payload.style.redactionBarColor)
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(onLineTap == nil)
    }
}

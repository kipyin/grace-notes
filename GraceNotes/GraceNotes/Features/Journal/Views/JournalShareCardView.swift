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
        if payload.cardSurface.useLightCardPalette {
            cardChrome
                .preferredColorScheme(.light)
        } else {
            cardChrome
                .preferredColorScheme(.dark)
        }
    }
}

private enum ShareLineRowID: Hashable {
    case line(ShareLineIdentity)
    case previewStub(section: ShareSectionKind, index: Int)
}

private struct IdentifiedShareLineRow: Identifiable {
    let id: ShareLineRowID
    let item: ShareLineDisplayItem
}

private extension JournalShareCardView {
    var surface: ShareCardSurface { payload.cardSurface }

    var cardChrome: some View {
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
            surface.cardBackground()
        }
        .shadow(
            color: surface.cardShadowColor,
            radius: style.cardShadowRadius,
            x: 0,
            y: style.cardShadowOffsetY
        )
        .environment(\.todayJournalPalette, .standard)
    }

    var cardColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            if payload.style.showsTopAccentRule {
                topAccentBar
                    .padding(.bottom, 24)
            }

            dateBlock
                .padding(.bottom, 32)

            VStack(alignment: .leading, spacing: 24) {
                // Invariant: each `ShareSectionKind` appears at most once in `payload.sections`
                // (enforced by `ShareRenderPayloadBuilder`); duplicate kinds would break `ForEach` identity.
                ForEach(Array(payload.sections.enumerated()), id: \.element.kind) { index, section in
                    if payload.style.showsSectionDividers, index > 0 {
                        Rectangle()
                            .fill(surface.sectionDividerColor)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                    }
                    sectionBlock(section)
                }
            }

            if payload.showWatermark {
                Text(String(localized: "sharing.card.footer"))
                    .font(payload.style.metaFont(for: script))
                    .foregroundStyle(surface.footerInk)
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
                .foregroundStyle(surface.bodyInk)
                .fixedSize(horizontal: false, vertical: true)
            if payload.showCompletionBadge {
                Spacer(minLength: 8)
                ShareCompletionChip(
                    completionLevel: payload.completionLevel,
                    surface: surface
                )
            }
        }
    }

    var topAccentBar: some View {
        Capsule(style: .continuous)
            .fill(payload.style.topAccentGradient())
            .frame(height: payload.style.topAccentHeight())
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    func sectionBlock(_ section: ShareSectionRenderModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(section)
            ForEach(identifiedLines(for: section)) { row in
                lineRow(row.item)
            }
        }
    }

    func identifiedLines(for section: ShareSectionRenderModel) -> [IdentifiedShareLineRow] {
        section.lines.enumerated().map { index, item in
            IdentifiedShareLineRow(
                id: shareLineRowID(section: section, item: item, index: index),
                item: item
            )
        }
    }

    func shareLineRowID(
        section: ShareSectionRenderModel,
        item: ShareLineDisplayItem,
        index: Int
    ) -> ShareLineRowID {
        switch item {
        case .visible(_, let identity), .redacted(let identity):
            return .line(identity)
        case .previewStub:
            return .previewStub(section: section.kind, index: index)
        }
    }

    @ViewBuilder
    func sectionHeader(_ section: ShareSectionRenderModel) -> some View {
        let style = payload.style
        let titleCase = style.sectionTitleTextCase(for: script)
        if let onSectionToggle {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(section.title)
                    .font(style.sectionTitleFont(for: script))
                    .foregroundStyle(surface.sectionTitleInk)
                    .textCase(titleCase)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button {
                    onSectionToggle(section.kind)
                } label: {
                    Text(section.isPreviewStub ? "+" : "×")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(surface.sectionControlInk)
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
                .foregroundStyle(surface.sectionTitleInk)
                .textCase(titleCase)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    func lineRow(_ item: ShareLineDisplayItem) -> some View {
        let ink = surface.bodyInk
        switch item {
        case .visible(let display, let identity):
            visibleShareLine(display: display, identity: identity, ink: ink)
        case .redacted(let identity):
            redactedShareLine(identity: identity)
        case .previewStub(let message):
            stubShareLine(message: message)
        }
    }

    @ViewBuilder
    private func visibleShareLine(display: String, identity: ShareLineIdentity, ink: Color) -> some View {
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
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func redactedShareLine(identity: ShareLineIdentity) -> some View {
        if let onLineTap {
            Button {
                onLineTap(identity)
            } label: {
                redactionBarShape
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "sharing.a11y.lineRedacted"))
            .accessibilityHint(String(localized: "sharing.a11y.lineTapToShow"))
        } else {
            redactionBarShape
                .accessibilityLabel(String(localized: "sharing.a11y.lineRedacted"))
        }
    }

    private func stubShareLine(message: String) -> some View {
        Text(message)
            .font(payload.style.metaFont(for: script))
            .italic()
            .foregroundStyle(surface.stubInk)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var redactionBarShape: some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(surface.redactionBarColor)
            .frame(height: 18)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

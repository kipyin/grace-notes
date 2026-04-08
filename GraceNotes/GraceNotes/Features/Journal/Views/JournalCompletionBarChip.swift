import SwiftUI

/// Compact completion control for the navigation bar: **capsule** fill (tier colors).
///
/// Shadows read poorly in toolbar chrome on **iOS 17–18** (clip / double edge), so the chip stays flat there.
/// On **iOS 26+**, with ``ToolbarItem/sharedBackgroundVisibility(_:)`` set to ``Visibility/hidden``, add a
/// tier-aware shadow stack so the chip reads clearly above the bar.
struct JournalCompletionBarChip: View {
    /// Sticky chip stays one line; cap text scaling at the largest standard Dynamic Type (not accessibility buckets).
    private static let toolbarChipDynamicTypeRange = DynamicTypeSize.xSmall ... DynamicTypeSize.xxxLarge

    /// Capsule width for expanded title; wide enough for CJK growth-stage strings at capped Dynamic Type.
    private static let expandedTitleMaxWidth: CGFloat = 400

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale
    @Environment(\.todayJournalPalette) private var palette

    /// Fixed bar height from ``JournalScreen/journalToolbarControlHeight`` (matched to the share symbol row).
    let toolbarControlHeight: CGFloat

    let completionLevel: JournalCompletionLevel
    let gratitudesCount: Int
    let needsCount: Int
    let peopleCount: Int
    /// When `false`, show only the tier symbol (toolbar stays compact).
    let showsCompletionTitle: Bool
    let onCollapseExpandTap: () -> Void
    let onShowCompletionInfo: () -> Void

    /// Matches the trailing share symbol row (Outfit 17pt headline scale).
    @ScaledMetric(relativeTo: .headline) private var tierIconLength: CGFloat = 24

    /// After a long-press succeeds, UIKit may still deliver the `Button` action on finger-up; skip one cycle.
    @State private var suppressNextCollapseExpandTap = false

    /// Icon-only: slightly shorter than the share row and padded so width tracks height (near-circular capsule).
    private var collapsedChipHeight: CGFloat {
        max(toolbarControlHeight - 1, tierIconLength + 8)
    }

    /// Match toolbar row height in both states so expand/collapse does not animate 46↔47 (see debug `h` flips).
    private var chipHeight: CGFloat { toolbarControlHeight }

    private var iconTitleGap: CGFloat { AppTheme.spacingTight }

    /// Centers the row in the retracted square accounting for a **constant** icon–title gap (spacing no longer 0↔8).
    private var chipLeadingInset: CGFloat {
        max(0, (collapsedChipHeight - tierIconLength - iconTitleGap) / 2)
    }

    /// Trailing inset: tighter when retracted (circle); sheet-style 14pt when expanded.
    private var chipTrailingInset: CGFloat {
        showsCompletionTitle ? 14 : chipLeadingInset
    }

    var body: some View {
        Button {
            if suppressNextCollapseExpandTap {
                suppressNextCollapseExpandTap = false
                return
            }
            onCollapseExpandTap()
        } label: {
            chipLabelContent
                // Logs showed intermittent w=40 with h=46 when collapsed (`maxWidth` only) — not square, reads as
                // a tall pill and lets the toolbar compress the chip. Pin collapsed width with min=max; expanded
                // uses no min width (avoids earlier min+animated-max oscillation when expanded).
                .frame(
                    minWidth: showsCompletionTitle ? nil : collapsedChipHeight,
                    maxWidth: showsCompletionTitle ? .infinity : collapsedChipHeight,
                    alignment: .leading
                )
                .frame(height: chipHeight)
                .background {
                    chipCapsuleBackground
                }
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        // #region agent log
        #if DEBUG
        .background {
            GeometryReader { geo in
                Color.clear
                    .onChange(of: geo.size) { _, size in
                        StickyChipAgentDebug.log(
                            hypothesisId: "C",
                            location: "JournalCompletionBarChip.labelGeometry",
                            message: "label_size",
                            data: [
                                "w": String(format: "%.2f", size.width),
                                "h": String(format: "%.2f", size.height),
                                "expanded": "\(showsCompletionTitle)",
                                "layout": "constGap_fixedHeightToolbar"
                            ]
                        )
                    }
            }
        }
        #endif
        // #endregion
        .dynamicTypeSize(Self.toolbarChipDynamicTypeRange)
        /// Always horizontal fixedSize so the toolbar cannot squeeze the chip to ~40pt (see debug oscillation 46→40).
        /// Collapsed width is enforced by ``frame(minWidth:maxWidth:)`` above.
        .fixedSize(horizontal: true, vertical: true)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.45).onEnded { _ in
                suppressNextCollapseExpandTap = true
                onShowCompletionInfo()
            }
        )
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(String(localized: "accessibility.stickyCompletionChipHint"))
        .accessibilityAction(named: String(localized: "accessibility.stickyCompletionChipShowDetailsAction")) {
            onShowCompletionInfo()
        }
        .onChange(of: showsCompletionTitle) { _, newValue in
            // #region agent log
            #if DEBUG
            StickyChipAgentDebug.log(
                hypothesisId: "D",
                location: "JournalCompletionBarChip.onChange.expanded",
                message: "showsCompletionTitle_changed",
                data: [
                    "showsTitle": "\(newValue)",
                    "collapsedH": "\(collapsedChipHeight)",
                    "toolbarH": "\(toolbarControlHeight)",
                    "leadInset": String(format: "%.2f", chipLeadingInset),
                    "trailInset": String(format: "%.2f", chipTrailingInset),
                    "iconTitleGap": String(format: "%.2f", iconTitleGap)
                ]
            )
            StickyChipAgentDebug.log(
                hypothesisId: "J",
                location: "JournalCompletionBarChip.onChange.expanded",
                message: "leading_frame_alignment",
                data: ["blurPulse": "removed", "collapsedCenter": "constGap_toolbarH"]
            )
            #endif
            // #endregion
        }
    }

    /// One stable row: no Spacer branch so expand/collapse interpolate the same subviews.
    private var chipLabelContent: some View {
        HStack(alignment: .center, spacing: iconTitleGap) {
            tierIcon
            Text(completionTitle)
                .font(AppTheme.warmPaperToolbarChipTitle)
                .lineLimit(1)
                .minimumScaleFactor(toolbarCompletionTitleMinimumScaleFactor)
                .frame(maxWidth: showsCompletionTitle ? Self.expandedTitleMaxWidth : 0, alignment: .leading)
                .clipped()
                // Inherit ``JournalScreenLayout/stickyChipMorphAnimation`` from ``withAnimation`` on expand/collapse.
                .opacity(showsCompletionTitle ? 1 : 0)
                .accessibilityHidden(true)
                .allowsHitTesting(showsCompletionTitle)
        }
        .foregroundStyle(labelColor)
        .padding(.leading, chipLeadingInset)
        .padding(.trailing, chipTrailingInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: .infinity)
    }

    private var tierIcon: some View {
        Image(ReviewRhythmFormatting.assetName(for: completionLevel))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: tierIconLength, height: tierIconLength)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var chipCapsuleBackground: some View {
        let capsule = Capsule(style: .continuous)
            .fill(JournalCompletionTierSurface.backgroundFill(for: completionLevel, palette: palette))

        if #available(iOS 26, *) {
            if reduceTransparency {
                capsule
            } else {
                capsule
                    .shadow(color: Color.black.opacity(0.14), radius: 12, x: 0, y: 6)
                    .shadow(
                        color: AppTheme.reviewRhythmPillShadow(for: completionLevel),
                        radius: 5,
                        x: 0,
                        y: 3
                    )
            }
        } else {
            capsule
        }
    }

    /// Latin titles stay short; CJK growth-stage strings are wider. Shrinking them made the chip read
    /// shorter than the trailing share control—prefer full type size and a wider capsule.
    private var toolbarCompletionTitleMinimumScaleFactor: CGFloat {
        switch locale.language.languageCode?.identifier {
        case "zh", "ja", "ko":
            return 1.0
        default:
            return 0.78
        }
    }

    private var completionTitle: String {
        CompletionBadgeInfo.matching(completionLevel).title
    }

    private var accessibilityLabelText: String {
        let statusName = completionTitle
        let format = String(localized: "journal.share.sectionCountsSentence")
        return String(format: format, locale: Locale.current, statusName, gratitudesCount, needsCount, peopleCount)
    }

    private var labelColor: Color {
        switch completionLevel {
        case .soil:
            return palette.textMuted
        case .sprout:
            return palette.quickCheckInText
        case .twig, .leaf:
            return palette.standardText
        case .bloom:
            return palette.fullText
        }
    }

}

// #region agent log
#if DEBUG
enum StickyChipAgentDebug {
    private static let ingestURL = URL(
        string: "http://127.0.0.1:7480/ingest/6b1dfaaa-db34-40e4-8b30-a71cc1c45d32"
    )!

    static func log(hypothesisId: String, location: String, message: String, data: [String: String] = [:]) {
        let payload: [String: Any] = [
            "sessionId": "6cf017",
            "runId": "const-gap-v1",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": data,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("6cf017", forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }
}
#endif
// #endregion

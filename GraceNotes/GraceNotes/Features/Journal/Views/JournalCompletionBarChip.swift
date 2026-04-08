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

    private enum MorphBlurPulse {
        static let peakRadius: CGFloat = 5
        static let easeInSeconds: TimeInterval = 0.1
        static let easeOutSeconds: TimeInterval = 0.26
    }

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

    @State private var morphBlurRadius: CGFloat = 0
    @State private var morphBlurPulseTask: Task<Void, Never>?

    /// Icon-only: slightly shorter than the share row and padded so width tracks height (near-circular capsule).
    private var collapsedChipHeight: CGFloat {
        max(toolbarControlHeight - 1, tierIconLength + 8)
    }

    private var chipHeight: CGFloat {
        showsCompletionTitle ? toolbarControlHeight : collapsedChipHeight
    }

    private var collapsedHorizontalPadding: CGFloat {
        max(0, (collapsedChipHeight - tierIconLength) / 2)
    }

    var body: some View {
        Button {
            if suppressNextCollapseExpandTap {
                suppressNextCollapseExpandTap = false
                return
            }
            onCollapseExpandTap()
        } label: {
            // `.center` here pinned the expanded HStack by its midpoint, overlapping icon and title.
            ZStack(alignment: .leading) {
                collapsedChipLabel
                    .frame(maxWidth: .infinity)
                    .opacity(showsCompletionTitle ? 0 : 1)
                    .allowsHitTesting(!showsCompletionTitle)
                expandedChipLabel
                    .opacity(showsCompletionTitle ? 1 : 0)
                    .allowsHitTesting(showsCompletionTitle)
            }
            // Single width constraint: post-fix logs showed 46→97→46 width while `expanded` was still true
            // (minWidth + animated maxWidth infinity produced transient collapsed-width layouts mid-expand).
            .frame(width: showsCompletionTitle ? nil : collapsedChipHeight)
            .frame(height: chipHeight)
            .blur(radius: morphBlurRadius)
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
                                "blur": "\(morphBlurRadius)"
                            ]
                        )
                    }
            }
        }
        .onChange(of: morphBlurRadius) { _, radius in
            StickyChipAgentDebug.log(
                hypothesisId: "B",
                location: "JournalCompletionBarChip.blur",
                message: "morphBlurRadius",
                data: ["radius": String(format: "%.2f", radius)]
            )
        }
        #endif
        // #endregion
        .dynamicTypeSize(Self.toolbarChipDynamicTypeRange)
        /// Avoid ``fixedSize(horizontal: true)`` here: it fights animated min/max width and can make the
        /// leading toolbar item re-center each frame (visible “slide” when width snaps ~97→46 pt per logs).
        .fixedSize(horizontal: false, vertical: true)
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
            scheduleMorphBlurPulseIfAllowed()
            // #region agent log
            #if DEBUG
            StickyChipAgentDebug.log(
                hypothesisId: "D",
                location: "JournalCompletionBarChip.onChange.expanded",
                message: "showsCompletionTitle_changed",
                data: [
                    "showsTitle": "\(newValue)",
                    "collapsedH": "\(collapsedChipHeight)",
                    "toolbarH": "\(toolbarControlHeight)"
                ]
            )
            #endif
            // #endregion
        }
        .onDisappear {
            morphBlurPulseTask?.cancel()
            morphBlurPulseTask = nil
            morphBlurRadius = 0
        }
    }

    private var collapsedChipLabel: some View {
        HStack {
            Spacer(minLength: 0)
            tierIcon
            Spacer(minLength: 0)
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, collapsedHorizontalPadding)
        .frame(maxHeight: .infinity)
    }

    private var expandedChipLabel: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingTight) {
            tierIcon
            Text(completionTitle)
                .font(AppTheme.warmPaperToolbarChipTitle)
                .lineLimit(1)
                .minimumScaleFactor(toolbarCompletionTitleMinimumScaleFactor)
                .frame(maxWidth: Self.expandedTitleMaxWidth, alignment: .leading)
                .accessibilityHidden(true)
        }
        .foregroundStyle(labelColor)
        .padding(.horizontal, 14)
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

    private func scheduleMorphBlurPulseIfAllowed() {
        morphBlurPulseTask?.cancel()
        morphBlurPulseTask = nil
        guard !reduceMotion else {
            morphBlurRadius = 0
            return
        }
        morphBlurPulseTask = Task { @MainActor in
            // Let width/layout settle before blur (same window as bad 46pt frames in logs).
            try? await Task.sleep(for: .milliseconds(85))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: MorphBlurPulse.easeInSeconds)) {
                morphBlurRadius = MorphBlurPulse.peakRadius
            }
            try? await Task.sleep(for: .seconds(MorphBlurPulse.easeInSeconds))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: MorphBlurPulse.easeOutSeconds)) {
                morphBlurRadius = 0
            }
            morphBlurPulseTask = nil
        }
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
            "runId": "post-fix-2",
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

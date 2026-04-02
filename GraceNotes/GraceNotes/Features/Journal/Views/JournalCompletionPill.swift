import SwiftUI

/// Shared completion status pill for the journal date section header.
struct JournalCompletionPill: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.todayJournalPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var completionTierIconLength: CGFloat = 17

    let completionLevel: JournalCompletionLevel
    let celebratingLevel: JournalCompletionLevel?
    var morphSource: Bool = false
    var morphNamespace: Namespace.ID?
    var morphAccentColor: Color = .clear
    var morphBloomProgress: CGFloat = 0

    var body: some View {
        pillLabel
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppTheme.spacingRegular)
            .padding(.vertical, AppTheme.spacingTight)
            .frame(minHeight: 44)
            .background(pillBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(borderColor(for: completionLevel), lineWidth: 1)
            )
            .scaleEffect(scaleFactor(for: completionLevel, isCelebrating: isCelebrating))
            .shadow(
                color: shadowColor(for: completionLevel, isCelebrating: isCelebrating),
                radius: shadowRadius(for: completionLevel, isCelebrating: isCelebrating),
                x: 0,
                y: isCelebrating && !reduceTransparency ? 2 : 0
            )
            .animation(
                reduceMotion ? nil : AppTheme.celebrationPulseAnimation(for: completionLevel),
                value: isCelebrating
            )
            .overlay {
                if morphSource {
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                        .stroke(
                            morphAccentColor.opacity(0.32 * morphBloomProgress),
                            lineWidth: 1.6
                        )
                        .scaleEffect(1.02 + (0.08 * (1 - morphBloomProgress)))
                }
            }
            .opacity(morphSource && !reduceMotion ? 0.92 : 1)
            .accessibilityElement(children: .combine)
    }

    private var isCelebrating: Bool {
        celebratingLevel == completionLevel && completionLevel != .soil
    }

    private var pillLabel: some View {
        HStack(alignment: .center, spacing: AppTheme.spacingTight) {
            Image(ReviewRhythmFormatting.assetName(for: completionLevel))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: completionTierIconLength, height: completionTierIconLength)
                .accessibilityHidden(true)
            Text(localizedCompletionTitle)
                .font(AppTheme.warmPaperMetaEmphasis)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(completionLabelForeground)
    }

    private var localizedCompletionTitle: String {
        switch completionLevel {
        case .soil:
            String(localized: "Empty")
        case .sprout:
            String(localized: "Started")
        case .twig:
            String(localized: "Growing")
        case .leaf:
            String(localized: "Balanced")
        case .bloom:
            String(localized: "Full")
        }
    }

    private var completionLabelForeground: AnyShapeStyle {
        switch completionLevel {
        case .soil:
            AnyShapeStyle(palette.textMuted)
        case .sprout:
            AnyShapeStyle(palette.quickCheckInText)
        case .twig, .leaf:
            AnyShapeStyle(palette.standardText)
        case .bloom:
            AnyShapeStyle(palette.fullText)
        }
    }

    @ViewBuilder
    private var pillBackground: some View {
        let base = RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
            .fill(backgroundFill(for: completionLevel))

        if let morphNamespace, morphSource, !reduceMotion {
            base.matchedGeometryEffect(
                id: "completionInfoMorphSurface",
                in: morphNamespace,
                properties: .frame,
                anchor: .topLeading,
                isSource: true
            )
        } else {
            base
        }
    }

    private func backgroundFill(for level: JournalCompletionLevel) -> AnyShapeStyle {
        switch level {
        case .soil:
            return AnyShapeStyle(palette.background)
        case .sprout:
            return AnyShapeStyle(palette.quickCheckInBackground)
        case .twig, .leaf:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [palette.standardBackgroundStart, palette.standardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .bloom:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [palette.fullBackgroundStart, palette.fullBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func borderColor(for level: JournalCompletionLevel) -> Color {
        switch level {
        case .soil:
            return palette.border
        case .sprout:
            return palette.quickCheckInBorder
        case .twig, .leaf:
            return palette.standardBorder
        case .bloom:
            return palette.fullBorder
        }
    }

    private func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .soil:
            return 1.0
        case .sprout:
            return 1.008
        case .twig:
            return 1.01
        case .leaf:
            return 1.015
        case .bloom:
            return 1.02
        }
    }

    private func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .soil:
            return .clear
        case .sprout:
            return palette.quickCheckInGlow.opacity(0.25)
        case .twig, .leaf:
            return palette.standardGlow.opacity(0.4)
        case .bloom:
            return palette.fullGlow.opacity(0.48)
        }
    }

    private func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .soil:
            return 0
        case .sprout:
            return 4
        case .twig:
            return 6
        case .leaf:
            return 8
        case .bloom:
            return 11
        }
    }
}

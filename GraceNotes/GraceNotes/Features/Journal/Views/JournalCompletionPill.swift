import SwiftUI

/// Shared completion status pill for the journal date section header.
struct JournalCompletionPill: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let completionLevel: JournalCompletionLevel
    let celebratingLevel: JournalCompletionLevel?
    var morphSource: Bool = false
    var morphNamespace: Namespace.ID?
    var morphAccentColor: Color = .clear
    var morphBloomProgress: CGFloat = 0

    var body: some View {
        pillLabel
            .font(AppTheme.warmPaperMetaEmphasis)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
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

    @ViewBuilder
    private var pillLabel: some View {
        switch completionLevel {
        case .soil:
            Label(String(localized: "Soil"), systemImage: "circle.dotted")
                .foregroundStyle(AppTheme.journalTextMuted)
        case .seed:
            Label(String(localized: "Seed"), systemImage: "leaf.fill")
                .foregroundStyle(AppTheme.journalQuickCheckInText)
        case .ripening:
            Label(String(localized: "Ripening"), systemImage: "leaf.circle.fill")
                .foregroundStyle(AppTheme.journalStandardText)
        case .harvest:
            Label(
                String(localized: "Harvest"),
                systemImage: celebratingLevel == .harvest
                    ? "sparkles.rectangle.stack.fill"
                    : "sparkles.rectangle.stack"
            )
            .foregroundStyle(AppTheme.journalStandardText)
        case .abundance:
            Label(
                String(localized: "Abundance"),
                systemImage: celebratingLevel == .abundance
                    ? "checkmark.circle.fill"
                    : "checkmark.circle"
            )
            .foregroundStyle(AppTheme.journalFullText)
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
            return AnyShapeStyle(AppTheme.journalBackground)
        case .seed:
            return AnyShapeStyle(AppTheme.journalQuickCheckInBackground)
        case .ripening, .harvest:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalStandardBackgroundStart, AppTheme.journalStandardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .abundance:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalFullBackgroundStart, AppTheme.journalFullBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
    }

    private func borderColor(for level: JournalCompletionLevel) -> Color {
        switch level {
        case .soil:
            return AppTheme.journalBorder
        case .seed:
            return AppTheme.journalQuickCheckInBorder
        case .ripening, .harvest:
            return AppTheme.journalStandardBorder
        case .abundance:
            return AppTheme.journalFullBorder
        }
    }

    private func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .soil:
            return 1.0
        case .seed:
            return 1.008
        case .ripening:
            return 1.01
        case .harvest:
            return 1.015
        case .abundance:
            return 1.02
        }
    }

    private func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .soil:
            return .clear
        case .seed:
            return AppTheme.journalQuickCheckInGlow.opacity(0.25)
        case .ripening, .harvest:
            return AppTheme.journalStandardGlow.opacity(0.4)
        case .abundance:
            return AppTheme.journalFullGlow.opacity(0.48)
        }
    }

    private func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .soil:
            return 0
        case .seed:
            return 4
        case .ripening:
            return 6
        case .harvest:
            return 8
        case .abundance:
            return 11
        }
    }
}

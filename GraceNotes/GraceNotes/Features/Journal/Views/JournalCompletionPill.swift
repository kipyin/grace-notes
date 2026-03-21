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
        celebratingLevel == completionLevel && completionLevel != .none
    }

    @ViewBuilder
    private var pillLabel: some View {
        switch completionLevel {
        case .quickCheckIn:
            Label(String(localized: "Seed"), systemImage: "leaf.fill")
                .foregroundStyle(AppTheme.journalQuickCheckInText)
        case .standardReflection:
            Label(
                String(localized: "Harvest"),
                systemImage: celebratingLevel == .standardReflection
                    ? "sparkles.rectangle.stack.fill"
                    : "sparkles.rectangle.stack"
            )
            .foregroundStyle(AppTheme.journalStandardText)
        case .fullFiveCubed:
            Label(
                String(localized: "Harvest"),
                systemImage: celebratingLevel == .fullFiveCubed
                    ? "checkmark.circle.fill"
                    : "checkmark.circle"
            )
            .foregroundStyle(AppTheme.journalFullText)
        case .none:
            Label(String(localized: "In Progress"), systemImage: "pencil.circle")
                .foregroundStyle(AppTheme.journalTextMuted)
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
        case .quickCheckIn:
            return AnyShapeStyle(AppTheme.journalQuickCheckInBackground)
        case .standardReflection:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalStandardBackgroundStart, AppTheme.journalStandardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .fullFiveCubed:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalFullBackgroundStart, AppTheme.journalFullBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .none:
            return AnyShapeStyle(AppTheme.journalBackground)
        }
    }

    private func borderColor(for level: JournalCompletionLevel) -> Color {
        switch level {
        case .quickCheckIn:
            return AppTheme.journalQuickCheckInBorder
        case .standardReflection:
            return AppTheme.journalStandardBorder
        case .fullFiveCubed:
            return AppTheme.journalFullBorder
        case .none:
            return AppTheme.journalBorder
        }
    }

    private func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .quickCheckIn:
            return 1.008
        case .standardReflection:
            return 1.015
        case .fullFiveCubed:
            return 1.02
        case .none:
            return 1.0
        }
    }

    private func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .quickCheckIn:
            return AppTheme.journalQuickCheckInGlow.opacity(0.25)
        case .standardReflection:
            return AppTheme.journalStandardGlow.opacity(0.4)
        case .fullFiveCubed:
            return AppTheme.journalFullGlow.opacity(0.48)
        case .none:
            return .clear
        }
    }

    private func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .quickCheckIn:
            return 4
        case .standardReflection:
            return 8
        case .fullFiveCubed:
            return 11
        case .none:
            return 0
        }
    }
}

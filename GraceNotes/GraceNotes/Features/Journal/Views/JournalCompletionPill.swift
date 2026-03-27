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
        celebratingLevel == completionLevel && completionLevel != .empty
    }

    @ViewBuilder
    private var pillLabel: some View {
        switch completionLevel {
        case .empty:
            Text(String(localized: "Empty"))
                .foregroundStyle(AppTheme.journalTextMuted)
        case .started:
            Text(String(localized: "Started"))
                .foregroundStyle(AppTheme.journalQuickCheckInText)
        case .growing:
            Text(String(localized: "Growing"))
                .foregroundStyle(AppTheme.journalStandardText)
        case .balanced:
            Text(String(localized: "Balanced"))
                .foregroundStyle(AppTheme.journalStandardText)
        case .full:
            Text(String(localized: "Full"))
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
        case .empty:
            return AnyShapeStyle(AppTheme.journalBackground)
        case .started:
            return AnyShapeStyle(AppTheme.journalQuickCheckInBackground)
        case .growing, .balanced:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.journalStandardBackgroundStart, AppTheme.journalStandardBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .full:
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
        case .empty:
            return AppTheme.journalBorder
        case .started:
            return AppTheme.journalQuickCheckInBorder
        case .growing, .balanced:
            return AppTheme.journalStandardBorder
        case .full:
            return AppTheme.journalFullBorder
        }
    }

    private func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .empty:
            return 1.0
        case .started:
            return 1.008
        case .growing:
            return 1.01
        case .balanced:
            return 1.015
        case .full:
            return 1.02
        }
    }

    private func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .empty:
            return .clear
        case .started:
            return AppTheme.journalQuickCheckInGlow.opacity(0.25)
        case .growing, .balanced:
            return AppTheme.journalStandardGlow.opacity(0.4)
        case .full:
            return AppTheme.journalFullGlow.opacity(0.48)
        }
    }

    private func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .empty:
            return 0
        case .started:
            return 4
        case .growing:
            return 6
        case .balanced:
            return 8
        case .full:
            return 11
        }
    }
}

import SwiftUI

/// Displays the journal entry date and completion status.
struct DateSectionView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let entryDate: Date
    let completionLevel: JournalCompletionLevel
    let chipsProgressText: String
    let celebratingLevel: JournalCompletionLevel?

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(String(localized: "Date"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.textPrimary)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                    dateLabel
                    completionStatusLabel
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppTheme.spacingTight) {
                        dateLabel
                        completionStatusLabel
                    }
                    VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                        dateLabel
                        completionStatusLabel
                    }
                }
            }
        }
    }

    private var dateLabel: some View {
        Text(entryDate.formatted(date: .abbreviated, time: .omitted))
            .font(AppTheme.warmPaperBody)
            .foregroundStyle(AppTheme.textPrimary)
            .monospacedDigit()
    }

    private var completionStatusLabel: some View {
        Group {
            switch completionLevel {
            case .quickCheckIn:
                levelSurface(level: .quickCheckIn, isCelebrating: celebratingLevel == .quickCheckIn) {
                    Label(String(localized: "Reflection Started"), systemImage: "sparkles")
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.reflectionStartedText)
                }
            case .standardReflection:
                levelSurface(level: .standardReflection, isCelebrating: celebratingLevel == .standardReflection) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(
                            String(localized: "Full 15 Complete"),
                            systemImage: celebratingLevel == .standardReflection
                                ? "sparkles.rectangle.stack.fill"
                                : "sparkles.rectangle.stack"
                        )
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.fullFifteenText)

                        Text(chipsProgressText)
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(AppTheme.fullFifteenMetaText)
                            .monospacedDigit()
                    }
                }
            case .fullFiveCubed:
                levelSurface(level: .fullFiveCubed, isCelebrating: celebratingLevel == .fullFiveCubed) {
                    Label(
                        String(localized: "Perfect Daily Rhythm"),
                        systemImage: celebratingLevel == .fullFiveCubed ? "checkmark.circle.fill" : "checkmark.circle"
                    )
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.perfectRhythmText)
                }
            case .none:
                Label(String(localized: "In progress"), systemImage: "pencil.circle")
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
    }

    private func levelSurface<Content: View>(
        level: JournalCompletionLevel,
        isCelebrating: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, AppTheme.spacingRegular)
            .padding(.vertical, AppTheme.spacingTight)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .fill(backgroundFill(for: level))
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(borderColor(for: level), lineWidth: 1)
            )
            .scaleEffect(scaleFactor(for: level, isCelebrating: isCelebrating))
            .shadow(
                color: shadowColor(for: level, isCelebrating: isCelebrating),
                radius: shadowRadius(for: level, isCelebrating: isCelebrating),
                x: 0,
                y: isCelebrating && !reduceTransparency ? 2 : 0
            )
            .animation(
                reduceMotion ? nil : AppTheme.celebrationPulseAnimation(for: level),
                value: isCelebrating
            )
    }

    private func backgroundFill(for level: JournalCompletionLevel) -> AnyShapeStyle {
        switch level {
        case .quickCheckIn:
            return AnyShapeStyle(AppTheme.reflectionStartedBackground)
        case .standardReflection:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.fullFifteenBackgroundStart, AppTheme.fullFifteenBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .fullFiveCubed:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [AppTheme.perfectRhythmBackgroundStart, AppTheme.perfectRhythmBackgroundEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .none:
            return AnyShapeStyle(AppTheme.background)
        }
    }

    private func borderColor(for level: JournalCompletionLevel) -> Color {
        switch level {
        case .quickCheckIn:
            return AppTheme.reflectionStartedBorder
        case .standardReflection:
            return AppTheme.fullFifteenBorder
        case .fullFiveCubed:
            return AppTheme.perfectRhythmBorder
        case .none:
            return AppTheme.border
        }
    }

    private func scaleFactor(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceMotion else { return 1.0 }
        switch level {
        case .quickCheckIn:
            return 1.01
        case .standardReflection:
            return 1.025
        case .fullFiveCubed:
            return 1.04
        case .none:
            return 1.0
        }
    }

    private func shadowColor(for level: JournalCompletionLevel, isCelebrating: Bool) -> Color {
        guard isCelebrating, !reduceTransparency else { return .clear }
        switch level {
        case .quickCheckIn:
            return AppTheme.reflectionStartedGlow.opacity(0.25)
        case .standardReflection:
            return AppTheme.fullFifteenGlow.opacity(0.4)
        case .fullFiveCubed:
            return AppTheme.perfectRhythmGlow.opacity(0.48)
        case .none:
            return .clear
        }
    }

    private func shadowRadius(for level: JournalCompletionLevel, isCelebrating: Bool) -> CGFloat {
        guard isCelebrating, !reduceTransparency else { return 0 }
        switch level {
        case .quickCheckIn:
            return 6
        case .standardReflection:
            return 12
        case .fullFiveCubed:
            return 16
        case .none:
            return 0
        }
    }
}

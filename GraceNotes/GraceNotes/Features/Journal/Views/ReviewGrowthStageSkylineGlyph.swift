import SwiftUI

/// Capsule-wrapped growth glyph shared by the Past skyline columns and drill-down chrome (issue #186).
struct ReviewGrowthStageSkylineGlyph: View {
    private struct Metrics {
        let glyphSize: CGFloat
        let glyphChrome: CGFloat

        static func skyline(dynamicTypeSize: DynamicTypeSize) -> Metrics {
            let scale = ReviewHistoryPanelLayoutScale.skylineMetricsScale(for: dynamicTypeSize)
            return Metrics(
                glyphSize: (14 * scale).rounded(.toNearestOrAwayFromZero),
                glyphChrome: (26 * scale).rounded(.toNearestOrAwayFromZero)
            )
        }

        static let calendarDayTeaser = Metrics(glyphSize: 11, glyphChrome: 20)
    }

    let level: JournalCompletionLevel
    private let metrics: Metrics

    init(level: JournalCompletionLevel, dynamicTypeSize: DynamicTypeSize) {
        self.level = level
        self.metrics = .skyline(dynamicTypeSize: dynamicTypeSize)
    }

    /// Smaller glyph for calendar day cells.
    init(calendarDayCellLevel level: JournalCompletionLevel) {
        self.level = level
        self.metrics = .calendarDayTeaser
    }

    var body: some View {
        Image(ReviewRhythmFormatting.assetName(for: level))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(AppTheme.reviewRhythmIconTint)
            .frame(width: metrics.glyphSize, height: metrics.glyphSize)
            .frame(width: metrics.glyphChrome, height: metrics.glyphChrome)
            .background {
                Capsule(style: .continuous)
                    .fill(AppTheme.reviewRhythmPillBackground(for: level))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(AppTheme.reviewRhythmPillBorder(for: level), lineWidth: 1)
            }
            .shadow(color: AppTheme.reviewRhythmPillShadow(for: level), radius: 3, x: 0, y: 1.2)
            .accessibilityHidden(true)
    }
}

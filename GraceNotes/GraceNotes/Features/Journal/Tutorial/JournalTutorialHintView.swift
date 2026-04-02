import SwiftUI

enum JournalTutorialHintKind: Equatable {
    case seed
    case harvest
}

enum JournalTutorialHintPresentation {
    static func hintKind(
        entryDate: Date?,
        completionLevel: JournalCompletionLevel,
        chipsFilledCount: Int,
        dismissedSeedGuidance: Bool,
        dismissedHarvestGuidance: Bool
    ) -> JournalTutorialHintKind? {
        guard entryDate == nil else { return nil }
        if completionLevel == .soil, !dismissedSeedGuidance {
            return .seed
        }
        let fifteenSlots = JournalViewModel.slotCount * 3
        if completionLevel == .sprout || completionLevel == .twig || completionLevel == .leaf,
           chipsFilledCount < fifteenSlots,
           !dismissedHarvestGuidance {
            return .harvest
        }
        return nil
    }
}

/// Dismissible nudge to keep writing toward Started or Full chip milestones (issue #60).
struct JournalTutorialHintView: View {
    @Environment(\.todayJournalPalette) private var palette
    let kind: JournalTutorialHintKind
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Text(String(localized: "Got it"))
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accentText)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "Dismisses this tip."))
        }
        .padding(AppTheme.spacingRegular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.paper.opacity(palette.sectionPaperOpacity))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(palette.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // swiftlint:disable line_length
    private var message: String {
        switch kind {
        case .seed:
            return String(
                localized: "Write one gratitude line to plant your first seed. Tap the status above anytime if you want a reminder."
            )
        case .harvest:
            return String(
                localized: "Add one more line in any section. Small steps are easier to keep. Tap the status above anytime if you want a reminder."
            )
        }
    }
    // swiftlint:enable line_length
}

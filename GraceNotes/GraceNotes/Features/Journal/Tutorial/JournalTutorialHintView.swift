import SwiftUI

enum JournalTutorialHintKind: Equatable {
    case sprout
    case bloom
}

enum JournalTutorialHintPresentation {
    static func hintKind(
        entryDate: Date?,
        completionLevel: JournalCompletionLevel,
        filledEntryCount: Int,
        dismissedSproutGuidance: Bool,
        dismissedBloomGuidance: Bool
    ) -> JournalTutorialHintKind? {
        guard entryDate == nil else { return nil }
        if completionLevel == .soil, !dismissedSproutGuidance {
            return .sprout
        }
        let fifteenSlots = JournalViewModel.slotCount * 3
        if completionLevel == .sprout || completionLevel == .twig || completionLevel == .leaf,
           filledEntryCount < fifteenSlots,
           !dismissedBloomGuidance {
            return .bloom
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
                Text(String(localized: "journal.tutorial.gotIt"))
                    .font(AppTheme.warmPaperMetaEmphasis)
                    .foregroundStyle(AppTheme.accentText)
            }
            .buttonStyle(.plain)
            .accessibilityHint(String(localized: "journal.tutorial.dismissTipHint"))
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
        case .sprout:
            return String(
                localized: "journal.tutorial.firstGratitudeSeed"
            )
        case .bloom:
            return String(
                localized: "journal.guidance.addOneMoreLineAnySection"
            )
        }
    }
    // swiftlint:enable line_length
}

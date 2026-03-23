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
        if completionLevel == .seed || completionLevel == .ripening,
           chipsFilledCount < fifteenSlots,
           !dismissedHarvestGuidance {
            return .harvest
        }
        return nil
    }
}

/// Dismissible nudge to keep writing toward Seed or fuller Harvest (issue #60).
struct JournalTutorialHintView: View {
    let kind: JournalTutorialHintKind
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.journalTextPrimary)
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
        .background(AppTheme.journalPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                .stroke(AppTheme.journalBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    // swiftlint:disable line_length
    private var message: String {
        switch kind {
        case .seed:
            return String(
                localized: "When you're ready, keep writing—a line in Gratitudes, Needs, and People in Mind is enough to begin. Tap the status above anytime if you want a reminder."
            )
        case .harvest:
            return String(
                localized: "You can keep writing in Gratitudes, Needs, and People in Mind if you'd like a fuller reflection. Tap the status above anytime to read about Harvest."
            )
        }
    }
    // swiftlint:enable line_length
}

import SwiftUI

struct JournalOnboardingGuidanceView: View {
    @Environment(\.todayJournalPalette) private var palette
    let title: String
    let message: String
    /// Optional second line under `message` (e.g. keyboard hint), matching `JournalOnboardingSectionGuidance`.
    let messageSecondary: String?

    init(title: String, message: String, messageSecondary: String? = nil) {
        self.title = title
        self.message = message
        self.messageSecondary = messageSecondary
    }

    var body: some View {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecondaryLine: String? = {
            guard let messageSecondary else { return nil }
            let trimmed = messageSecondary.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        let hasMeaningfulContent = !trimmedTitle.isEmpty || !trimmedMessage.isEmpty || trimmedSecondaryLine != nil

        if !hasMeaningfulContent {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                if !trimmedTitle.isEmpty {
                    Text(trimmedTitle)
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.accentText)
                        .accessibilityAddTraits(.isHeader)
                }

                if !trimmedMessage.isEmpty {
                    Text(trimmedMessage)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let secondaryLine = trimmedSecondaryLine {
                    Text(secondaryLine)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(AppTheme.spacingRegular)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.paper.opacity(palette.sectionPaperOpacity))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium)
                    .stroke(palette.inputBorder, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
        }
    }
}

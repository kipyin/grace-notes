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
        if message.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                if !title.isEmpty {
                    Text(title)
                        .font(AppTheme.warmPaperMetaEmphasis)
                        .foregroundStyle(AppTheme.accentText)
                        .accessibilityAddTraits(.isHeader)
                }

                Text(message)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let messageSecondary {
                    Text(messageSecondary)
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

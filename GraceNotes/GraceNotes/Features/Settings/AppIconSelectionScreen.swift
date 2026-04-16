import SwiftUI

private enum AppIconRowPreviewMetrics {
    static let side: CGFloat = 44
    static let cornerRadius = side * 0.22
}

struct AppIconSelectionScreen: View {
    @State private var selectedChoice = AppAlternateIconSelection.currentChoice()
    @State private var showAppIconChangeError = false

    var body: some View {
        List {
            Section {
                ForEach(AppAlternateIconSelection.Choice.allCases) { choice in
                    Button {
                        select(choice)
                    } label: {
                        HStack(spacing: AppTheme.spacingRegular) {
                            Image(choice.settingsPreviewAssetName)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: AppIconRowPreviewMetrics.side, height: AppIconRowPreviewMetrics.side)
                                .clipShape(
                                    RoundedRectangle(
                                        cornerRadius: AppIconRowPreviewMetrics.cornerRadius,
                                        style: .continuous
                                    )
                                )
                                .accessibilityHidden(true)
                            Text(choice.localizedTitle)
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.settingsTextPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if selectedChoice == choice {
                                Image(systemName: "checkmark")
                                    .font(AppTheme.outfitSemiboldCaption)
                                    .foregroundStyle(AppTheme.accent)
                                    .accessibilityHidden(true)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedChoice == choice ? .isSelected : [])
                }
            } footer: {
                Text(String(localized: "settings.advanced.appIcon.footnote"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
        .navigationTitle(String(localized: "settings.advanced.appIcon.sectionTitle"))
        .onAppear {
            selectedChoice = AppAlternateIconSelection.currentChoice()
        }
        .alert(
            String(localized: "settings.advanced.appIcon.errorTitle"),
            isPresented: $showAppIconChangeError
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.advanced.appIcon.errorMessage"))
        }
    }

    private func select(_ choice: AppAlternateIconSelection.Choice) {
        guard choice != AppAlternateIconSelection.currentChoice() else { return }
        AppAlternateIconSelection.setChoice(choice) { error in
            Task { @MainActor in
                if error != nil {
                    selectedChoice = AppAlternateIconSelection.currentChoice()
                    showAppIconChangeError = true
                } else {
                    selectedChoice = AppAlternateIconSelection.currentChoice()
                }
            }
        }
    }
}

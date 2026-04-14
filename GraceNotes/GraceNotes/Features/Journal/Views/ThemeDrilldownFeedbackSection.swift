import SwiftUI

struct ThemeDrilldownFeedbackSection: View {
    let canonicalConcept: String
    /// Example journal line used to derive a short trigger for an automatic substitution rule after merge.
    let lineSampleForSubstitution: String?
    @Binding var relabelDraft: String
    @Binding var mergeDraft: String
    @ObservedObject var themeOverrideStore: ThemeOverrideStore
    let onFinished: () -> Void

    var body: some View {
        Section {
            Button(String(localized: "review.themeDrilldown.hideTheme")) {
                themeOverrideStore.hideTheme(canonicalConcept: canonicalConcept)
                onFinished()
            }
            .accessibilityIdentifier("ThemeDrilldownHideTheme")

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "review.themeDrilldown.customLabel"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                TextField(
                    String(localized: "review.themeDrilldown.relabelPlaceholder"),
                    text: $relabelDraft
                )
                .textInputAutocapitalization(.sentences)
                .accessibilityIdentifier("ThemeDrilldownRelabelField")
                Button(String(localized: "review.themeDrilldown.applyRelabel")) {
                    themeOverrideStore.setDisplayLabelOverride(
                        canonicalConcept: canonicalConcept,
                        displayLabel: relabelDraft
                    )
                    onFinished()
                }
                .accessibilityIdentifier("ThemeDrilldownApplyRelabel")
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "review.themeDrilldown.mergeInto"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                TextField(
                    String(localized: "review.themeDrilldown.mergePlaceholder"),
                    text: $mergeDraft
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("ThemeDrilldownMergeField")
                Button(String(localized: "review.themeDrilldown.applyMerge")) {
                    themeOverrideStore.setCanonicalRemap(
                        from: canonicalConcept,
                        to: mergeDraft
                    )
                    ThemeSubstitutionMergeRuleRecorder.recordIfPossible(
                        lineSample: lineSampleForSubstitution,
                        fromCanonical: canonicalConcept,
                        toCanonicalRaw: mergeDraft
                    )
                    onFinished()
                }
                .accessibilityIdentifier("ThemeDrilldownApplyMerge")
                Text(String(localized: "review.themeDrilldown.mergeAlsoSavesRuleFooter"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.reviewTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
        } header: {
            Text(String(localized: "review.themeDrilldown.somethingLooksOff"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .textCase(nil)
        }
    }
}

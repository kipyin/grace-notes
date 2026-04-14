import SwiftUI

/// Day-grouped journal lines for a theme drilldown, matching Past search day cards (one card per day).
struct ThemeDrilldownSurfaceRecordsSection: View {
    let evidenceGroupedByDay: [(
        day: Date,
        sections: [(source: ReviewThemeSourceCategory, rows: [ReviewThemeSurfaceEvidence])]
    )]
    let calendar: Calendar
    let journalThemeDisplayLocale: Locale
    /// Canonical for the theme being viewed (Past aggregation key).
    let drilldownCanonicalConcept: String
    /// Visible title for that theme in this drilldown (matches summary header).
    let drilldownThemeLabel: String
    let onOpenJournalDay: (Date) -> Void

    var body: some View {
        Section {
            ForEach(evidenceGroupedByDay, id: \.day) { group in
                ThemeDrilldownDayCardView(
                    day: group.day,
                    sections: group.sections,
                    calendar: calendar,
                    journalThemeDisplayLocale: journalThemeDisplayLocale,
                    drilldownCanonicalConcept: drilldownCanonicalConcept,
                    drilldownThemeLabel: drilldownThemeLabel,
                    onOpenJournalDay: onOpenJournalDay
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        } header: {
            Text(String(localized: "review.labels.matchingSurfaces"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .textCase(nil)
        }
    }
}

private struct ThemeDrilldownDayCardView: View {
    let day: Date
    let sections: [(source: ReviewThemeSourceCategory, rows: [ReviewThemeSurfaceEvidence])]
    let calendar: Calendar
    let journalThemeDisplayLocale: Locale
    let drilldownCanonicalConcept: String
    let drilldownThemeLabel: String
    let onOpenJournalDay: (Date) -> Void

    private var dayCaption: String {
        PastSearchDayCaption.string(day: day, now: Date(), calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                onOpenJournalDay(day)
            } label: {
                Text(dayCaption)
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.reviewTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(PastTappablePressStyle())
            .accessibilityHint(String(localized: "review.themeDrilldown.openEntry.a11yHint"))

            VStack(alignment: .leading, spacing: 16) {
                ForEach(sections, id: \.source) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.source.localizedJournalSurfaceTitle)
                            .font(AppTheme.warmPaperMetaEmphasis.weight(.semibold))
                            .foregroundStyle(AppTheme.reviewTextPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(section.rows) { evidence in
                                ThemeDrilldownLineRowView(
                                    evidence: evidence,
                                    journalThemeDisplayLocale: journalThemeDisplayLocale,
                                    drilldownCanonicalConcept: drilldownCanonicalConcept,
                                    drilldownThemeLabel: drilldownThemeLabel,
                                    onOpenSameDay: { onOpenJournalDay(day) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .fill(AppTheme.reviewPaper.opacity(0.72))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .circular)
                .strokeBorder(AppTheme.reviewStandardBorder.opacity(0.42), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .circular))
    }
}

private struct LineThemeChipModel: Identifiable {
    let concept: ReviewDistilledConcept
    /// True when this tag came from per-line manual adds (not the drilldown theme alone).
    let isManualAdd: Bool

    var id: String { concept.canonicalConcept }
}

private struct ThemeDrilldownLineRowView: View {
    let evidence: ReviewThemeSurfaceEvidence
    let journalThemeDisplayLocale: Locale
    let drilldownCanonicalConcept: String
    let drilldownThemeLabel: String
    let onOpenSameDay: () -> Void

    @ObservedObject private var themeOverrideStore = ThemeOverrideStore.shared
    @ObservedObject private var surfaceThemeStore = SurfaceThemeAdjustmentStore.shared
    @ObservedObject private var themeSubstitutionRulesStore = ThemeSubstitutionRulesStore.shared

    @State private var showAddLineThemeSheet = false
    @State private var showTokenSubstitutionSheet = false

    private let textNormalizer = WeeklyInsightTextNormalizer()

    private var surfaceKey: String {
        evidence.surfaceLineKey?.storageKey ?? ""
    }

    /// All themes for this line: NLP distillation (same pipeline as weekly aggregation), per-line adds,
    /// plus the drilldown theme when it is missing (e.g. supporting-evidence matches).
    private var lineChipModels: [LineThemeChipModel] {
        _ = themeSubstitutionRulesStore.revision
        let themePolicy = themeOverrideStore.currentPolicy()
        let surfacePolicy = surfaceThemeStore.currentPolicy()
        let rules = ThemeSubstitutionRulesPersistence.loadRules()

        var tuples = ThemeDrilldownLineThemeResolver.distilledConceptsForLine(
            ThemeDrilldownLineDistillationInput(
                evidence: evidence,
                journalThemeDisplayLocale: journalThemeDisplayLocale,
                themeOverridePolicy: themePolicy,
                surfaceThemePolicy: surfacePolicy,
                substitutionRules: rules,
                textNormalizer: textNormalizer
            )
        )
        tuples = ThemeDrilldownLineThemeResolver.ensureDrilldownChipIfMissing(
            chips: tuples,
            fallback: ThemeDrilldownFallbackParams(
                drilldownCanonical: drilldownCanonicalConcept,
                drilldownDefaultLabel: drilldownThemeLabel,
                surfaceKey: surfaceKey,
                themeOverridePolicy: themePolicy,
                surfaceThemePolicy: surfacePolicy
            )
        )
        tuples = ThemeDrilldownLineThemeResolver.sortChipsDrilldownFirst(
            chips: tuples,
            drilldownCanonical: drilldownCanonicalConcept
        )
        return tuples.map { LineThemeChipModel(concept: $0.concept, isManualAdd: $0.isManualAdd) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onOpenSameDay) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(evidence.content)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .imageScale(.small)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(PastTappablePressStyle())
            .accessibilityHint(String(localized: "review.themeDrilldown.openEntry.a11yHint"))

            if !surfaceKey.isEmpty {
                HStack(alignment: .center, spacing: 8) {
                    if !lineChipModels.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(lineChipModels) { chip in
                                    chipMenu(for: chip)
                                }
                            }
                        }
                    }

                    Button {
                        showTokenSubstitutionSheet = true
                    } label: {
                        Image(systemName: "link.badge.plus")
                            .font(.title3)
                            .foregroundStyle(AppTheme.reviewAccent)
                            .accessibilityLabel(String(localized: "review.themeDrilldown.tokenRuleButtonA11y"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ThemeDrilldownTokenRuleButton")

                    Button {
                        showAddLineThemeSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppTheme.reviewAccent)
                            .accessibilityLabel(String(localized: "review.themeDrilldown.addThemeToLineA11y"))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("ThemeDrilldownAddLineThemeButton")
                }
                .sheet(isPresented: $showAddLineThemeSheet) {
                    ThemeDrilldownAddLineThemeSheet(
                        surfaceKey: surfaceKey,
                        source: evidence.source,
                        journalThemeDisplayLocale: journalThemeDisplayLocale,
                        surfaceThemeStore: surfaceThemeStore
                    )
                }
                .sheet(isPresented: $showTokenSubstitutionSheet) {
                    ThemeDrilldownTokenSubstitutionSheet(
                        lineText: evidence.content,
                        source: evidence.source,
                        journalThemeDisplayLocale: journalThemeDisplayLocale,
                        themeSubstitutionRulesStore: themeSubstitutionRulesStore
                    )
                }
            } else if !lineChipModels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lineChipModels) { chip in
                            themeChipLabel(for: chip.concept)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chipMenu(for chip: LineThemeChipModel) -> some View {
        let concept = chip.concept
        Menu {
            if chip.isManualAdd {
                Button(
                    String(localized: "review.themeDrilldown.removeAddedThemeFromLine"),
                    role: .destructive
                ) {
                    surfaceThemeStore.removeAddedCanonical(concept.canonicalConcept, surfaceKey: surfaceKey)
                }
            } else {
                Button(
                    String(localized: "review.themeDrilldown.excludeFromThisLine"),
                    role: .destructive
                ) {
                    surfaceThemeStore.excludeCanonical(concept.canonicalConcept, surfaceKey: surfaceKey)
                }
            }
        } label: {
            themeChipLabel(for: concept)
        }
        .accessibilityIdentifier("ThemeDrilldownThemeChip.\(concept.canonicalConcept)")
    }

    private func themeChipLabel(for concept: ReviewDistilledConcept) -> some View {
        Text(ThemeDrilldownChipDisplayLabel.label(for: concept, lineText: evidence.content))
            .font(AppTheme.warmPaperMeta.weight(.medium))
            .foregroundStyle(AppTheme.reviewTextPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppTheme.reviewAccent.opacity(0.14))
            .clipShape(Capsule())
    }
}

private struct ThemeDrilldownTokenSubstitutionSheet: View {
    let lineText: String
    let source: ReviewThemeSourceCategory
    let journalThemeDisplayLocale: Locale
    @ObservedObject var themeSubstitutionRulesStore: ThemeSubstitutionRulesStore

    @Environment(\.dismiss) private var dismiss
    @State private var token = ""
    @State private var countAsPhrase = ""
    @State private var showCouldNotResolve = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(lineText)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.reviewTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: {
                    Text(String(localized: "review.themeDrilldown.tokenRuleLinePreviewHeader"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }

                Section {
                    TextField(
                        String(localized: "review.themeDrilldown.tokenFieldPlaceholder"),
                        text: $token
                    )
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("ThemeDrilldownTokenRuleTokenField")
                } header: {
                    Text(String(localized: "review.themeDrilldown.tokenFieldLabel"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                }

                Section {
                    TextField(
                        String(localized: "review.themeDrilldown.countAsFieldPlaceholder"),
                        text: $countAsPhrase
                    )
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("ThemeDrilldownTokenRuleCountAsField")
                } header: {
                    Text(String(localized: "review.themeDrilldown.countAsFieldLabel"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                        .textCase(nil)
                } footer: {
                    Text(String(localized: "review.themeDrilldown.tokenRuleFooter"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                }
                .onChange(of: token) { _, _ in
                    showCouldNotResolve = false
                }
                .onChange(of: countAsPhrase) { _, _ in
                    showCouldNotResolve = false
                }

                if showCouldNotResolve {
                    Section {
                        Text(String(localized: "review.themeDrilldown.tokenRuleCouldNotResolve"))
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(String(localized: "review.themeDrilldown.tokenRuleSheetTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "review.themeDrilldown.tokenRuleConfirm")) {
                        let didSave = themeSubstitutionRulesStore.addTokenDesignationRule(
                            lineText: lineText,
                            token: token,
                            countAsPhrase: countAsPhrase,
                            source: source,
                            journalThemeDisplayLocale: journalThemeDisplayLocale
                        )
                        if didSave {
                            dismiss()
                        } else {
                            showCouldNotResolve = true
                        }
                    }
                    .accessibilityIdentifier("ThemeDrilldownTokenRuleConfirm")
                }
            }
        }
    }
}

private struct ThemeDrilldownAddLineThemeSheet: View {
    let surfaceKey: String
    let source: ReviewThemeSourceCategory
    let journalThemeDisplayLocale: Locale
    @ObservedObject var surfaceThemeStore: SurfaceThemeAdjustmentStore

    @Environment(\.dismiss) private var dismiss
    @State private var phrase = ""
    @State private var showCouldNotResolve = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField(
                        String(localized: "review.themeDrilldown.addLineThemePlaceholder"),
                        text: $phrase
                    )
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier("ThemeDrilldownAddLineThemeField")
                } footer: {
                    Text(String(localized: "review.themeDrilldown.addLineThemeFooter"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.reviewTextMuted)
                }
                .onChange(of: phrase) { _, _ in
                    showCouldNotResolve = false
                }

                if showCouldNotResolve {
                    Section {
                        Text(String(localized: "review.themeDrilldown.addLineThemeCouldNotResolve"))
                            .font(AppTheme.warmPaperMeta)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(String(localized: "review.themeDrilldown.addLineThemeSheetTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "review.themeDrilldown.addLineThemeSheetAdd")) {
                        let didAdd = surfaceThemeStore.addCanonicalFromUserPhrase(
                            phrase,
                            surfaceKey: surfaceKey,
                            source: source,
                            journalThemeDisplayLocale: journalThemeDisplayLocale
                        )
                        if didAdd {
                            dismiss()
                        } else {
                            showCouldNotResolve = true
                        }
                    }
                    .accessibilityIdentifier("ThemeDrilldownAddLineThemeConfirm")
                }
            }
        }
    }
}

struct ThemeDrilldownAdjustThemeSheet: View {
    let canonicalConcept: String
    let lineSampleForSubstitution: String?
    @Binding var relabelDraft: String
    @Binding var mergeDraft: String
    @ObservedObject var themeOverrideStore: ThemeOverrideStore
    let onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ThemeDrilldownFeedbackSection(
                    canonicalConcept: canonicalConcept,
                    lineSampleForSubstitution: lineSampleForSubstitution,
                    relabelDraft: $relabelDraft,
                    mergeDraft: $mergeDraft,
                    themeOverrideStore: themeOverrideStore,
                    onFinished: {
                        onFinished()
                        dismiss()
                    }
                )
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.reviewBackground)
            .navigationTitle(String(localized: "review.themeDrilldown.adjustThemesTitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

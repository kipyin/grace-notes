import SwiftUI

private enum PastStatisticsIntervalPickerMode: String, CaseIterable, Identifiable {
    case all
    case custom

    var id: String { rawValue }
}

struct AdvancedSettingsScreen: View {
    @Environment(\.interactionAccentPalette) private var interactionAccent
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var intervalEncoded = ""
    @AppStorage(JournalTutorialStorageKeys.celebratedFirstBloom) private var hasCelebratedFirstBloom = false
    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue
    @AppStorage(JournalAppearanceStorageKeys.accentPreference)
    private var accentPreferenceRaw = AccentPreference.terracotta.rawValue

    @State private var intervalMode: PastStatisticsIntervalPickerMode = .all
    @State private var customQuantity: Int = 4
    @State private var customUnit: PastStatisticsIntervalUnit = .week

    var body: some View {
        List {
            Section {
                Picker(
                    String(localized: "Settings.advanced.firstWeekday.label"),
                    selection: reviewWeekBoundaryBinding
                ) {
                    ForEach(ReviewWeekBoundaryPreference.allCases, id: \.self) { option in
                        Text(option.localizedLabel).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .accessibilityIdentifier("SettingsReviewWeekBoundaryPicker")
                .frame(minHeight: 44)
            }

            Section {
                Picker(
                    String(localized: "Settings.advanced.pastStatsInterval.label"),
                    selection: $intervalMode
                ) {
                    Text(String(localized: "Settings.advanced.pastStatsInterval.all")).tag(
                        PastStatisticsIntervalPickerMode.all
                    )
                    Text(String(localized: "Settings.advanced.pastStatsInterval.custom")).tag(
                        PastStatisticsIntervalPickerMode.custom
                    )
                }
                .pickerStyle(.menu)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .onChange(of: intervalMode) { _, newValue in
                    applyIntervalMode(newValue)
                }

                if intervalMode == .custom {
                    HStack(alignment: .center, spacing: 12) {
                        Picker(
                            String(localized: "Settings.advanced.pastStatsInterval.quantity.a11y"),
                            selection: $customQuantity
                        ) {
                            ForEach(1...999, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker(
                            String(localized: "Settings.advanced.pastStatsInterval.unit.a11y"),
                            selection: $customUnit
                        ) {
                            ForEach(PastStatisticsIntervalUnit.allCases, id: \.self) { unit in
                                Text(localizedUnitLabel(unit)).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: customQuantity) { _, _ in persistCustomInterval() }
                    .onChange(of: customUnit) { _, _ in persistCustomInterval() }
                }

                Text(String(localized: "Settings.advanced.pastStatsInterval.footnote"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasCelebratedFirstBloom {
                Section {
                    Toggle(isOn: bloomModeBinding) {
                        Text(String(localized: "Bloom"))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                    }
                    .tint(interactionAccent.accent)
                    .accessibilityHint(String(localized: "Settings.todayJournalAppearance.bloomToggleA11yHint"))
                }
            }

            Section {
                VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                    Picker(selection: accentPreferenceBinding) {
                        ForEach(AccentPreference.allCases) { option in
                            Text(option.localizedTitle).tag(option)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .font(AppTheme.outfitSemiboldSubheadline)
                    .accessibilityLabel(String(localized: "Settings.advanced.accent.label"))

                    Text(String(localized: "Settings.advanced.accent.footnote"))
                        .font(AppTheme.warmPaperMeta)
                        .foregroundStyle(AppTheme.settingsTextMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppTheme.spacingTight / 2)
            } header: {
                Text(String(localized: "Settings.advanced.accent.label"))
                    .font(AppTheme.warmPaperHeader)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .textCase(nil)
            }
        }
        .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
        .navigationTitle(String(localized: "Settings.advanced.title"))
        .onAppear {
            loadIntervalState()
        }
        .onChange(of: intervalEncoded) { _, _ in
            loadIntervalState()
        }
    }

    private var reviewWeekBoundaryBinding: Binding<ReviewWeekBoundaryPreference> {
        Binding(
            get: { ReviewWeekBoundaryPreference.resolve(from: reviewWeekBoundaryRawValue) },
            set: { reviewWeekBoundaryRawValue = $0.rawValue }
        )
    }

    private var settingsJournalTodayAppearance: JournalAppearanceMode {
        JournalAppearanceMode.resolveStored(rawValue: journalTodayAppearanceRaw)
    }

    private var bloomModeBinding: Binding<Bool> {
        Binding(
            get: { settingsJournalTodayAppearance == .bloom },
            set: { isEnabled in
                journalTodayAppearanceRaw = isEnabled
                    ? JournalAppearanceMode.bloom.rawValue
                    : JournalAppearanceMode.standard.rawValue
            }
        )
    }

    private var accentPreferenceBinding: Binding<AccentPreference> {
        Binding(
            get: { AccentPreference.resolveStored(rawValue: accentPreferenceRaw) },
            set: { accentPreferenceRaw = $0.rawValue }
        )
    }

    private func localizedUnitLabel(_ unit: PastStatisticsIntervalUnit) -> String {
        switch unit {
        case .week:
            return String(localized: "Settings.advanced.pastStatsInterval.unit.week")
        case .month:
            return String(localized: "Settings.advanced.pastStatsInterval.unit.month")
        case .year:
            return String(localized: "Settings.advanced.pastStatsInterval.unit.year")
        }
    }

    private func loadIntervalState() {
        let selection = PastStatisticsIntervalPreference.selection(fromAppStorage: intervalEncoded).validated
        customQuantity = selection.quantity
        customUnit = selection.unit
        intervalMode = selection.mode == .all ? .all : .custom
    }

    private func applyIntervalMode(_ mode: PastStatisticsIntervalPickerMode) {
        switch mode {
        case .all:
            let next = PastStatisticsIntervalSelection(
                mode: .all,
                quantity: customQuantity,
                unit: customUnit
            ).validated
            intervalEncoded = PastStatisticsIntervalSelection.encodeForStorage(next)
        case .custom:
            persistCustomInterval()
        }
    }

    private func persistCustomInterval() {
        let next = PastStatisticsIntervalSelection(
            mode: .custom,
            quantity: customQuantity,
            unit: customUnit
        ).validated
        intervalEncoded = PastStatisticsIntervalSelection.encodeForStorage(next)
    }
}

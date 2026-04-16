import SwiftUI

private enum PastStatisticsIntervalPickerMode: String, CaseIterable, Identifiable {
    case all
    case custom

    var id: String { rawValue }
}

struct AdvancedSettingsScreen: View {
    @AppStorage(ReviewWeekBoundaryPreference.userDefaultsKey)
    private var reviewWeekBoundaryRawValue = ReviewWeekBoundaryPreference.defaultValue.rawValue
    @AppStorage(PastStatisticsIntervalPreference.appStorageKey)
    private var intervalEncoded = ""
    @AppStorage(JournalTutorialStorageKeys.celebratedFirstBloom) private var hasCelebratedFirstBloom = false
    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue

    @State private var intervalMode: PastStatisticsIntervalPickerMode
    @State private var customQuantity: Int
    @State private var customUnit: PastStatisticsIntervalUnit
    @State private var appIconRowChoice: AppAlternateIconSelection.Choice = .liquidGlass
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let raw = PastStatisticsIntervalPreference.appStorageRawValue()
        let selection = PastStatisticsIntervalPreference.selection(fromAppStorage: raw).validated
        _intervalMode = State(initialValue: selection.mode == .all ? .all : .custom)
        _customQuantity = State(initialValue: Self.clampedPickerQuantity(selection.quantity))
        _customUnit = State(initialValue: selection.unit)
    }

    var body: some View {
        List {
            if AppAlternateIconSelection.supportsAlternateIcons {
                Section {
                    NavigationLink {
                        AppIconSelectionScreen()
                    } label: {
                        HStack(spacing: AppTheme.spacingRegular) {
                            Text(String(localized: "settings.advanced.appIcon.pickerLabel"))
                                .font(AppTheme.warmPaperBody)
                                .foregroundStyle(AppTheme.settingsTextPrimary)
                            Spacer(minLength: AppTheme.spacingRegular)
                            Text(appIconRowChoice.localizedTitle)
                                .font(AppTheme.warmPaperMeta)
                                .foregroundStyle(AppTheme.settingsTextMuted)
                                .lineLimit(1)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                } header: {
                    Text(String(localized: "settings.advanced.appIcon.sectionTitle"))
                        .font(AppTheme.warmPaperHeader)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .textCase(nil)
                }
            }

            Section {
                Picker(
                    String(localized: "settings.advanced.firstWeekday.label"),
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
                    String(localized: "settings.advanced.pastStatsInterval.label"),
                    selection: $intervalMode
                ) {
                    Text(String(localized: "settings.advanced.pastStatsInterval.all")).tag(
                        PastStatisticsIntervalPickerMode.all
                    )
                    Text(String(localized: "settings.advanced.pastStatsInterval.custom")).tag(
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
                            String(localized: "settings.advanced.pastStatsInterval.quantity.a11y"),
                            selection: $customQuantity
                        ) {
                            ForEach(Self.pickerQuantityRange, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker(
                            String(localized: "settings.advanced.pastStatsInterval.unit.a11y"),
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

                Text(String(localized: "settings.advanced.pastStatsInterval.footnote"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if hasCelebratedFirstBloom {
                Section {
                    Toggle(isOn: bloomModeBinding) {
                        Text(String(localized: "journal.growthStage.bloom"))
                            .font(AppTheme.warmPaperBody)
                            .foregroundStyle(AppTheme.settingsTextPrimary)
                    }
                    .tint(AppTheme.accent)
                    .accessibilityHint(String(localized: "settings.todayJournalAppearance.bloomToggleA11yHint"))
                }
            }
        }
        .listRowBackground(AppTheme.settingsPaper.opacity(0.9))
        .scrollContentBackground(.hidden)
        .background(AppTheme.settingsBackground)
        .navigationTitle(String(localized: "settings.advanced.title"))
        .onAppear {
            loadIntervalState()
            appIconRowChoice = AppAlternateIconSelection.currentChoice()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appIconRowChoice = AppAlternateIconSelection.currentChoice()
            }
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

    private static let pickerQuantityRange = 1...999

    private static func clampedPickerQuantity(_ quantity: Int) -> Int {
        min(
            max(quantity, Self.pickerQuantityRange.lowerBound),
            Self.pickerQuantityRange.upperBound
        )
    }

    private func localizedUnitLabel(_ unit: PastStatisticsIntervalUnit) -> String {
        switch unit {
        case .week:
            return String(localized: "settings.advanced.pastStatsInterval.unit.week")
        case .month:
            return String(localized: "settings.advanced.pastStatsInterval.unit.month")
        case .year:
            return String(localized: "settings.advanced.pastStatsInterval.unit.year")
        }
    }

    private func loadIntervalState() {
        let selection = PastStatisticsIntervalPreference.selection(fromAppStorage: intervalEncoded).validated
        let nextQuantity = Self.clampedPickerQuantity(selection.quantity)
        let nextUnit = selection.unit
        let nextMode: PastStatisticsIntervalPickerMode = selection.mode == .all ? .all : .custom
        if nextQuantity == customQuantity, nextUnit == customUnit, nextMode == intervalMode {
            return
        }
        customQuantity = nextQuantity
        customUnit = nextUnit
        intervalMode = nextMode
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

import SwiftUI

/// One-time full-screen App Tour from Today or Settings.
/// Styled like app onboarding; **Done** (last page) or **Skip** (earlier pages) ends the flow.
struct AppTourView: View {
    let onFinish: () -> Void
    /// When true, hides the Started congratulations page (user already completed guided journal before this journey).
    let skipsCongratulationsPage: Bool

    @Environment(\.openURL) var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.persistenceRuntimeSnapshot) var persistenceRuntimeSnapshot
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @AppStorage(PersistenceController.iCloudSyncEnabledKey) var isICloudSyncEnabled = false

    @StateObject var reminderState = ReminderSettingsFlowModel()
    @StateObject var iCloudAccountState = ICloudAccountStatusModel()

    @State var pageIndex = 0
    @State var isReminderToggleOn = false
    @State var isReminderPickerExpanded = false
    @State var congratsAnimatedIn = false

    var lastPageIndex: Int { 4 }

    var firstPageIndex: Int { skipsCongratulationsPage ? 1 : 0 }

    init(onFinish: @escaping () -> Void, skipsCongratulationsPage: Bool = false) {
        self.onFinish = onFinish
        self.skipsCongratulationsPage = skipsCongratulationsPage
        _pageIndex = State(initialValue: skipsCongratulationsPage ? 1 : 0)
        _reminderState = StateObject(wrappedValue: ReminderSettingsFlowModel())
        _iCloudAccountState = StateObject(wrappedValue: ICloudAccountStatusModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $pageIndex) {
                if !skipsCongratulationsPage {
                    congratulationsPage.tag(0)
                }
                pathPage.tag(1)
                insightsPage.tag(2)
                remindersPage.tag(3)
                iCloudPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageIndicatorRow
                .padding(.top, AppTheme.spacingTight)

            bottomChrome
                .padding(.horizontal, AppTheme.spacingWide)
                .padding(.top, AppTheme.spacingRegular)
                .padding(.bottom, AppTheme.spacingSection)
                .background(AppTheme.settingsBackground)
        }
        .background(AppTheme.settingsBackground.ignoresSafeArea())
        .task {
            reminderState.reminderNotificationBody = { reminderTime in
                (try? ReminderNotificationBodyBuilder.localizedBody(
                    modelContext: modelContext,
                    reminderTime: reminderTime
                )) ?? String(localized: String.LocalizationValue("notifications.reminder.body.fallback"))
            }
            await reminderState.refreshStatus()
            syncReminderControlState(with: reminderState.liveStatus)
            iCloudAccountState.refresh()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
            iCloudAccountState.refresh()
        }
        .onChange(of: reminderState.liveStatus) { _, newValue in
            syncReminderControlState(with: newValue)
        }
        .onChange(of: reminderState.selectedTime) { _, _ in
            reminderState.handleSelectedTimeChanged()
        }
        .alert(
            String(localized: "notifications.reminder.updateFailedTitle"),
            isPresented: reminderErrorIsPresented
        ) {
            Button(String(localized: "common.ok"), role: .cancel) {
                reminderState.clearTransientError()
            }
        } message: {
            Text(reminderState.transientErrorMessage ?? String(localized: "common.tryAgainGeneric"))
        }
    }
}

// MARK: - Path strip

private enum AppTourPathTitleMetricsKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// One row of the path strip: timeline dot is vertically centered on the **title** line only (not the criterion).
private struct AppTourPathStepRow: View {
    let index: Int
    let stepCount: Int
    let title: String
    let titleSystemImage: String
    let criterionText: String
    let isHighlighted: Bool
    let dotFill: Color
    let dotBorder: Color
    let dotStrokeWidth: CGFloat
    let pathSpineStroke: Color

    @State private var titleLineHeight: CGFloat = 0

    private var isLastStep: Bool { index >= stepCount - 1 }

    private static let dotDiameter: CGFloat = 10

    var body: some View {
        Group {
            stepRow
            if !isLastStep {
                connectorRow
            }
        }
    }

    private var stepRow: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingRegular) {
            ZStack(alignment: .top) {
                spineBetweenDotCenters
                Circle()
                    .fill(dotFill)
                    .frame(width: Self.dotDiameter, height: Self.dotDiameter)
                    .background {
                        if isHighlighted {
                            Circle().fill(AppTheme.settingsPaper)
                        }
                    }
                    .overlay(
                        Circle()
                            .stroke(dotBorder, lineWidth: dotStrokeWidth)
                    )
                    .offset(y: dotVerticalOffset)
            }
            .frame(width: Self.dotDiameter)

            VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
                HStack(alignment: .firstTextBaseline, spacing: AppTheme.spacingTight) {
                    if !titleSystemImage.isEmpty {
                        Image(systemName: titleSystemImage)
                            .font(isHighlighted ? AppTheme.warmPaperMetaEmphasis : AppTheme.warmPaperMeta)
                            .foregroundStyle(isHighlighted ? AppTheme.reviewAccent : AppTheme.settingsTextMuted)
                            .accessibilityHidden(true)
                    }
                    Text(title)
                        .font(isHighlighted ? AppTheme.warmPaperMetaEmphasis : AppTheme.warmPaperMeta)
                        .foregroundStyle(isHighlighted ? AppTheme.reviewAccent : AppTheme.settingsTextMuted)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: AppTourPathTitleMetricsKey.self,
                            value: geometry.size.height
                        )
                    }
                }

                Text(criterionText)
                    .font(AppTheme.warmPaperCaption)
                    .foregroundStyle(AppTheme.settingsTextMuted.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                if !isLastStep {
                    Rectangle()
                        .fill(AppTheme.journalInputBorder.opacity(0.35))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, AppTheme.spacingTight / 2)
                        .padding(.bottom, AppTheme.spacingTight)
                }
            }
            .onPreferenceChange(AppTourPathTitleMetricsKey.self) { titleLineHeight = $0 }

            Spacer(minLength: 0)
        }
    }

    /// Places the dot’s vertical center on the title’s vertical center (measured).
    private var dotVerticalOffset: CGFloat {
        guard titleLineHeight > 0 else { return 0 }
        return max(0, titleLineHeight / 2 - Self.dotDiameter / 2)
    }

    /// Y-offset from the top of this row’s spine column to the dot’s vertical center.
    private var dotCenterY: CGFloat {
        dotVerticalOffset + Self.dotDiameter / 2
    }

    /// Spine runs **between** dot centers: no stub above the first dot, full run through the last dot.
    private var spineBetweenDotCenters: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let centerY = dotCenterY
            let incomingHeight = max(0, min(centerY, height))
            let outgoingHeight = max(0, height - centerY)

            ZStack(alignment: .top) {
                if index > 0 && incomingHeight > 0 {
                    Rectangle()
                        .fill(pathSpineStroke)
                        .frame(width: 1, height: incomingHeight)
                        .position(x: width / 2, y: incomingHeight / 2)
                }
                if !isLastStep && outgoingHeight > 0 {
                    Rectangle()
                        .fill(pathSpineStroke)
                        .frame(width: 1, height: outgoingHeight)
                        .position(x: width / 2, y: centerY + outgoingHeight / 2)
                }
            }
        }
    }

    private var connectorRow: some View {
        HStack(alignment: .top, spacing: AppTheme.spacingRegular) {
            Color.clear
                .frame(width: Self.dotDiameter, height: AppTheme.spacingRegular)
                .overlay(alignment: .center) {
                    Rectangle()
                        .fill(pathSpineStroke)
                        .frame(width: 1, height: AppTheme.spacingRegular)
                }
            Color.clear
                .frame(height: AppTheme.spacingRegular)
                .frame(maxWidth: .infinity)
        }
    }
}

struct AppTourPathStrip: View {
    let highlightedLevel: JournalCompletionLevel

    private static let orderedLevels: [JournalCompletionLevel] = [
        .soil, .sprout, .twig, .leaf, .bloom
    ]

    private var pathSpineStroke: Color {
        AppTheme.journalInputBorder.opacity(0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.orderedLevels.enumerated()), id: \.offset) { index, level in
                AppTourPathStepRow(
                    index: index,
                    stepCount: Self.orderedLevels.count,
                    title: displayName(for: level),
                    titleSystemImage: "",
                    criterionText: criterion(for: level),
                    isHighlighted: level == highlightedLevel,
                    dotFill: dotFill(for: level),
                    dotBorder: dotBorder(for: level),
                    dotStrokeWidth: level == highlightedLevel ? 2 : 1,
                    pathSpineStroke: pathSpineStroke
                )
            }
        }
        .padding(AppTheme.spacingWide)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.settingsPaper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.journalInputBorder, lineWidth: 1)
        )
    }

    private func displayName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            return String(localized: "journal.growthStage.empty")
        case .sprout:
            return String(localized: "journal.growthStage.started")
        case .twig:
            return String(localized: "journal.growthStage.growing")
        case .leaf:
            return String(localized: "journal.growthStage.balanced")
        case .bloom:
            return String(localized: "journal.growthStage.full")
        }
    }

    private func criterion(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            return String(localized: "tutorial.appTour.path.criterion.empty")
        case .sprout:
            return String(localized: "tutorial.appTour.path.criterion.started")
        case .twig:
            return String(localized: "tutorial.appTour.path.criterion.growing")
        case .leaf:
            return String(localized: "tutorial.appTour.path.criterion.balanced")
        case .bloom:
            return String(localized: "tutorial.appTour.path.criterion.full")
        }
    }

    private func dotFill(for level: JournalCompletionLevel) -> Color {
        if level == highlightedLevel {
            return AppTheme.reviewAccent.opacity(0.35)
        }
        return AppTheme.journalBackground
    }

    private func dotBorder(for level: JournalCompletionLevel) -> Color {
        if level == highlightedLevel {
            return AppTheme.reviewAccent
        }
        return AppTheme.journalBorder
    }
}

// MARK: - Sample insights preview

struct AppTourInsightsPreview: View {
    /// Soft scrim over the bottom of the clip (matches ``AppTheme.reviewBackground``).
    private static let fadeBandHeight: CGFloat = 120
    /// Shows roughly the source row + upper ~4/5 of the Reflection rhythm panel, then fades before Observation.
    private static let previewClipHeight: CGFloat = 360

    private var sampleInsights: ReviewInsights {
        ReviewInsights.appTourTutorialPreview()
    }

    var body: some View {
        ReviewDaysYouWrotePanel(
            insights: sampleInsights,
            isLoading: false
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .allowsHitTesting(false)
        .background(AppTheme.reviewBackground)
        .compositingGroup()
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.62),
                    .init(color: .white.opacity(0.4), location: 0.76),
                    .init(color: .clear, location: 0.86)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .frame(height: Self.previewClipHeight, alignment: .top)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    AppTheme.reviewBackground.opacity(0),
                    AppTheme.reviewBackground.opacity(0.65),
                    AppTheme.reviewBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.fadeBandHeight)
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "tutorial.appTour.sampleInsights.a11yLabel"))
    }
}

// MARK: - iCloud card (parity with Data & Privacy)

struct AppTourICloudCard: View {
    @Binding var isICloudSyncEnabled: Bool
    @ObservedObject var iCloudAccountState: ICloudAccountStatusModel
    let persistenceRuntimeSnapshot: PersistenceRuntimeSnapshot
    let openSystemSettings: () -> Void

    var body: some View {
        journeySettingsCard {
            VStack(alignment: .leading, spacing: AppTheme.spacingRegular) {
                storageSummaryBlock

                if let attentionMessage {
                    attentionBlock(message: attentionMessage)
                }

                if shouldShowICloudSyncToggle {
                    Toggle(String(localized: "settings.dataPrivacy.iCloudSyncToggle"), isOn: $isICloudSyncEnabled)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .tint(AppTheme.reviewAccent)
                        .frame(minHeight: 44)
                }
            }
        }
    }

    private func journeySettingsCard(@ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(AppTheme.spacingWide)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.settingsPaper)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                    .stroke(AppTheme.journalInputBorder, lineWidth: 1)
            )
    }

    private var preferenceMatchesEffectiveStore: Bool {
        isICloudSyncEnabled == persistenceRuntimeSnapshot.storeUsesCloudKit
    }

    private var shouldOfferICloudSettingsLink: Bool {
        guard let bucket = iCloudAccountState.displayedBucket else { return false }
        switch bucket {
        case .noAccount, .restricted:
            return true
        case .available, .temporarilyUnavailable, .couldNotDetermine:
            return false
        }
    }

    private var shouldShowICloudSyncToggle: Bool {
        iCloudAccountState.displayedBucket?.showsICloudSyncToggle ?? true
    }

    private var isJournalOnCloudKitStore: Bool {
        persistenceRuntimeSnapshot.storeUsesCloudKit && !persistenceRuntimeSnapshot.startupUsedCloudKitFallback
    }

    private var primaryStorageBody: String {
        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback {
            return String(localized: "settings.dataPrivacy.storage.fallbackLocal")
        }
        return String(localized: "settings.dataPrivacy.storage.localOnly")
    }

    private var attentionMessage: String? {
        if let bucket = iCloudAccountState.displayedBucket {
            switch bucket {
            case .noAccount:
                return String(localized: "settings.dataPrivacy.attention.noAccount.summary")
            case .restricted:
                return String(localized: "settings.dataPrivacy.attention.restricted.summary")
            case .temporarilyUnavailable:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "settings.dataPrivacy.attention.tempUnavailableMismatch.summary")
                }
                return String(localized: "settings.dataPrivacy.attention.tempUnavailable")
            case .couldNotDetermine:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "settings.dataPrivacy.attention.unknownMismatch.summary")
                }
                return String(localized: "settings.dataPrivacy.attention.unknown")
            case .available:
                break
            }
        }

        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback, isICloudSyncEnabled {
            return String(localized: "settings.dataPrivacy.attention.retryICloudAfterRelaunch.summary")
        }

        if !preferenceMatchesEffectiveStore {
            if shouldShowICloudSyncToggle {
                return String(localized: "settings.dataPrivacy.attention.toggleChangedRelaunch.summary")
            }
            return String(localized: "settings.dataPrivacy.attention.preferenceMismatchRelaunch.summary")
        }

        return nil
    }

    @ViewBuilder
    private var storageSummaryBlock: some View {
        if isJournalOnCloudKitStore {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                Text(String(localized: "settings.dataPrivacy.storage.heading"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.storage.cloudActive"))
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                Text(String(localized: "settings.dataPrivacy.storage.heading"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                Text(primaryStorageBody)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.storage"))
        }
    }

    private func attentionBlock(message: String) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.spacingTight) {
            Text(message)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.settingsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if shouldOfferICloudSettingsLink {
                SettingsOpenSystemSettingsButton(
                    action: openSystemSettings,
                    accessibilityHint: String(
                        localized: "settings.dataPrivacy.openIOSSettingsICloudHint"
                    ),
                    emphasis: .prominent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "settings.dataPrivacy.a11y.nextSteps"))
    }
}

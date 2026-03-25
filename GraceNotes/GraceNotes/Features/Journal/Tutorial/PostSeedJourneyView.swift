import SwiftUI

/// One-time full-screen flow after the user first reaches **Seed** on Today’s guided entry.
/// Styled like app onboarding; **Done** (last page) or **Skip** (earlier pages) ends the flow and the guided tutorial.
struct PostSeedJourneyView: View {
    let onFinish: () -> Void
    /// When true, hides the Seed congratulations page (0.5.0 build 7+ upgraders already at or above Seed).
    let skipsCongratulationsPage: Bool

    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.persistenceRuntimeSnapshot) var persistenceRuntimeSnapshot
    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.verticalSizeClass) var verticalSizeClass

    @AppStorage(SummarizerProvider.useCloudUserDefaultsKey) var useCloudSummarization = false
    @AppStorage(PersistenceController.iCloudSyncEnabledKey) var isICloudSyncEnabled = false

    @StateObject var reminderState = ReminderSettingsFlowModel()
    @StateObject var iCloudAccountState = ICloudAccountStatusModel()
    @StateObject var aiCloudStatus = AISettingsCloudStatusModel()

    @State var pageIndex = 0
    @State var isReminderToggleOn = false
    @State var isReminderPickerExpanded = false
    @State var congratsAnimatedIn = false

    let lastPageIndex = 5

    var firstPageIndex: Int { skipsCongratulationsPage ? 1 : 0 }

    init(onFinish: @escaping () -> Void, skipsCongratulationsPage: Bool = false) {
        self.onFinish = onFinish
        self.skipsCongratulationsPage = skipsCongratulationsPage
        _pageIndex = State(initialValue: skipsCongratulationsPage ? 1 : 0)
        _reminderState = StateObject(wrappedValue: ReminderSettingsFlowModel())
        _iCloudAccountState = StateObject(wrappedValue: ICloudAccountStatusModel())
        _aiCloudStatus = StateObject(wrappedValue: AISettingsCloudStatusModel())
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
                aiPage.tag(4)
                iCloudPage.tag(5)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            pageIndicatorRow
                .padding(.top, AppTheme.spacingTight)

            bottomChrome
                .padding(.horizontal, AppTheme.spacingWide)
                .padding(.top, AppTheme.spacingRegular)
                .padding(.bottom, AppTheme.spacingSection)
                .background(AppTheme.background)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .task {
            await reminderState.refreshStatus()
            syncReminderControlState(with: reminderState.liveStatus)
            iCloudAccountState.refresh()
            clampCloudAIFeaturesIfApiKeyMissing()
            syncAICloudStatusModel()
            aiCloudStatus.scheduleThrottledAutoCheckIfNeeded()
        }
        .onDisappear {
            aiCloudStatus.onSettingsDisappear()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else { return }
            Task {
                await reminderState.refreshStatus()
            }
            iCloudAccountState.refresh()
            aiCloudStatus.sceneDidBecomeActive()
            syncAICloudStatusModel()
        }
        .onChange(of: reminderState.liveStatus) { _, newValue in
            syncReminderControlState(with: newValue)
        }
        .onChange(of: reminderState.selectedTime) { _, _ in
            reminderState.handleSelectedTimeChanged()
        }
        .onChange(of: useCloudSummarization) { _, _ in
            syncAICloudStatusModel()
        }
        .alert(
            String(localized: "Unable to update reminder"),
            isPresented: reminderErrorIsPresented
        ) {
            Button(String(localized: "OK"), role: .cancel) {
                reminderState.clearTransientError()
            }
        } message: {
            Text(reminderState.transientErrorMessage ?? String(localized: "Please try again."))
        }
    }
}

// MARK: - Path strip

private enum PostSeedJourneyPathTitleMetricsKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// One row of the path strip: timeline dot is vertically centered on the **title** line only (not the criterion).
private struct PostSeedJourneyPathStepRow: View {
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
                            Circle().fill(AppTheme.paper)
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
                    Image(systemName: titleSystemImage)
                        .font(isHighlighted ? AppTheme.warmPaperMetaEmphasis : AppTheme.warmPaperMeta)
                        .foregroundStyle(isHighlighted ? AppTheme.accentText : AppTheme.textMuted)
                        .accessibilityHidden(true)
                    Text(title)
                        .font(isHighlighted ? AppTheme.warmPaperMetaEmphasis : AppTheme.warmPaperMeta)
                        .foregroundStyle(isHighlighted ? AppTheme.accentText : AppTheme.textMuted)
                }
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: PostSeedJourneyPathTitleMetricsKey.self,
                            value: geometry.size.height
                        )
                    }
                }

                Text(criterionText)
                    .font(AppTheme.warmPaperCaption)
                    .foregroundStyle(AppTheme.textMuted.opacity(0.88))
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
            .onPreferenceChange(PostSeedJourneyPathTitleMetricsKey.self) { titleLineHeight = $0 }

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
            let w = geo.size.width
            let h = geo.size.height
            let centerY = dotCenterY
            let incomingHeight = max(0, min(centerY, h))
            let outgoingHeight = max(0, h - centerY)

            ZStack(alignment: .top) {
                if index > 0 && incomingHeight > 0 {
                    Rectangle()
                        .fill(pathSpineStroke)
                        .frame(width: 1, height: incomingHeight)
                        .position(x: w / 2, y: incomingHeight / 2)
                }
                if !isLastStep && outgoingHeight > 0 {
                    Rectangle()
                        .fill(pathSpineStroke)
                        .frame(width: 1, height: outgoingHeight)
                        .position(x: w / 2, y: centerY + outgoingHeight / 2)
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

struct PostSeedJourneyPathStrip: View {
    let highlightedLevel: JournalCompletionLevel

    private static let orderedLevels: [JournalCompletionLevel] = [
        .soil, .seed, .ripening, .harvest, .abundance
    ]

    private var pathSpineStroke: Color {
        AppTheme.journalInputBorder.opacity(0.45)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(Self.orderedLevels.enumerated()), id: \.offset) { index, level in
                PostSeedJourneyPathStepRow(
                    index: index,
                    stepCount: Self.orderedLevels.count,
                    title: displayName(for: level),
                    titleSystemImage: level.completionStatusSystemImage(isEmphasized: level == highlightedLevel),
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
        .background(AppTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge)
                .stroke(AppTheme.journalInputBorder, lineWidth: 1)
        )
    }

    private func displayName(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            return String(localized: "Soil")
        case .seed:
            return String(localized: "Seed")
        case .ripening:
            return String(localized: "Ripening")
        case .harvest:
            return String(localized: "Harvest")
        case .abundance:
            return String(localized: "Abundance")
        }
    }

    private func criterion(for level: JournalCompletionLevel) -> String {
        switch level {
        case .soil:
            return String(localized: "PostSeedJourney.path.criterion.soil")
        case .seed:
            return String(localized: "PostSeedJourney.path.criterion.seed")
        case .ripening:
            return String(localized: "PostSeedJourney.path.criterion.ripening")
        case .harvest:
            return String(localized: "PostSeedJourney.path.criterion.harvest")
        case .abundance:
            return String(localized: "PostSeedJourney.path.criterion.abundance")
        }
    }

    private func dotFill(for level: JournalCompletionLevel) -> Color {
        if level == highlightedLevel {
            return AppTheme.accent.opacity(0.35)
        }
        return AppTheme.journalBackground
    }

    private func dotBorder(for level: JournalCompletionLevel) -> Color {
        if level == highlightedLevel {
            return AppTheme.accent
        }
        return AppTheme.journalBorder
    }
}

// MARK: - Sample insights preview

struct PostSeedJourneyInsightsPreview: View {
    private static let fadeBandHeight: CGFloat = 120
    private static let previewClipHeight: CGFloat = 328

    /// Same review period as ``ReviewScreen`` (past seven calendar days) and the shared “%1$@ to %2$@” range line.
    private var sampleWeekRangeLine: String {
        let calendar = Calendar.current
        let period = ReviewInsightsPeriod.currentPeriod(containing: Date(), calendar: calendar)
        let weekStart = period.lowerBound
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: period.upperBound) ?? period.upperBound
        let startText = weekStart.formatted(.dateTime.month(.abbreviated).day())
        let endText = inclusiveEnd.formatted(.dateTime.month(.abbreviated).day())
        return String(
            format: String(localized: "%1$@ to %2$@"),
            startText,
            endText
        )
    }

    var body: some View {
        sampleContent
            .compositingGroup()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: 0.56),
                        .init(color: .white.opacity(0.35), location: 0.84),
                        .init(color: .clear, location: 1)
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
                        AppTheme.background.opacity(0),
                        AppTheme.background.opacity(0.55),
                        AppTheme.background
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: Self.fadeBandHeight)
                .allowsHitTesting(false)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "PostSeedJourney.sampleInsights.a11yLabel"))
    }

    private var sampleContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "This Week"))
                .font(AppTheme.warmPaperHeader)
                .foregroundStyle(AppTheme.reviewTextPrimary)

            Text(sampleWeekRangeLine)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)

            Text(String(localized: "Insights"))
                .font(AppTheme.warmPaperBody.weight(.semibold))
                .foregroundStyle(AppTheme.reviewTextPrimary)

            VStack(alignment: .leading, spacing: 8) {
                sampleInsightRow(
                    observation: String(localized: "PostSeedJourney.sampleInsights.row1.observation"),
                    action: String(localized: "PostSeedJourney.sampleInsights.row1.action")
                )

                Divider()

                sampleInsightRow(
                    observation: String(localized: "PostSeedJourney.sampleInsights.row2.observation"),
                    action: String(localized: "PostSeedJourney.sampleInsights.row2.action")
                )
            }

            // Extra lines so fade has content to soften against
            Text(String(localized: "PostSeedJourney.sampleInsights.filler"))
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.reviewPaper)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppTheme.border.opacity(0.4), lineWidth: 1)
        )
    }

    /// Mirrors ``ReviewWeeklyInsightsSection``: body observation plus muted follow-up line (not an in-app text field).
    private func sampleInsightRow(observation: String, action: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(observation)
                .font(AppTheme.warmPaperBody)
                .foregroundStyle(AppTheme.reviewTextPrimary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(action)
                .font(AppTheme.warmPaperMeta)
                .foregroundStyle(AppTheme.reviewTextMuted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - iCloud card (parity with Data & Privacy)

struct PostSeedJourneyICloudCard: View {
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
                    Toggle(String(localized: "iCloud sync"), isOn: $isICloudSyncEnabled)
                        .font(AppTheme.warmPaperBody)
                        .foregroundStyle(AppTheme.settingsTextPrimary)
                        .tint(AppTheme.accent)
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
            return String(localized: "DataPrivacy.storage.fallbackLocal")
        }
        return String(localized: "DataPrivacy.storage.localOnly")
    }

    private var attentionMessage: String? {
        if let bucket = iCloudAccountState.displayedBucket {
            switch bucket {
            case .noAccount:
                return String(localized: "DataPrivacy.attention.noAccount.summary")
            case .restricted:
                return String(localized: "DataPrivacy.attention.restricted.summary")
            case .temporarilyUnavailable:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "DataPrivacy.attention.tempUnavailableMismatch.summary")
                }
                return String(localized: "DataPrivacy.attention.tempUnavailable")
            case .couldNotDetermine:
                if !preferenceMatchesEffectiveStore {
                    return String(localized: "DataPrivacy.attention.unknownMismatch.summary")
                }
                return String(localized: "DataPrivacy.attention.unknown")
            case .available:
                break
            }
        }

        if persistenceRuntimeSnapshot.startupUsedCloudKitFallback, isICloudSyncEnabled {
            return String(localized: "DataPrivacy.attention.retryICloudAfterRelaunch.summary")
        }

        if !preferenceMatchesEffectiveStore {
            if shouldShowICloudSyncToggle {
                return String(localized: "DataPrivacy.attention.toggleChangedRelaunch.summary")
            }
            return String(localized: "DataPrivacy.attention.preferenceMismatchRelaunch.summary")
        }

        return nil
    }

    @ViewBuilder
    private var storageSummaryBlock: some View {
        if isJournalOnCloudKitStore {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                Text(String(localized: "DataPrivacy.storage.heading"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(String(localized: "DataPrivacy.a11y.storage.cloudActive"))
        } else {
            VStack(alignment: .leading, spacing: AppTheme.spacingTight / 2) {
                Text(String(localized: "DataPrivacy.storage.heading"))
                    .font(AppTheme.warmPaperMeta)
                    .foregroundStyle(AppTheme.settingsTextMuted)
                Text(primaryStorageBody)
                    .font(AppTheme.warmPaperBody)
                    .foregroundStyle(AppTheme.settingsTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(localized: "DataPrivacy.a11y.storage"))
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
                        localized:
                            "Opens iOS Settings where you can sign in to iCloud or review restrictions."
                    ),
                    emphasis: .prominent
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "DataPrivacy.a11y.nextSteps"))
    }
}

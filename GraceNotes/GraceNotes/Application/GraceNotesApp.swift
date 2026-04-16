//
//  GraceNotesApp.swift
//  GraceNotes
//
//  Created by Kip on 2026/3/15.
//

import SwiftUI
import SwiftData
import UIKit

@main
struct GraceNotesApp: App {
    @UIApplicationDelegateAdaptor(GraceNotesAppDelegate.self) private var appDelegate
    private let isRunningUITests: Bool
    private let isRunningUnitTests: Bool
    @StateObject private var startupCoordinator: StartupCoordinator
    @StateObject private var appNavigation = AppNavigationModel()
    @State private var uiTestPersistenceController: PersistenceController?
    @State private var hasRunDeferredStartupTasks = false
    @AppStorage(FirstRunOnboardingStorageKeys.completed) private var hasCompletedOnboarding = false
    @AppStorage(JournalAppearanceStorageKeys.todayMode)
    private var journalTodayAppearanceRaw = JournalAppearanceMode.standard.rawValue

    init() {
        let startupTrace = PerformanceTrace.begin("App.init")
        let processInfo = ProcessInfo.processInfo
        isRunningUITests = ProcessInfo.graceNotesIsRunningUITests
        isRunningUnitTests = ProcessInfo.graceNotesIsRunningHostedUnitTests

        if !isRunningUnitTests {
            JournalTutorialStorageKeys.migrateLegacyKeysIfNeeded(using: .standard)
            JournalAppearanceMode.migrateLegacyJournalAppearanceRawValueIfNeeded(defaults: .standard)
            _ = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: .standard)
            JournalOnboardingProgress.migrateLegacyPostSeedOrientationFlagsIfNeeded(using: .standard)
            JournalOnboardingProgress.migrateLegacyAppTourSeenFlagIfNeeded(using: .standard)
            PastStatisticsIntervalPreference.bootstrapUserDefaultsIfNeeded(defaults: .standard)
            AppLaunchVersionTracker.applyLaunch()
            _ = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: .standard)
        }

        if isRunningUITests, processInfo.arguments.contains("-reset-journal-tutorial") {
            JournalTutorialProgress.resetAll()
            JournalOnboardingProgress.resetAll()
        }

        let preloadedUITestController: PersistenceController?
        if isRunningUITests {
            _startupCoordinator = StateObject(wrappedValue: StartupCoordinator(timing: .uiTesting))
            do {
                preloadedUITestController = try PersistenceController.makeForUITesting()
            } catch {
                preloadedUITestController = nil
                PerformanceTrace.instant("App.uiTestPersistenceBootstrapFailed")
            }
        } else {
            _startupCoordinator = StateObject(wrappedValue: StartupCoordinator())
            preloadedUITestController = nil
        }
        _uiTestPersistenceController = State(initialValue: preloadedUITestController)
        PerformanceTrace.end("App.init", startedAt: startupTrace)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningUnitTests {
                    Color.clear
                } else if let uiTestController = uiTestPersistenceController {
                    uiTestRootView(using: uiTestController)
                } else {
                    startupRootView
                }
            }
            .environment(\.font, AppTheme.outfitUI)
        }
    }

    @ViewBuilder
    private func uiTestRootView(using controller: PersistenceController) -> some View {
        mainTabView
            .background(AppTheme.background)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .tint(AppTheme.accent)
            .environmentObject(appNavigation)
            .modelContainer(controller.container)
            .environment(\.persistenceRuntimeSnapshot, controller.runtimeSnapshot)
    }

    @ViewBuilder
    private var startupRootView: some View {
        switch startupCoordinator.phase {
        case .loading, .reassurance, .retryableFailure:
            StartupLoadingView(
                state: loadingSurfaceState,
                isRetrying: startupCoordinator.isStartingUp,
                onRetry: {
                    startupCoordinator.retry()
                }
            )
            .task {
                startupCoordinator.startIfNeeded()
            }
            .background(AppTheme.background)
        case .ready(let controller):
            readyContent
                .background(AppTheme.background)
                .toolbarBackground(AppTheme.background, for: .tabBar)
                .tint(AppTheme.accent)
                .environmentObject(appNavigation)
                .task {
                    await runDeferredStartupTasksIfNeeded(using: controller)
                }
                .modelContainer(controller.container)
                .environment(\.persistenceRuntimeSnapshot, controller.runtimeSnapshot)
                .modifier(
                    ScheduledBackupSceneModifier(
                        modelContainer: controller.container,
                        enabled: hasCompletedOnboarding && !isRunningUITests
                    )
                )
        }
    }

    private var loadingSurfaceState: StartupLoadingView.State {
        switch startupCoordinator.phase {
        case .loading:
            return .loading(
                message: startupCoordinator.startupMessage,
                isReassurance: false
            )
        case .reassurance:
            return .loading(
                message: startupCoordinator.startupMessage,
                isReassurance: true
            )
        case .retryableFailure(let message):
            return .retryableFailure(message: message)
        case .ready:
            return .loading(
                message: String(localized: "startup.status.settingUp"),
                isReassurance: false
            )
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        if isRunningUITests {
            mainTabView
                .environmentObject(appNavigation)
        } else if !hasCompletedOnboarding {
            OnboardingScreen {
                hasCompletedOnboarding = true
            }
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        let isBloomAtmosphereGlobal =
            JournalAppearanceMode.resolveStored(rawValue: journalTodayAppearanceRaw) == .bloom

        // App-wide Bloom paper, leaves, and forced light scheme are intentional (#125):
        // Past/Settings stay visually cohesive with Today.
        return ZStack {
            if isBloomAtmosphereGlobal {
                BloomPaperBackgroundView()
            }

            TabView(selection: $appNavigation.selectedTab) {
                TodayTabRoot()
                    .tabItem {
                        Label(String(localized: "shell.tab.today"), image: "pen-scribble")
                    }
                    .tag(AppTab.today)
                NavigationStack {
                    DeferredReviewRoot(isSelected: appNavigation.selectedTab == .history)
                }
                .tabItem {
                    Label(String(localized: "shell.tab.past"), image: "calendar")
                }
                .tag(AppTab.history)
                NavigationStack {
                    SettingsScreen()
                }
                .tabItem {
                    Label(String(localized: "shell.tab.settings"), image: "nodes-2")
                }
                .tag(AppTab.settings)
            }

            if isBloomAtmosphereGlobal {
                GlobalBloomLeavesOverlayLayer()
            }
        }
        .environment(\.journalBloomAtmosphereHosted, isBloomAtmosphereGlobal)
        .preferredColorScheme(isBloomAtmosphereGlobal ? .light : nil)
        .modifier(DailyReminderRefreshOnActiveModifier())
    }

    @MainActor
    private func runDeferredStartupTasksIfNeeded(using controller: PersistenceController) async {
        guard !hasRunDeferredStartupTasks else { return }
        hasRunDeferredStartupTasks = true

#if USE_DEMO_DATABASE
        PerformanceTrace.instant("Starting deferred demo seeding")
        await Task.yield()
        let context = ModelContext(controller.container)
        DemoDataSeeder.seedIfNeeded(context: context)
#endif
    }
}

private struct DeferredReviewRoot: View {
    let isSelected: Bool
    @State private var hasOpenedReviewTab = false

    var body: some View {
        Group {
            if hasOpenedReviewTab {
                ReviewScreen()
            } else {
                Color.clear
                    .navigationTitle(String(localized: "shell.tab.past"))
            }
        }
        // Past defers `ReviewScreen` until the tab is actually selected (default tab is Today). Use
        // synchronous callbacks for the open gate: a `.task` body can be cancelled before it assigns
        // `hasOpenedReviewTab` if `await` is ever inserted ahead of that assignment.
        .onAppear {
            openPastTabIfNeeded()
        }
        .onChange(of: isSelected) { _, _ in
            openPastTabIfNeeded()
        }
    }

    private func openPastTabIfNeeded() {
        guard isSelected, !hasOpenedReviewTab else { return }
        hasOpenedReviewTab = true
        PerformanceTrace.instant("ReviewScreen.deferredUntilSelected")
    }
}

private struct DailyReminderRefreshOnActiveModifier: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { @MainActor in
                await DailyReminderNotificationSync.rescheduleEnabledReminderIfNeeded(modelContext: modelContext)
            }
        }
    }
}

private struct ScheduledBackupSceneModifier: ViewModifier {
    let modelContainer: ModelContainer
    let enabled: Bool

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content.onChange(of: scenePhase) { _, phase in
            guard enabled, phase == .active else { return }
            Task { await ScheduledBackupRunner.runIfDue(modelContainer: modelContainer) }
        }
    }
}

private struct GlobalBloomLeavesOverlayLayer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        BloomLeavesOverlaySeam(reduceMotion: reduceMotion)
    }
}

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

    init() {
        let startupTrace = PerformanceTrace.begin("App.init")
        let processInfo = ProcessInfo.processInfo
        let isXCTestSession = processInfo.environment["XCTestConfigurationFilePath"] != nil
        isRunningUITests = ProcessInfo.graceNotesIsRunningUITests
        isRunningUnitTests = isXCTestSession && !isRunningUITests

        if !isRunningUnitTests {
            _ = ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: .standard)
            AppLaunchVersionTracker.applyLaunch()
            _ = JournalOnboardingProgress.resolvedHasCompletedGuidedJournal(using: .standard)
            LegacyAIInsightsUserDefaultsMigration.migrateIfNeeded()
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
                message: String(localized: "We are setting up your private Grace Notes space..."),
                isReassurance: false
            )
        }
    }

    @ViewBuilder
    private var readyContent: some View {
        if isRunningUITests {
            mainTabView
        } else if !hasCompletedOnboarding {
            OnboardingScreen {
                hasCompletedOnboarding = true
            }
        } else {
            mainTabView
        }
    }

    private var mainTabView: some View {
        TabView(selection: $appNavigation.selectedTab) {
            NavigationStack {
                JournalScreen()
            }
            .tabItem {
                Label(String(localized: "Today"), systemImage: "doc.text")
            }
            .tag(AppTab.today)
            NavigationStack {
                DeferredReviewRoot(isSelected: appNavigation.selectedTab == .history)
            }
            .tabItem {
                Label(String(localized: "Review"), systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)
            NavigationStack {
                SettingsScreen()
            }
            .tabItem {
                Label(String(localized: "Settings"), systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
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
                    .navigationTitle(String(localized: "Review"))
            }
        }
        .onChange(of: isSelected) { _, selected in
            guard selected, !hasOpenedReviewTab else { return }
            hasOpenedReviewTab = true
            PerformanceTrace.instant("ReviewScreen.deferredUntilSelected")
        }
        .task {
            guard isSelected, !hasOpenedReviewTab else { return }
            hasOpenedReviewTab = true
            PerformanceTrace.instant("ReviewScreen.deferredUntilSelected")
        }
    }
}

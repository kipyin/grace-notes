//
//  GraceNotesApp.swift
//  GraceNotes
//
//  Created by Kip on 2026/3/15.
//

import SwiftUI
import SwiftData

@main
struct GraceNotesApp: App {
    private enum AppTab: Hashable {
        case today
        case history
        case settings
    }

    private let persistenceController: PersistenceController
    private let isRunningUITests: Bool
    private let isRunningUnitTests: Bool
    @State private var hasRunDeferredStartupTasks = false
    @State private var selectedTab: AppTab = .today
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let startupTrace = PerformanceTrace.begin("App.init")
        persistenceController = PersistenceController.shared
        let processInfo = ProcessInfo.processInfo
        let isXCTestSession = processInfo.environment["XCTestConfigurationFilePath"] != nil
        let isUITestBundle = processInfo.environment["XCTestBundlePath"]?.contains("UITests") == true
        let hasUITestLaunchArgument = processInfo.arguments.contains("-ui-testing")
        let hasUITestEnvironmentFlag = processInfo.environment["FIVECUBED_UI_TESTING"]
            .map { value in
                let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return normalizedValue == "1" || normalizedValue == "true" || normalizedValue == "yes"
            } ?? false
        isRunningUITests = isUITestBundle || hasUITestLaunchArgument || hasUITestEnvironmentFlag
        isRunningUnitTests = isXCTestSession && !isRunningUITests
        PerformanceTrace.end("App.init", startedAt: startupTrace)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningUnitTests {
                    Color.clear
                } else if isRunningUITests {
                    mainTabView
                } else if !hasCompletedOnboarding {
                    OnboardingScreen {
                        hasCompletedOnboarding = true
                    }
                } else {
                    mainTabView
                }
            }
            .preferredColorScheme(.light)
            .background(AppTheme.background)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .tint(AppTheme.accent)
            .task {
                await runDeferredStartupTasksIfNeeded()
            }
        }
        .modelContainer(persistenceController.container)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                JournalScreen()
            }
            .tabItem {
                Label("Today", systemImage: "doc.text")
            }
            .tag(AppTab.today)
            NavigationStack {
                if selectedTab == .history {
                    ReviewScreen()
                } else {
                    Color.clear
                        .onAppear {
                            PerformanceTrace.instant("ReviewScreen.deferredUntilSelected")
                        }
                }
            }
            .tabItem {
                Label("Review", systemImage: "clock.arrow.circlepath")
            }
            .tag(AppTab.history)
            NavigationStack {
                SettingsScreen()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(AppTab.settings)
        }
    }

    @MainActor
    private func runDeferredStartupTasksIfNeeded() async {
        guard !hasRunDeferredStartupTasks else { return }
        hasRunDeferredStartupTasks = true

#if USE_DEMO_DATABASE
        guard PersistenceController.isDemoDatabaseEnabled else { return }
        PerformanceTrace.instant("Starting deferred demo seeding")
        await Task.yield()
        let context = ModelContext(persistenceController.container)
        DemoDataSeeder.seedIfNeeded(context: context)
#endif
    }
}

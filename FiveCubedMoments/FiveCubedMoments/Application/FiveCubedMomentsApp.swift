//
//  FiveCubedMomentsApp.swift
//  FiveCubedMoments
//
//  Created by Kip on 2026/3/15.
//

import SwiftUI
import SwiftData

@main
struct FiveCubedMomentsApp: App {
    private enum AppTab: Hashable {
        case today
        case history
        case settings
    }

    private let persistenceController: PersistenceController
    private let isRunningTests: Bool
    @State private var hasRunDeferredStartupTasks = false
    @State private var selectedTab: AppTab = .today

    init() {
        let startupTrace = PerformanceTrace.begin("App.init")
        persistenceController = PersistenceController.shared
        isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        PerformanceTrace.end("App.init", startedAt: startupTrace)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunningTests {
                    Color.clear
                } else {
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
                                HistoryScreen()
                            } else {
                                Color.clear
                                    .onAppear {
                                        PerformanceTrace.instant("HistoryScreen.deferredUntilSelected")
                                    }
                            }
                        }
                        .tabItem {
                            Label("History", systemImage: "clock.arrow.circlepath")
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

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
    private let persistenceController: PersistenceController

    init() {
        let controller = PersistenceController.shared
        if PersistenceController.isDemoDatabaseEnabled {
#if USE_DEMO_DATABASE
            let context = ModelContext(controller.container)
            DemoDataSeeder.seedIfNeeded(context: context)
#endif
        }
        persistenceController = controller
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    JournalScreen()
                }
                .tabItem {
                    Label("Today", systemImage: "doc.text")
                }
                NavigationStack {
                    HistoryScreen()
                }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                NavigationStack {
                    SettingsScreen()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .preferredColorScheme(.light)
            .background(AppTheme.background)
            .toolbarBackground(AppTheme.background, for: .tabBar)
            .tint(AppTheme.accent)
        }
        .modelContainer(persistenceController.container)
    }
}

import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    nonisolated(unsafe) static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
    static let shared = PersistenceController(cloudSyncEnabled: isCloudSyncEnabled)
    static let isDemoDatabaseEnabled: Bool = {
#if USE_DEMO_DATABASE
        true
#else
        false
#endif
    }()
    static var isCloudSyncEnabled: Bool {
#if USE_DEMO_DATABASE
        false
#else
        UserDefaults.standard.object(forKey: iCloudSyncEnabledKey) as? Bool ?? true
#endif
    }

    let container: ModelContainer

    /// Creates the SwiftData container. On failure, calls `fatalError` because the app cannot
    /// function without persistence. Future improvement: surface the error to the user
    /// (e.g., show an error screen) instead of crashing for production resilience.
    private init(inMemory: Bool = false, cloudSyncEnabled: Bool = true) {
        let startupTrace = PerformanceTrace.begin("PersistenceController.init")
        let schema = Schema([JournalEntry.self])
        let configuration = Self.makeConfiguration(
            schema: schema,
            inMemory: inMemory,
            cloudSyncEnabled: cloudSyncEnabled
        )
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
            PerformanceTrace.end("PersistenceController.init", startedAt: startupTrace)
        } catch {
            if !inMemory, cloudSyncEnabled {
                do {
                    let fallbackConfiguration = Self.makeConfiguration(
                        schema: schema,
                        inMemory: false,
                        cloudSyncEnabled: false
                    )
                    container = try ModelContainer(for: schema, configurations: fallbackConfiguration)
                    Self.disableCloudSyncAfterFallback()
                    PerformanceTrace.end("PersistenceController.init.fallback", startedAt: startupTrace)
                } catch {
                    PerformanceTrace.end("PersistenceController.init.failed", startedAt: startupTrace)
                    fatalError("Failed to create SwiftData container (including local fallback): \(error)")
                }
            } else {
                PerformanceTrace.end("PersistenceController.init.failed", startedAt: startupTrace)
                fatalError("Failed to create SwiftData container: \(error)")
            }
        }
    }

    private static func disableCloudSyncAfterFallback() {
        UserDefaults.standard.set(false, forKey: iCloudSyncEnabledKey)
    }

    private static func makeConfiguration(
        schema: Schema,
        inMemory: Bool,
        cloudSyncEnabled: Bool
    ) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
#if USE_DEMO_DATABASE
        let cloudDatabase: ModelConfiguration.CloudKitDatabase = cloudSyncEnabled ? .automatic : .none
        return ModelConfiguration(schema: schema, url: demoStoreURL, cloudKitDatabase: cloudDatabase)
#else
        let cloudDatabase: ModelConfiguration.CloudKitDatabase = cloudSyncEnabled ? .automatic : .none
        return ModelConfiguration(schema: schema, cloudKitDatabase: cloudDatabase)
#endif
    }

#if USE_DEMO_DATABASE
    private static var demoStoreURL: URL {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupportURL ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("Demo.store", isDirectory: false)
    }
#endif
}

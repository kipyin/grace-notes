import Foundation
import SwiftData

final class PersistenceController {
    private static let startupBootstrapQueue = DispatchQueue(
        label: "com.gracenotes.persistence.bootstrap",
        qos: .userInitiated
    )

    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
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
        cloudSyncEnabled(using: .standard)
#endif
    }

    static func cloudSyncEnabled(using defaults: UserDefaults) -> Bool {
        defaults.object(forKey: iCloudSyncEnabledKey) as? Bool ?? true
    }

    let container: ModelContainer

    private init(container: ModelContainer) {
        self.container = container
    }

    static func makeForStartup() async throws -> PersistenceController {
        let cloudSyncEnabled = isCloudSyncEnabled
        return try await withCheckedThrowingContinuation { continuation in
            startupBootstrapQueue.async {
                do {
                    let controller = try makeController(inMemory: false, cloudSyncEnabled: cloudSyncEnabled)
                    continuation.resume(returning: controller)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    static func makeForUITesting() throws -> PersistenceController {
        try makeController(inMemory: false, cloudSyncEnabled: false)
    }

    static func makeInMemoryForTesting() throws -> PersistenceController {
        try makeController(inMemory: true, cloudSyncEnabled: false)
    }

    private static func makeController(inMemory: Bool, cloudSyncEnabled: Bool) throws -> PersistenceController {
        let startupTrace = PerformanceTrace.begin("PersistenceController.makeController")
        let schema = Schema([JournalEntry.self])
        let configuration = Self.makeConfiguration(
            schema: schema,
            inMemory: inMemory,
            cloudSyncEnabled: cloudSyncEnabled
        )
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            PerformanceTrace.end("PersistenceController.makeController", startedAt: startupTrace)
            return PersistenceController(container: container)
        } catch {
            if !inMemory, cloudSyncEnabled {
                do {
                    let fallbackConfiguration = Self.makeConfiguration(
                        schema: schema,
                        inMemory: false,
                        cloudSyncEnabled: false
                    )
                    let container = try ModelContainer(for: schema, configurations: fallbackConfiguration)
                    PerformanceTrace.end("PersistenceController.makeController.fallback", startedAt: startupTrace)
                    return PersistenceController(container: container)
                } catch {
                    PerformanceTrace.end("PersistenceController.makeController.failed", startedAt: startupTrace)
                    throw PersistenceControllerError.unableToCreateContainer(error)
                }
            } else {
                PerformanceTrace.end("PersistenceController.makeController.failed", startedAt: startupTrace)
                throw PersistenceControllerError.unableToCreateContainer(error)
            }
        }
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

enum PersistenceControllerError: LocalizedError {
    case unableToCreateContainer(Error)

    var errorDescription: String? {
        String(localized: "We couldn't finish setting up your journal space. Please try again.")
    }
}

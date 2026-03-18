import Foundation
import SwiftData

final class PersistenceController {
    private static let startupBootstrapQueue = DispatchQueue(
        label: "com.gracenotes.persistence.bootstrap",
        qos: .userInitiated
    )

    static let iCloudSyncEnabledKey = "iCloudSyncEnabled"
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
    let runtimeSnapshot: PersistenceRuntimeSnapshot

    private init(container: ModelContainer, runtimeSnapshot: PersistenceRuntimeSnapshot) {
        self.container = container
        self.runtimeSnapshot = runtimeSnapshot
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
        let startupTrace = PerformanceTrace.begin("PersistenceController.makeForUITesting")
        let schema = Schema([JournalEntry.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: uiTestStoreURL,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: configuration)
            try seedUITestDataIfNeeded(in: container)
            PerformanceTrace.end("PersistenceController.makeForUITesting", startedAt: startupTrace)
            let snapshot = PersistenceRuntimeSnapshot.forDiskLaunch(
                userRequestedCloudSync: Self.cloudSyncEnabled(using: .standard),
                storeUsesCloudKit: false,
                startupUsedCloudKitFallback: false
            )
            return PersistenceController(container: container, runtimeSnapshot: snapshot)
        } catch {
            PerformanceTrace.end("PersistenceController.makeForUITesting.failed", startedAt: startupTrace)
            throw PersistenceControllerError.unableToCreateContainer(error)
        }
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
            let snapshot: PersistenceRuntimeSnapshot
            if inMemory {
                snapshot = .forInMemory(userRequestedCloudSync: cloudSyncEnabled)
            } else {
                snapshot = .forDiskLaunch(
                    userRequestedCloudSync: cloudSyncEnabled,
                    storeUsesCloudKit: cloudSyncEnabled,
                    startupUsedCloudKitFallback: false
                )
            }
            return PersistenceController(container: container, runtimeSnapshot: snapshot)
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
                    let snapshot = PersistenceRuntimeSnapshot.forDiskLaunch(
                        userRequestedCloudSync: true,
                        storeUsesCloudKit: false,
                        startupUsedCloudKitFallback: true
                    )
                    return PersistenceController(container: container, runtimeSnapshot: snapshot)
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

    private static var uiTestStoreURL: URL {
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let uiTestDirectory = appSupportURL.appendingPathComponent("GraceNotesUITests", isDirectory: true)
        if !fileManager.fileExists(atPath: uiTestDirectory.path) {
            try? fileManager.createDirectory(at: uiTestDirectory, withIntermediateDirectories: true)
        }

        // Use XCTest configuration path to scope storage per test run.
        // This keeps relaunches in the same run persistent while preventing
        // stale data from previous test runs from leaking into current runs.
        let sessionKey = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] ?? UUID().uuidString
        let safeSessionKey = sessionKey
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileName = "ui-test-\(safeSessionKey).store"
        return uiTestDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func seedUITestDataIfNeeded(in container: ModelContainer) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<JournalEntry>()
        descriptor.fetchLimit = 1
        if let _ = try context.fetch(descriptor).first {
            return
        }

        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        let seededEntry = JournalEntry(
            entryDate: previousDay,
            gratitudes: [JournalItem(fullText: "Seed gratitude for timeline")],
            needs: [JournalItem(fullText: "Seed need for timeline")],
            people: [JournalItem(fullText: "Seed person for timeline")],
            createdAt: now,
            updatedAt: now
        )
        context.insert(seededEntry)
        try context.save()
    }
}

enum PersistenceControllerError: LocalizedError {
    case unableToCreateContainer(Error)

    var errorDescription: String? {
        String(localized: "We couldn't finish setting up your journal space. Please try again.")
    }
}

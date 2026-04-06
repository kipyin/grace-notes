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
        ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: .standard)
#endif
    }

    static func cloudSyncEnabled(using defaults: UserDefaults) -> Bool {
        ICloudSyncPreferenceResolver.resolvedCloudSyncEnabled(using: defaults)
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

    /// When `-grace-notes-reset-uitest-store` is present, deletes the on-disk UI-test store before opening it.
    /// UI tests otherwise reuse one SwiftData file per session key, so data would accumulate across test methods.
    static func resetUITestStoreIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-grace-notes-reset-uitest-store") else { return }
        let url = uiTestStoreURL
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        ReviewInsightsCache.wipeDiskPayloadForUITestStoreReset()
    }

    static func makeForUITesting() throws -> PersistenceController {
        resetUITestStoreIfRequested()
        let startupTrace = PerformanceTrace.begin("PersistenceController.makeForUITesting")
        let schema = Schema([Journal.self])
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
        let schema = Schema([Journal.self])
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

        // Prefer XCTest's config path so parallel runs stay isolated. After `terminate()` + `launch()`,
        // that env var is often missing in the app; reuse the last key so relaunch hits the same store.
        let markerURL = uiTestDirectory.appendingPathComponent("active-uitest-session-key.txt", isDirectory: false)
        let configPath = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] ?? ""
        let sessionKey: String
        if !configPath.isEmpty {
            sessionKey = configPath
            try? configPath.write(to: markerURL, atomically: true, encoding: .utf8)
        } else if let remembered = try? String(contentsOf: markerURL, encoding: .utf8),
                  !remembered.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sessionKey = remembered
        } else {
            sessionKey = UUID().uuidString
            try? sessionKey.write(to: markerURL, atomically: true, encoding: .utf8)
        }

        let safeSessionKey = sessionKey
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let fileName = "ui-test-\(safeSessionKey).store"
        return uiTestDirectory.appendingPathComponent(fileName, isDirectory: false)
    }

    private static func seedUITestDataIfNeeded(in container: ModelContainer) throws {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Journal>()
        descriptor.fetchLimit = 1
        if try context.fetch(descriptor).first != nil {
            return
        }

        let now = Date.now
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let previousDay = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        if ProcessInfo.graceNotesUITestWideReviewRhythmSeed {
            try insertWideReviewRhythmUITestSeed(
                context: context,
                calendar: calendar,
                today: today,
                now: now
            )
        } else {
            // Short, distinct lines so NL distillation does not emit overlapping concepts that
            // sum to trending floors from a single entry (see `WeeklyReviewAggregatesMostRecurringTests`).
            let seededEntry = Journal(
                entryDate: previousDay,
                gratitudes: [Entry(fullText: "sunlight")],
                needs: [Entry(fullText: "stretching")],
                people: [Entry(fullText: "Jordan")],
                createdAt: now,
                updatedAt: now
            )
            context.insert(seededEntry)
        }
        try context.save()
    }

    /// One lightweight entry per day so `rhythmHistory` spans dozens of columns (horizontal scrolling in Review).
    private static func insertWideReviewRhythmUITestSeed(
        context: ModelContext,
        calendar: Calendar,
        today: Date,
        now: Date
    ) throws {
        for dayOffset in 1...36 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let gratitudeSeed: String
            let needSeed: String
            switch dayOffset {
            case 1...6:
                gratitudeSeed = "rest"
                needSeed = "focus"
            case 7...13:
                gratitudeSeed = "walking"
                needSeed = "focus"
            case 14...20:
                gratitudeSeed = "family time"
                needSeed = "rest"
            default:
                let rolling = ["rest", "walking", "quiet morning"]
                gratitudeSeed = rolling[dayOffset % rolling.count]
                needSeed = rolling[(dayOffset + 1) % rolling.count]
            }
            let personSeed = dayOffset % 2 == 0 ? "Mia" : "Dad"
            let entry = Journal(
                entryDate: day,
                gratitudes: [Entry(fullText: gratitudeSeed)],
                needs: [Entry(fullText: needSeed)],
                people: [Entry(fullText: personSeed)],
                readingNotes: dayOffset % 3 == 0 ? "Short note about \(gratitudeSeed)." : "",
                reflections: dayOffset % 4 == 0 ? "Reflecting on \(needSeed)." : "",
                createdAt: now,
                updatedAt: now
            )
            context.insert(entry)
        }
    }
}

enum PersistenceControllerError: LocalizedError {
    case unableToCreateContainer(Error)

    var errorDescription: String? {
        String(localized: "startup.error.setupFailed")
    }
}

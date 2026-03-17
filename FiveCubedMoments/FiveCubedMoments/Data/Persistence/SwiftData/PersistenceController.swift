import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()
    static let isDemoDatabaseEnabled: Bool = {
#if USE_DEMO_DATABASE
        true
#else
        false
#endif
    }()

    let container: ModelContainer

    /// Creates the SwiftData container. On failure, calls `fatalError` because the app cannot
    /// function without persistence. Future improvement: surface the error to the user
    /// (e.g., show an error screen) instead of crashing for production resilience.
    private init(inMemory: Bool = false) {
        let schema = Schema([JournalEntry.self])
        let configuration = Self.makeConfiguration(schema: schema, inMemory: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }

    private static func makeConfiguration(schema: Schema, inMemory: Bool) -> ModelConfiguration {
        if inMemory {
            return ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
#if USE_DEMO_DATABASE
        return ModelConfiguration(schema: schema, url: demoStoreURL)
#else
        return ModelConfiguration(schema: schema)
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

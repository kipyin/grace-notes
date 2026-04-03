import SwiftData
@testable import GraceNotes

/// Shared in-memory SwiftData setup for unit tests.
///
/// Uses `isStoredInMemoryOnly: true` (same as ``PersistenceController.makeInMemoryForTesting()``).
/// Temporary on-disk store URLs in the app-hosted test process previously correlated with Simulator malloc crashes.
enum SwiftDataTestIsolation {
    static func makeModelContext() throws -> ModelContext {
        let schema = Schema([Journal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        return ModelContext(container)
    }
}

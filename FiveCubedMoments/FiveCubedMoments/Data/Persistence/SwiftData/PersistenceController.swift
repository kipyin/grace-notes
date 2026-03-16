import Foundation
import SwiftData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: ModelContainer

    /// Creates the SwiftData container. On failure, calls `fatalError` because the app cannot
    /// function without persistence. Future improvement: surface the error to the user
    /// (e.g., show an error screen) instead of crashing for production resilience.
    private init(inMemory: Bool = false) {
        let schema = Schema([JournalEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Failed to create SwiftData container: \(error)")
        }
    }
}

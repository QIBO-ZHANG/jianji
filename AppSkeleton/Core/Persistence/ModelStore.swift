import SwiftData

/// The whole SwiftData schema in one place so the app container, previews and tests
/// can never drift apart.
enum ModelStore {
    static var schema: Schema {
        Schema([TodoItem.self, NoteItem.self, LedgerEntry.self])
    }

    static func make() -> ModelContainer {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Unable to create the ModelContainer: \(error)")
        }
    }

    static func makeInMemory() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        } catch {
            fatalError("Unable to create the in-memory ModelContainer: \(error)")
        }
    }
}

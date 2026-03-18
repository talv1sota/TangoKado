import SwiftUI
import SwiftData

@main
struct TangoKadoApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([Deck.self, Flashcard.self])
        let config = ModelConfiguration(schema: schema)

        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed — delete old store and retry
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            // Also remove write-ahead log and shared memory files
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))

            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }

        SeedDataManager.seedIfNeeded(modelContext: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}

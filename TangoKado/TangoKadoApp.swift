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
            let url = config.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("store-wal"))

            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Seed on background-friendly main actor context after UI appears
                    SeedDataManager.seedIfNeeded(modelContext: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

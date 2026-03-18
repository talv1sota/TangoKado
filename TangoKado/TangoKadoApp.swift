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

        // Custom nav bar font — rounded design for a friendlier look
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let roundedLargeTitle = UIFont(
            descriptor: largeTitleFont.fontDescriptor.withDesign(.rounded)!,
            size: 34
        )
        let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let roundedTitle = UIFont(
            descriptor: titleFont.fontDescriptor.withDesign(.rounded)!,
            size: 17
        )

        UINavigationBar.appearance().largeTitleTextAttributes = [.font: roundedLargeTitle]
        UINavigationBar.appearance().titleTextAttributes = [.font: roundedTitle]
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    SeedDataManager.seedIfNeeded(modelContext: container.mainContext)
                }
        }
        .modelContainer(container)
    }
}

import Foundation
import SwiftData

@MainActor
enum SeedDataManager {
    static func seedIfNeeded(modelContext: ModelContext) {
        // No auto-seeding — users add languages via the Add Language view.
        // This method is kept for potential future use (e.g. default language on first launch).
    }
}

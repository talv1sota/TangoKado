import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        if hasSeenWelcome {
            DeckListView()
        } else {
            WelcomeView(hasSeenWelcome: $hasSeenWelcome)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
}

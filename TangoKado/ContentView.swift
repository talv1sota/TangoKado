import SwiftUI

struct ContentView: View {
    var body: some View {
        DeckListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
}

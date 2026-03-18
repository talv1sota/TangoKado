import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("appColorScheme") private var appColorScheme = 0 // 0=system, 1=light, 2=dark

    var body: some View {
        Group {
            if hasSeenWelcome {
                DeckListView()
            } else {
                WelcomeView(hasSeenWelcome: $hasSeenWelcome)
            }
        }
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
}

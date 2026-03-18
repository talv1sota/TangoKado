import Foundation
import SwiftData

@MainActor
enum SeedDataManager {
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Deck>()
        guard (try? modelContext.fetchCount(descriptor)) == 0 else { return }

        let languages: [(String, String, String, [(String, String)])] = [
            ("Italian", "Top 300 most used Italian words", "it-IT", ItalianWords.words),
            ("Russian", "Top 300 most used Russian words", "ru-RU", RussianWords.words),
            ("Japanese", "Top 300 most used Japanese words", "ja-JP", JapaneseWords.words),
            ("Dutch", "Top 300 most used Dutch words", "nl-NL", DutchWords.words),
            ("German", "Top 300 most used German words", "de-DE", GermanWords.words),
            ("Serbian", "Top 300 most used Serbian words", "hr-HR", SerbianWords.words),
        ]

        for (name, description, langCode, words) in languages {
            let deck = Deck(name: name, description: description, languageCode: langCode)
            for (index, (front, back)) in words.enumerated() {
                let card = Flashcard(front: front, back: back, rank: index + 1)
                card.deck = deck
                deck.cards.append(card)
            }
            modelContext.insert(deck)
        }
    }
}

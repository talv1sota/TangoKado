import Foundation
import SwiftData

@Model
final class Deck {
    var name: String
    var deckDescription: String
    var languageCode: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var cards: [Flashcard]

    init(name: String, description: String = "", languageCode: String = "en-US") {
        self.name = name
        self.deckDescription = description
        self.languageCode = languageCode
        self.createdAt = Date()
        self.cards = []
    }

    // Combined mastery
    var masteredCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .mastered }
    }

    var strugglingCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .struggling }
    }

    var unseenCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .unseen }
    }

    // Flashcard-specific
    var flashcardCorrect: Int {
        cards.reduce(0) { $0 + $1.correctCount }
    }

    var flashcardIncorrect: Int {
        cards.reduce(0) { $0 + $1.incorrectCount }
    }

    var flashcardStudied: Int {
        cards.filter { $0.totalReviews > 0 }.count
    }

    // Typing-specific
    var typingCorrect: Int {
        cards.reduce(0) { $0 + $1.typingCorrectCount }
    }

    var typingIncorrect: Int {
        cards.reduce(0) { $0 + $1.typingIncorrectCount }
    }

    var typingStudied: Int {
        cards.filter { $0.typingTotalReviews > 0 }.count
    }
}

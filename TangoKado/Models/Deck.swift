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

    var masteredCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .mastered }
    }

    var strugglingCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .struggling }
    }

    var unseenCards: [Flashcard] {
        cards.filter { $0.masteryStatus == .unseen }
    }

    var overallAccuracy: Double {
        let reviewed = cards.filter { $0.totalReviews > 0 }
        guard !reviewed.isEmpty else { return 0 }
        let totalCorrect = reviewed.reduce(0) { $0 + $1.correctCount }
        let totalAttempts = reviewed.reduce(0) { $0 + $1.totalReviews }
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }
}

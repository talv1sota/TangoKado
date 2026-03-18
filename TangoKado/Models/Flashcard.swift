import Foundation
import SwiftData

@Model
final class Flashcard {
    var front: String
    var back: String
    var rank: Int
    var createdAt: Date
    var lastReviewedAt: Date?
    var correctCount: Int
    var incorrectCount: Int

    @Relationship(inverse: \Deck.cards)
    var deck: Deck?

    init(front: String, back: String, rank: Int = 0) {
        self.front = front
        self.back = back
        self.rank = rank
        self.createdAt = Date()
        self.correctCount = 0
        self.incorrectCount = 0
    }

    var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total)
    }
}

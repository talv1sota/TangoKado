import Foundation
import SwiftUI
import SwiftData

enum MasteryStatus: String, CaseIterable {
    case mastered
    case struggling
    case unseen

    var label: String {
        switch self {
        case .mastered: return "Mastered"
        case .struggling: return "Struggling"
        case .unseen: return "New"
        }
    }

    var icon: String {
        switch self {
        case .mastered: return "checkmark.circle.fill"
        case .struggling: return "exclamationmark.triangle.fill"
        case .unseen: return "circle.dotted"
        }
    }

    var color: Color {
        switch self {
        case .mastered: return .green
        case .struggling: return .red
        case .unseen: return .secondary
        }
    }
}

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

    var totalReviews: Int {
        correctCount + incorrectCount
    }

    var accuracy: Double {
        guard totalReviews > 0 else { return 0 }
        return Double(correctCount) / Double(totalReviews)
    }

    var masteryStatus: MasteryStatus {
        guard totalReviews > 0 else { return .unseen }
        if totalReviews >= 3 && accuracy >= 0.8 { return .mastered }
        return .struggling
    }
}

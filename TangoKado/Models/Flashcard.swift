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
        case .struggling: return "Weak"
        case .unseen: return "New"
        }
    }

    var icon: String {
        switch self {
        case .mastered: return "checkmark.circle.fill"
        case .struggling: return "arrow.triangle.2.circlepath"
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
    var example: String
    var rank: Int
    var createdAt: Date
    var lastReviewedAt: Date?

    // Flashcard mode stats
    var correctCount: Int
    var incorrectCount: Int

    // Typing mode stats
    var typingCorrectCount: Int
    var typingIncorrectCount: Int

    @Relationship(inverse: \Deck.cards)
    var deck: Deck?

    init(front: String, back: String, example: String = "", rank: Int = 0) {
        self.front = front
        self.back = back
        self.example = example
        self.rank = rank
        self.createdAt = Date()
        self.correctCount = 0
        self.incorrectCount = 0
        self.typingCorrectCount = 0
        self.typingIncorrectCount = 0
    }

    var totalReviews: Int {
        correctCount + incorrectCount
    }

    var typingTotalReviews: Int {
        typingCorrectCount + typingIncorrectCount
    }

    var accuracy: Double {
        guard totalReviews > 0 else { return 0 }
        return Double(correctCount) / Double(totalReviews)
    }

    var typingAccuracy: Double {
        guard typingTotalReviews > 0 else { return 0 }
        return Double(typingCorrectCount) / Double(typingTotalReviews)
    }

    // Combined mastery considers both modes
    var masteryStatus: MasteryStatus {
        let total = totalReviews + typingTotalReviews
        guard total > 0 else { return .unseen }
        let totalCorrect = correctCount + typingCorrectCount
        let combinedAccuracy = Double(totalCorrect) / Double(total)
        if combinedAccuracy >= 0.8 { return .mastered }
        return .struggling
    }
}

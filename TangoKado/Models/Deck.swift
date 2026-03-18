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
}

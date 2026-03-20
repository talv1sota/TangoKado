import Foundation

struct WordResult: Codable {
    let front: String
    let back: String
}

struct SessionRecord: Codable, Identifiable {
    let id: UUID
    let date: Date
    let deckName: String
    let typingMode: Bool
    let correct: Int
    let incorrect: Int
    let total: Int
    var correctWords: [WordResult]?
    var incorrectWords: [WordResult]?

    var percentage: Int {
        guard total > 0 else { return 0 }
        return Int(Double(correct) / Double(total) * 100)
    }

    var modeLabel: String {
        typingMode ? "Typing" : "Flashcards"
    }
}

enum SessionHistory {
    private static let storageKey = "sessionHistory"
    private static let maxRecords = 100

    static func save(deckName: String, typingMode: Bool, correct: Int, incorrect: Int, total: Int, correctWords: [WordResult] = [], incorrectWords: [WordResult] = []) {
        var records = load()
        let record = SessionRecord(
            id: UUID(),
            date: Date(),
            deckName: deckName,
            typingMode: typingMode,
            correct: correct,
            incorrect: incorrect,
            total: total,
            correctWords: correctWords.isEmpty ? nil : correctWords,
            incorrectWords: incorrectWords.isEmpty ? nil : incorrectWords
        )
        records.insert(record, at: 0)
        if records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func load() -> [SessionRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([SessionRecord].self, from: data) else {
            return []
        }
        return records
    }

    static func records(for deckName: String) -> [SessionRecord] {
        load().filter { $0.deckName == deckName }
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    static func clear(for deckName: String) {
        let filtered = load().filter { $0.deckName != deckName }
        if let data = try? JSONEncoder().encode(filtered) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    static func delete(id: UUID) {
        let filtered = load().filter { $0.id != id }
        if let data = try? JSONEncoder().encode(filtered) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

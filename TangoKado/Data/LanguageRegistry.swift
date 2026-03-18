import Foundation

struct LanguageInfo: Identifiable {
    let id: String // language code
    let name: String
    let flag: String
    let words: [(String, String)]

    var code: String { id }
}

enum LanguageRegistry {
    static let available: [LanguageInfo] = [
        LanguageInfo(id: "it-IT", name: "Italian", flag: "\u{1F1EE}\u{1F1F9}", words: ItalianWords.words),
        LanguageInfo(id: "ru-RU", name: "Russian", flag: "\u{1F1F7}\u{1F1FA}", words: RussianWords.words),
        LanguageInfo(id: "ja-JP", name: "Japanese", flag: "\u{1F1EF}\u{1F1F5}", words: JapaneseWords.words),
        LanguageInfo(id: "nl-NL", name: "Dutch", flag: "\u{1F1F3}\u{1F1F1}", words: DutchWords.words),
        LanguageInfo(id: "de-DE", name: "German", flag: "\u{1F1E9}\u{1F1EA}", words: GermanWords.words),
        LanguageInfo(id: "hr-HR", name: "Croatian", flag: "\u{1F1ED}\u{1F1F7}", words: CroatianWords.words),
    ]

    static func language(for code: String) -> LanguageInfo? {
        available.first { $0.id == code }
    }
}

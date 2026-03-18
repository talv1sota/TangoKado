import Foundation

struct LanguageInfo: Identifiable {
    let id: String // language code
    let name: String
    let flag: String
    let words: [(String, String, String)]

    var code: String { id }
}

enum LanguageRegistry {
    static let available: [LanguageInfo] = [
        LanguageInfo(id: "es-ES", name: "Spanish", flag: "🇪🇸", words: SpanishWords.words),
        LanguageInfo(id: "fr-FR", name: "French", flag: "🇫🇷", words: FrenchWords.words),
        LanguageInfo(id: "pt-BR", name: "Portuguese", flag: "🇧🇷", words: PortugueseWords.words),
        LanguageInfo(id: "de-DE", name: "German", flag: "🇩🇪", words: GermanWords.words),
        LanguageInfo(id: "it-IT", name: "Italian", flag: "🇮🇹", words: ItalianWords.words),
        LanguageInfo(id: "nl-NL", name: "Dutch", flag: "🇳🇱", words: DutchWords.words),
        LanguageInfo(id: "hr-HR", name: "Croatian", flag: "🇭🇷", words: CroatianWords.words),
        LanguageInfo(id: "pl-PL", name: "Polish", flag: "🇵🇱", words: PolishWords.words),
        LanguageInfo(id: "tr-TR", name: "Turkish", flag: "🇹🇷", words: TurkishWords.words),
        LanguageInfo(id: "ru-RU", name: "Russian", flag: "🇷🇺", words: RussianWords.words),
        LanguageInfo(id: "ja-JP", name: "Japanese", flag: "🇯🇵", words: JapaneseWords.words),
        LanguageInfo(id: "ko-KR", name: "Korean", flag: "🇰🇷", words: KoreanWords.words),
        LanguageInfo(id: "zh-CN", name: "Chinese", flag: "🇨🇳", words: ChineseWords.words),
        LanguageInfo(id: "ar-SA", name: "Arabic", flag: "🇸🇦", words: ArabicWords.words),
    ]

    static func language(for code: String) -> LanguageInfo? {
        available.first { $0.id == code }
    }
}

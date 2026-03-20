import SwiftUI
import SwiftData

struct AddLanguageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingDecks: [Deck]

    private var addedLanguageCodes: Set<String> {
        Set(existingDecks.map { $0.languageCode })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(LanguageRegistry.available) { language in
                        let alreadyAdded = addedLanguageCodes.contains(language.code)
                        Button {
                            if !alreadyAdded {
                                addLanguage(language)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(language.flag)
                                    .font(.largeTitle)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(language.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }

                                Spacer()

                                if alreadyAdded {
                                    Label("Added", systemImage: "checkmark.circle.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                }
                            }
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyAdded)
                    }
                } header: {
                    Text("Tap to add")
                }
            }
            .navigationTitle("Add Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addLanguage(_ language: LanguageInfo) {
        guard !existingDecks.contains(where: { $0.languageCode == language.code }) else { return }
        let deck = Deck(
            name: language.name,
            description: "Top \(language.words.count) most used \(language.name) words",
            languageCode: language.code
        )
        for (index, (front, back, example)) in language.words.enumerated() {
            let card = Flashcard(front: front, back: back, example: example, rank: index + 1)
            card.deck = deck
            deck.cards.append(card)
        }
        modelContext.insert(deck)
    }
}

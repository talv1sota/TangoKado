import SwiftUI

struct AddCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let deck: Deck

    @State private var front = ""
    @State private var back = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case front, back
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Front") {
                    TextField("e.g. ciao", text: $front)
                        .focused($focusedField, equals: .front)
                }

                Section("Back") {
                    TextField("e.g. hello", text: $back)
                        .focused($focusedField, equals: .back)
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addCard()
                    }
                    .bold()
                    .disabled(front.isEmpty || back.isEmpty)
                }
            }
            .onAppear {
                focusedField = .front
            }
        }
    }

    private func addCard() {
        let card = Flashcard(front: front.trimmingCharacters(in: .whitespacesAndNewlines),
                             back: back.trimmingCharacters(in: .whitespacesAndNewlines))
        card.deck = deck
        deck.cards.append(card)
        dismiss()
    }
}

import SwiftUI

struct AddDeckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck Name") {
                    TextField("e.g. Spanish Basics", text: $name)
                }

                Section("Description (optional)") {
                    TextField("What's this deck about?", text: $description)
                }
            }
            .navigationTitle("New Deck")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createDeck()
                    }
                    .bold()
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func createDeck() {
        let deck = Deck(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines))
        modelContext.insert(deck)
        dismiss()
    }
}

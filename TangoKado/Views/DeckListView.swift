import SwiftUI
import SwiftData

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @State private var showingAddLanguage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if decks.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(decks) { deck in
                            NavigationLink(value: deck) {
                                DeckCard(deck: deck, onDelete: { deleteDeck(deck) })
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("TangoKado")
            .navigationDestination(for: Deck.self) { deck in
                DeckDetailView(deck: deck)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddLanguage = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddLanguage) {
                AddLanguageView()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
                .frame(height: 100)
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(.indigo.opacity(0.5))
            Text("Start Learning")
                .font(.title2.bold())
            Text("Add a language to begin studying")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button {
                showingAddLanguage = true
            } label: {
                Label("Add Language", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }

    private func deleteDeck(_ deck: Deck) {
        modelContext.delete(deck)
    }
}

struct DeckCard: View {
    let deck: Deck
    let onDelete: () -> Void
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                let flag = LanguageRegistry.language(for: deck.languageCode)?.flag ?? ""
                Text(flag)
                    .font(.title)
                Text(deck.name)
                    .font(.title3.bold())
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack {
                Label("\(deck.cards.count) cards", systemImage: "rectangle.stack.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                let reviewed = deck.cards.filter { $0.lastReviewedAt != nil }.count
                if reviewed > 0 {
                    Label("\(reviewed) studied", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete \(deck.name)?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct DeckDetailView: View {
    var deck: Deck
    @State private var showingAddCard = false
    @State private var showingStudySession = false

    var body: some View {
        List {
            if !deck.cards.isEmpty {
                Section {
                    Button {
                        showingStudySession = true
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading) {
                                Text("Start Studying")
                                    .font(.headline)
                                Text("\(deck.cards.count) cards, shuffled")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Cards (\(deck.cards.count))") {
                if deck.cards.isEmpty {
                    Text("No cards yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(deck.cards).sorted { $0.rank < $1.rank }) { (card: Flashcard) in
                        CardRowView(card: card, languageCode: deck.languageCode)
                    }
                }
            }
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddCard = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardView(deck: deck)
        }
        .fullScreenCover(isPresented: $showingStudySession) {
            StudySessionView(deck: deck)
        }
    }
}

struct CardRowView: View {
    let card: Flashcard
    let languageCode: String

    var body: some View {
        HStack(spacing: 12) {
            if card.rank > 0 {
                Text("#\(card.rank)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(card.front)
                    .font(.body.bold())
                Text(card.back)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                SpeechHelper.shared.speak(card.front, languageCode: languageCode)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
}

import SwiftUI
import SwiftData

// MARK: - Home Screen

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
            Spacer().frame(height: 100)
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

// MARK: - Deck Card (Home Screen)

struct DeckCard: View {
    let deck: Deck
    let onDelete: () -> Void
    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            deckCardHeader
            deckCardStats
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .contextMenu {
            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete \(deck.name)?", isPresented: $showingDeleteConfirm) {
            Button("Delete", role: .destructive) { onDelete() }
        }
    }

    private var deckCardHeader: some View {
        HStack {
            let flag = LanguageRegistry.language(for: deck.languageCode)?.flag ?? ""
            Text(flag).font(.title)
            Text(deck.name).font(.title3.bold())
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var deckCardStats: some View {
        HStack(spacing: 8) {
            Label("\(deck.cards.count)", systemImage: "rectangle.stack.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if deck.masteredCards.count > 0 {
                Label("\(deck.masteredCards.count)", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
            if deck.strugglingCards.count > 0 {
                Label("\(deck.strugglingCards.count)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if deck.unseenCards.count > 0 {
                Label("\(deck.unseenCards.count)", systemImage: "circle.dotted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Deck Detail View

enum CardFilter: String, CaseIterable {
    case all = "All"
    case mastered = "Mastered"
    case struggling = "Weak"
    case unseen = "New"
}

struct DeckDetailView: View {
    var deck: Deck
    @State private var showingAddCard = false
    @State private var showingStudySession = false
    @State private var showingStudyModePicker = false
    @State private var selectedFilter: CardFilter = .all
    @State private var studyCards: [Flashcard]? = nil

    var body: some View {
        List {
            if !deck.cards.isEmpty {
                studySection
                progressSection
                filterSection
            }
            cardsSection
        }
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAddCard = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardView(deck: deck)
        }
        .confirmationDialog("Study Mode", isPresented: $showingStudyModePicker) {
            studyModeButtons
        }
        .fullScreenCover(isPresented: $showingStudySession) {
            StudySessionView(deck: deck, specificCards: studyCards)
        }
    }

    // MARK: Study Section

    private var studySection: some View {
        Section {
            Button { showingStudyModePicker = true } label: {
                HStack {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading) {
                        Text("Start Studying")
                            .font(.headline)
                        Text("\(deck.cards.count) total · \(deck.strugglingCards.count) weak · \(deck.unseenCards.count) new")
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

    @ViewBuilder
    private var studyModeButtons: some View {
        Button("All Cards (\(deck.cards.count))") {
            studyCards = nil
            showingStudySession = true
        }
        let weakCards = Array(deck.strugglingCards)
        if !weakCards.isEmpty {
            Button("Weak Cards (\(weakCards.count))") {
                studyCards = weakCards
                showingStudySession = true
            }
        }
        let newCards = Array(deck.unseenCards)
        if !newCards.isEmpty {
            Button("New Cards (\(newCards.count))") {
                studyCards = newCards
                showingStudySession = true
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    // MARK: Progress Section

    private var progressSection: some View {
        Section {
            ProgressDashboard(deck: deck)
        }
    }

    // MARK: Filter + Cards Section

    private var filterSection: some View {
        Section {
            Picker("Filter", selection: $selectedFilter) {
                ForEach(CardFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private var cardsSection: some View {
        Section("\(selectedFilter.rawValue) (\(filteredCards.count))") {
            if filteredCards.isEmpty {
                emptyFilterView
            } else {
                ForEach(filteredCards) { (card: Flashcard) in
                    CardRowView(card: card, languageCode: deck.languageCode)
                }
            }
        }
    }

    private var filteredCards: [Flashcard] {
        let sorted = Array(deck.cards).sorted { $0.rank < $1.rank }
        switch selectedFilter {
        case .all: return sorted
        case .mastered: return sorted.filter { $0.masteryStatus == .mastered }
        case .struggling: return sorted.filter { $0.masteryStatus == .struggling }
        case .unseen: return sorted.filter { $0.masteryStatus == .unseen }
        }
    }

    private var emptyFilterView: some View {
        VStack(spacing: 8) {
            let icon = selectedFilter == .mastered ? "star.circle" :
                       selectedFilter == .struggling ? "exclamationmark.triangle" : "sparkles"
            let msg = selectedFilter == .mastered ? "No mastered cards yet" :
                      selectedFilter == .struggling ? "No struggling cards" : "All cards have been studied"
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(.secondary)
            Text(msg)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Progress Dashboard

struct ProgressDashboard: View {
    let deck: Deck

    var body: some View {
        VStack(spacing: 12) {
            progressBar
            progressLabels
        }
        .padding(.vertical, 4)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            let total = max(deck.cards.count, 1)
            let mW = CGFloat(deck.masteredCards.count) / CGFloat(total) * geo.size.width
            let sW = CGFloat(deck.strugglingCards.count) / CGFloat(total) * geo.size.width

            HStack(spacing: 2) {
                if deck.masteredCards.count > 0 {
                    RoundedRectangle(cornerRadius: 4).fill(.green).frame(width: max(mW, 2))
                }
                if deck.strugglingCards.count > 0 {
                    RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: max(sW, 2))
                }
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray4))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var progressLabels: some View {
        HStack(spacing: 16) {
            progressLabel(count: deck.masteredCards.count, label: "Mastered", color: .green)
            progressLabel(count: deck.strugglingCards.count, label: "Weak", color: .red)
            progressLabel(count: deck.unseenCards.count, label: "New", color: .secondary)
        }
    }

    private func progressLabel(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Card Row

struct CardRowView: View {
    let card: Flashcard
    let languageCode: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: card.masteryStatus.icon)
                .font(.caption)
                .foregroundStyle(card.masteryStatus.color)
                .frame(width: 18)

            if card.rank > 0 {
                Text("#\(card.rank)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(card.front)
                    .font(.body.bold())
                Text(card.back)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if card.totalReviews > 0 {
                Text("\(Int(card.accuracy * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(card.masteryStatus.color)
                    .frame(width: 36, alignment: .trailing)
            }

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

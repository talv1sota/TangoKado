import SwiftUI
import SwiftData

// MARK: - Home Screen

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @State private var showingAddLanguage = false

    var body: some View {
        NavigationStack {
            Group {
                if decks.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(decks) { deck in
                            NavigationLink(value: deck) {
                                DeckRow(deck: deck)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation {
                                        modelContext.delete(deck)
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("TangoKado")
            .navigationDestination(for: Deck.self) { deck in
                DeckDetailView(deck: deck)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    streakBadge
                }
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

    private var streakBadge: some View {
        let streak = UserDefaults.standard.integer(forKey: "currentStreak")
        return HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .foregroundStyle(streak > 0 ? .orange : .secondary)
            Text("\(streak)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(streak > 0 ? .primary : .secondary)
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

}

// MARK: - Deck Row (Home Screen)

struct DeckRow: View {
    let deck: Deck

    var body: some View {
        HStack(spacing: 14) {
            Text(LanguageRegistry.language(for: deck.languageCode)?.flag ?? "")
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.name)
                    .font(.headline)
                HStack(spacing: 10) {
                    Label("\(deck.cards.count)", systemImage: "rectangle.stack.fill")
                    if deck.masteredCards.count > 0 {
                        Label("\(deck.masteredCards.count)", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if deck.strugglingCards.count > 0 {
                        Label("\(deck.strugglingCards.count)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var deck: Deck
    @State private var showingAddCard = false
    @State private var showingStudySession = false
    @State private var showingStudyPicker = false
    @State private var launchStudyOnDismiss = false
    @State private var showingResetConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var selectedFilter: CardFilter = .all
    @State private var studyCards: [Flashcard]? = nil
    @State private var reverseMode = false
    @State private var searchText = ""

    var body: some View {
        List {
            if !deck.cards.isEmpty {
                studySection
                progressSection
                filterSection
            }
            cardsSection
        }
        .searchable(text: $searchText, prompt: "Search words")
        .navigationTitle(deck.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button { showingAddCard = true } label: {
                        Label("Add Card", systemImage: "plus")
                    }
                    Button(role: .destructive) { showingResetConfirm = true } label: {
                        Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Remove Language", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Reset all progress for \(deck.name)?", isPresented: $showingResetConfirm, titleVisibility: .visible) {
            Button("Reset Progress", role: .destructive) {
                resetProgress()
            }
        } message: {
            Text("This will clear all correct/incorrect counts and mastery status. The word list stays the same.")
        }
        .confirmationDialog("Remove \(deck.name)?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Remove Language", role: .destructive) {
                modelContext.delete(deck)
                dismiss()
            }
        } message: {
            Text("This will delete all cards and progress for \(deck.name).")
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardView(deck: deck)
        }
        .sheet(isPresented: $showingStudyPicker, onDismiss: {
            if launchStudyOnDismiss {
                launchStudyOnDismiss = false
                showingStudySession = true
            }
        }) {
            StudyModePicker(deck: deck) { cards, reverse in
                studyCards = cards
                reverseMode = reverse
                launchStudyOnDismiss = true
                showingStudyPicker = false
            }
            .presentationDetents([.height(280)])
        }
        .fullScreenCover(isPresented: $showingStudySession) {
            StudySessionView(deck: deck, specificCards: studyCards, reverseMode: reverseMode)
        }
    }

    // MARK: Study Section

    private var studySection: some View {
        Section {
            Button { showingStudyPicker = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start Studying")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(deck.cards.count) total · \(deck.strugglingCards.count) weak · \(deck.unseenCards.count) new")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
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

    @State private var isCardsExpanded = false

    private var cardsSection: some View {
        Section {
            DisclosureGroup(
                "\(selectedFilter.rawValue) (\(filteredCards.count))",
                isExpanded: $isCardsExpanded
            ) {
                if filteredCards.isEmpty {
                    emptyFilterView
                } else {
                    ForEach(filteredCards) { (card: Flashcard) in
                        CardRowView(card: card, languageCode: deck.languageCode)
                    }
                }
            }
        }
    }

    private func resetProgress() {
        for card in deck.cards {
            card.correctCount = 0
            card.incorrectCount = 0
            card.lastReviewedAt = nil
        }
    }

    private var filteredCards: [Flashcard] {
        var cards = Array(deck.cards).sorted { $0.rank < $1.rank }
        switch selectedFilter {
        case .all: break
        case .mastered: cards = cards.filter { $0.masteryStatus == .mastered }
        case .struggling: cards = cards.filter { $0.masteryStatus == .struggling }
        case .unseen: cards = cards.filter { $0.masteryStatus == .unseen }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            cards = cards.filter { $0.front.lowercased().contains(query) || $0.back.lowercased().contains(query) }
        }
        return cards
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

// MARK: - Study Mode Picker

struct StudyModePicker: View {
    let deck: Deck
    let onSelect: ([Flashcard]?, Bool) -> Void
    @State private var sessionLimit: Int = 0
    @State private var reverseMode = false

    var body: some View {
        NavigationStack {
            List {
                Section("Cards") {
                    studyRow(icon: "play.fill", title: "All Cards", count: deck.cards.count, color: .indigo) {
                        onSelect(limitCards(nil), reverseMode)
                    }
                    let weak = Array(deck.strugglingCards)
                    if !weak.isEmpty {
                        studyRow(icon: "exclamationmark.triangle.fill", title: "Weak Cards", count: weak.count, color: .red) {
                            onSelect(limitCards(weak), reverseMode)
                        }
                    }
                    let mastered = Array(deck.masteredCards)
                    if !mastered.isEmpty {
                        studyRow(icon: "checkmark.circle.fill", title: "Known Cards", count: mastered.count, color: .green) {
                            onSelect(limitCards(mastered), reverseMode)
                        }
                    }
                    let new = Array(deck.unseenCards)
                    if !new.isEmpty {
                        studyRow(icon: "sparkles", title: "New Cards", count: new.count, color: .orange) {
                            onSelect(limitCards(new), reverseMode)
                        }
                    }
                }

                Section("Options") {
                    Picker("Cards per session", selection: $sessionLimit) {
                        Text("All").tag(0)
                        Text("10").tag(10)
                        Text("25").tag(25)
                        Text("50").tag(50)
                    }
                    .pickerStyle(.segmented)

                    Toggle("Reverse Mode (English → Word)", isOn: $reverseMode)
                        .font(.subheadline)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Study Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func limitCards(_ cards: [Flashcard]?) -> [Flashcard]? {
        guard sessionLimit > 0 else { return cards }
        if let cards = cards {
            return Array(cards.prefix(sessionLimit))
        }
        return Array(Array(deck.cards).prefix(sessionLimit))
    }

    private func studyRow(icon: String, title: String, count: Int, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 24)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 2)
        }
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

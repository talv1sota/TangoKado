import SwiftUI
import SwiftData

// MARK: - Home Screen

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @AppStorage("appColorScheme") private var appColorScheme = 0
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
                            .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("TangoKado")
            .navigationBarTitleDisplayMode(decks.isEmpty ? .inline : .large)
            .navigationDestination(for: Deck.self) { deck in
                DeckDetailView(deck: deck)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    streakBadge
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    appearanceButton
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

    private var appearanceButton: some View {
        Button {
            appColorScheme = appColorScheme == 2 ? 1 : 2
        } label: {
            Image(systemName: appColorScheme == 2 ? "moon.fill" : "sun.max.fill")
                .font(.body)
        }
    }

    private var emptyStateView: some View {
        GeometryReader { geo in
            VStack(spacing: 16) {
                Image(systemName: "character.book.closed.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.indigo.opacity(0.5))
                Text("Start Learning")
                    .font(.title2.bold())
                Text("Add a language to begin studying")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button {
                    showingAddLanguage = true
                } label: {
                    Text("Add Language")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.indigo)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .offset(y: -40)
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
                    Label("\(deck.cards.count) words", systemImage: "rectangle.stack.fill")
                    if deck.masteredCards.count > 0 {
                        Label("\(deck.masteredCards.count) known", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
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

struct StudyConfig: Identifiable {
    let id = UUID()
    let cards: [Flashcard]?
    let reverseMode: Bool
    let typingMode: Bool
}

enum CardFilter: String, CaseIterable {
    case all = "All"
    case mastered = "Correct"
    case struggling = "Incorrect"
    case unseen = "Skipped"
}

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var deck: Deck
    @State private var showingAddCard = false
    @State private var showingStudyPicker = false
    @State private var pendingStudyConfig: StudyConfig? = nil
    @State private var activeStudyConfig: StudyConfig? = nil
    @State private var showingResetConfirm = false
    @State private var showingDeleteConfirm = false
    @State private var selectedFilter: CardFilter = .all
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
        .alert("Reset Progress", isPresented: $showingResetConfirm) {
            Button("Reset", role: .destructive) { resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clear all correct/incorrect counts for \(deck.name)?")
        }
        .alert("Remove Language", isPresented: $showingDeleteConfirm) {
            Button("Remove", role: .destructive) {
                modelContext.delete(deck)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete all cards and progress for \(deck.name)?")
        }
        .sheet(isPresented: $showingAddCard) {
            AddCardView(deck: deck)
        }
        .sheet(isPresented: $showingStudyPicker, onDismiss: {
            if let config = pendingStudyConfig {
                pendingStudyConfig = nil
                activeStudyConfig = config
            }
        }) {
            StudyModePicker(deck: deck) { cards, reverse, typing in
                pendingStudyConfig = StudyConfig(cards: cards, reverseMode: reverse, typingMode: typing)
                showingStudyPicker = false
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $activeStudyConfig) { config in
            StudySessionView(deck: deck, specificCards: config.cards, reverseMode: config.reverseMode, typingMode: config.typingMode)
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
                        Text("\(deck.cards.count) total · \(deck.masteredCards.count) correct · \(deck.strugglingCards.count) incorrect")
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
            .buttonStyle(.plain)
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
                    RoundedRectangle(cornerRadius: 4).fill(.orange).frame(width: max(sW, 2))
                }
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray4))
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private var progressLabels: some View {
        HStack(spacing: 16) {
            progressLabel(count: deck.masteredCards.count, label: "Correct", color: .green)
            progressLabel(count: deck.strugglingCards.count, label: "Incorrect", color: .orange)
            progressLabel(count: deck.unseenCards.count, label: "Skipped", color: .secondary)
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
    let onSelect: ([Flashcard]?, Bool, Bool) -> Void
    @State private var wordRangeValue: Double = 0
    @State private var sessionLimitValue: Double = 0
    @State private var reverseMode = false
    @State private var typingMode = false

    private var maxCards: Int { deck.cards.count }

    private var wordRange: Int {
        let v = Int(wordRangeValue)
        return v == 0 ? maxCards : v
    }

    private var sessionLimit: Int {
        Int(sessionLimitValue)
    }

    private var rangedCards: [Flashcard] {
        return Array(deck.cards).filter { $0.rank <= wordRange }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 4) {
                        HStack {
                            Text("Word Range")
                                .font(.subheadline)
                            Spacer()
                            Text(Int(wordRangeValue) == 0 ? "All \(maxCards)" : "Top \(Int(wordRangeValue))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.indigo)
                        }
                        Slider(value: $wordRangeValue, in: 0...Double(maxCards), step: 5)
                            .tint(.indigo)
                    }
                }

                Section("Options") {
                    Toggle("Reverse (English → Word)", isOn: $reverseMode)
                        .font(.subheadline)
                    Toggle("Type Answer", isOn: $typingMode)
                        .font(.subheadline)
                }

                Section {
                    startButton(title: "All Cards", count: rangedCards.count) {
                        onSelect(applyLimit(rangedCards), reverseMode, typingMode)
                    }
                    let weak = rangedCards.filter { $0.masteryStatus == .struggling }
                    if !weak.isEmpty {
                        startButton(title: "Incorrect Cards", count: weak.count) {
                            onSelect(applyLimit(weak), reverseMode, typingMode)
                        }
                    }
                    let mastered = rangedCards.filter { $0.masteryStatus == .mastered }
                    if !mastered.isEmpty {
                        startButton(title: "Correct Cards", count: mastered.count) {
                            onSelect(applyLimit(mastered), reverseMode, typingMode)
                        }
                    }
                    let unseen = rangedCards.filter { $0.masteryStatus == .unseen }
                    if !unseen.isEmpty {
                        startButton(title: "Skipped Cards", count: unseen.count) {
                            onSelect(applyLimit(unseen), reverseMode, typingMode)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Study Mode")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func applyLimit(_ cards: [Flashcard]) -> [Flashcard]? {
        guard sessionLimit > 0 else { return cards }
        return Array(cards.prefix(sessionLimit))
    }

    private func startButton(title: String, count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.indigo, in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Row

struct CardRowView: View {
    let card: Flashcard
    let languageCode: String

    var body: some View {
        HStack(spacing: 8) {
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

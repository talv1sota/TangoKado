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
            .navigationBarTitleDisplayMode(.large)
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
                Text("\(deck.cards.count) words")
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
    let shuffleMode: Bool
}

enum CardFilter: String, CaseIterable {
    case all = "All"
    case mastered = "Know"
    case struggling = "Don't Know"
    case unseen = "New"
}

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("studyReverse") private var reverseMode = false
    @AppStorage("studyShuffle") private var shuffleMode = true
    @AppStorage("studyWordRange") private var wordRangeStored: Int = 0
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
                flashcardProgressSection
                typingProgressSection
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
                    Divider()
                    Button(role: .destructive) { resetFlashcardProgress() } label: {
                        Label("Reset Flashcards", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }
                    Button(role: .destructive) { resetTypingProgress() } label: {
                        Label("Reset Typing", systemImage: "keyboard")
                    }
                    Button(role: .destructive) { showingResetConfirm = true } label: {
                        Label("Reset All Progress", systemImage: "arrow.counterclockwise")
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Label("Remove Language", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Reset All Progress", isPresented: $showingResetConfirm) {
            Button("Reset All", role: .destructive) { resetAllProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clear all flashcard and typing progress for \(deck.name)?")
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
        .sheet(isPresented: $showingStudyPicker) {
            StudyModePicker(deck: deck) { _, _, _, _ in
                // Settings saved via @AppStorage automatically
                showingStudyPicker = false
            }
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(item: $activeStudyConfig) { config in
            StudySessionView(deck: deck, specificCards: config.cards, reverseMode: config.reverseMode, typingMode: config.typingMode, shuffleMode: config.shuffleMode)
        }
    }

    // MARK: Study Section

    private var studyCards: [Flashcard]? {
        guard wordRangeStored > 0, wordRangeStored < deck.cards.count else { return nil }
        return Array(deck.cards).filter { $0.rank <= wordRangeStored }
    }

    private var savedFlashcardIndex: Int? {
        StudySession.savedIndex(for: deck.name, typingMode: false)
    }

    private var savedTypingIndex: Int? {
        StudySession.savedIndex(for: deck.name, typingMode: true)
    }

    private var studySection: some View {
        Section {
            // Flashcards
            Button {
                activeStudyConfig = StudyConfig(cards: studyCards, reverseMode: reverseMode, typingMode: false, shuffleMode: shuffleMode)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(savedFlashcardIndex != nil ? "Continue Flashcards" : "Flashcards")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let idx = savedFlashcardIndex {
                            Text("Card \(idx + 1) of \(deck.cards.count)")
                                .font(.caption)
                                .foregroundStyle(.indigo)
                        } else {
                            Text("Tap to flip · swipe to skip")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if savedFlashcardIndex != nil {
                    Button {
                        StudySession.clearSavedSession(for: deck.name, typingMode: false)
                    } label: {
                        Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            // Type Answer
            Button {
                activeStudyConfig = StudyConfig(cards: studyCards, reverseMode: reverseMode, typingMode: true, shuffleMode: shuffleMode)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "keyboard.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(savedTypingIndex != nil ? "Continue Typing" : "Type Answer")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if let idx = savedTypingIndex {
                            Text("Card \(idx + 1) of \(deck.cards.count)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Text("Type the translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "play.fill")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .contextMenu {
                if savedTypingIndex != nil {
                    Button {
                        StudySession.clearSavedSession(for: deck.name, typingMode: true)
                    } label: {
                        Label("Reset Progress", systemImage: "arrow.counterclockwise")
                    }
                }
            }

            // Study Options
            Button { showingStudyPicker = true } label: {
                HStack(spacing: 14) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Study Options")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("Word range · reverse · shuffle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
        } header: {
            Text("\(deck.cards.count) words · \(deck.masteredCards.count) correct · \(deck.strugglingCards.count) incorrect")
                .font(.caption)
        }
    }

    // MARK: Progress Section

    @State private var showResetFlashcardConfirm = false
    @State private var showResetTypingConfirm = false

    private var flashcardProgressSection: some View {
        Section {
            HStack {
                Text("Flashcards")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if deck.flashcardStudied > 0 {
                    Button { showResetFlashcardConfirm = true } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                progressStat(count: deck.flashcardCorrect, label: "Know", color: .green)
                progressStat(count: deck.flashcardIncorrect, label: "Don't Know", color: .red)
                progressStat(count: deck.cards.count - deck.flashcardStudied, label: "New", color: .secondary)
            }
        }
        .alert("Reset Flashcard Progress?", isPresented: $showResetFlashcardConfirm) {
            Button("Reset", role: .destructive) { resetFlashcardProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all flashcard counters and progress.")
        }
    }

    private var typingProgressSection: some View {
        Section {
            HStack {
                Text("Typing")
                    .font(.subheadline.weight(.medium))
                Spacer()
                if deck.typingStudied > 0 {
                    Button { showResetTypingConfirm = true } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                progressStat(count: deck.typingCorrect, label: "Correct", color: .green)
                progressStat(count: deck.typingIncorrect, label: "Incorrect", color: .red)
                progressStat(count: deck.cards.count - deck.typingStudied, label: "New", color: .secondary)
            }
        }
        .alert("Reset Typing Progress?", isPresented: $showResetTypingConfirm) {
            Button("Reset", role: .destructive) { resetTypingProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all typing counters and progress.")
        }
    }

    private func progressStat(count: Int, label: String, color: Color) -> some View {
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

    private func resetFlashcardProgress() {
        for card in deck.cards {
            card.correctCount = 0
            card.incorrectCount = 0
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: false)
    }

    private func resetTypingProgress() {
        for card in deck.cards {
            card.typingCorrectCount = 0
            card.typingIncorrectCount = 0
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: true)
    }

    private func resetAllProgress() {
        for card in deck.cards {
            card.correctCount = 0
            card.incorrectCount = 0
            card.typingCorrectCount = 0
            card.typingIncorrectCount = 0
            card.lastReviewedAt = nil
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: false)
        StudySession.clearSavedSession(for: deck.name, typingMode: true)
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

// ProgressDashboard removed — stats are now inline in separate sections

// MARK: - Study Mode Picker

enum CardSet: String, CaseIterable {
    case all = "All"
    case incorrect = "Don't Know"
    case correct = "Know"
    case skipped = "New"
}

struct StudyModePicker: View {
    let deck: Deck
    let onSelect: ([Flashcard]?, Bool, Bool, Bool) -> Void
    @AppStorage("studyWordRange") private var wordRangeStored: Int = 0
    @AppStorage("studyReverse") private var reverseMode = false
    @AppStorage("studyTyping") private var typingMode = false
    @AppStorage("studyShuffle") private var shuffleMode = true
    @State private var wordRangeValue: Double = 0
    @State private var selectedSet: CardSet = .all
    @State private var showingNextSessionAlert = false

    private var maxCards: Int { deck.cards.count }

    private var wordRange: Int {
        let v = Int(wordRangeValue)
        return v == 0 ? maxCards : v
    }

    private var hasActiveSession: Bool {
        StudySession.savedIndex(for: deck.name, typingMode: false) != nil ||
        StudySession.savedIndex(for: deck.name, typingMode: true) != nil
    }

    private var rangedCards: [Flashcard] {
        Array(deck.cards).filter { $0.rank <= wordRange }
    }

    private var selectedCards: [Flashcard] {
        switch selectedSet {
        case .all: return rangedCards
        case .incorrect: return rangedCards.filter { $0.masteryStatus == .struggling }
        case .correct: return rangedCards.filter { $0.masteryStatus == .mastered }
        case .skipped: return rangedCards.filter { $0.masteryStatus == .unseen }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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

                    Section("Cards") {
                        Picker("Study", selection: $selectedSet) {
                            ForEach(CardSet.allCases, id: \.self) { set in
                                Text(set.rawValue).tag(set)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Options") {
                        Toggle("Learn in Order (#1 first)", isOn: Binding(
                            get: { !shuffleMode },
                            set: { shuffleMode = !$0 }
                        ))
                            .font(.subheadline)
                        Toggle("Reverse (English → Word)", isOn: $reverseMode)
                            .font(.subheadline)
                    }
                }
                .listStyle(.insetGrouped)

                // Save button pinned at bottom
                Button {
                    if hasActiveSession {
                        showingNextSessionAlert = true
                    } else {
                        onSelect(selectedCards.isEmpty ? nil : selectedCards, reverseMode, typingMode, shuffleMode)
                    }
                } label: {
                    Text("Save & Apply")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.indigo)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Study Mode")
            .onAppear { wordRangeValue = Double(wordRangeStored) }
            .onChange(of: wordRangeValue) { wordRangeStored = Int(wordRangeValue) }
            .alert("Changes will apply to your next session", isPresented: $showingNextSessionAlert) {
                Button("Save Anyway") {
                    onSelect(selectedCards.isEmpty ? nil : selectedCards, reverseMode, typingMode, shuffleMode)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You have an active study session. These settings won't affect your current session.")
            }
            .navigationBarTitleDisplayMode(.inline)
        }
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

            VStack(alignment: .trailing, spacing: 1) {
                if card.totalReviews > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait")
                            .font(.system(size: 8))
                        Text("\(Int(card.accuracy * 100))%")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(card.accuracy >= 0.8 ? .green : .red)
                }
                if card.typingTotalReviews > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 8))
                        Text("\(Int(card.typingAccuracy * 100))%")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(card.typingAccuracy >= 0.8 ? .green : .red)
                }
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

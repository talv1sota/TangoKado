import SwiftUI
import SwiftData

// MARK: - Home Screen

struct DeckListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deck.createdAt, order: .reverse) private var decks: [Deck]
    @AppStorage("appColorScheme") private var appColorScheme = 0
    @State private var showingAddLanguage = false
    @State private var deckToDelete: Deck?

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    deckToDelete = deck
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .tint(.red)
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
            .alert("Remove Language", isPresented: Binding(
                get: { deckToDelete != nil },
                set: { if !$0 { deckToDelete = nil } }
            )) {
                Button("Remove", role: .destructive) {
                    if let deck = deckToDelete {
                        SessionHistory.clear(for: deck.name)
                        StudySession.clearSavedSession(for: deck.name, typingMode: false)
                        StudySession.clearSavedSession(for: deck.name, typingMode: true)
                        UserDefaults.standard.removeObject(forKey: "lastSession_\(deck.name)_flash")
                        UserDefaults.standard.removeObject(forKey: "lastSession_\(deck.name)_type")
                        withAnimation { modelContext.delete(deck) }
                    }
                    deckToDelete = nil
                }
                Button("Cancel", role: .cancel) { deckToDelete = nil }
            } message: {
                Text("Delete all cards and progress for \(deckToDelete?.name ?? "")?")
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
    case mastered = "Mastered"
    case struggling = "Weak"
    case unseen = "New"
}

struct DeckDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("studyReverse") private var reverseMode = false
    @AppStorage("studyShuffle") private var shuffleMode = true
    var deck: Deck
    @State private var showingAddCard = false
    @State private var showingStudyPicker = false
    @State private var pendingStudyConfig: StudyConfig? = nil
    @State private var activeStudyConfig: StudyConfig? = nil
    @State private var showingResetConfirm = false
    @State private var showingWordCountPicker = false
    @State private var pendingTypingMode = false
    @State private var customWordCount = ""
    @State private var showingDeleteConfirm = false
    @State private var selectedFilter: CardFilter = .all
    @State private var searchText = ""
    @State private var refreshID = UUID()
    @State private var sessionRecords: [SessionRecord] = []
    @State private var isSessionActive = false
    var body: some View {
        List {
            if !deck.cards.isEmpty {
                studySection
                flashcardProgressSection
                typingProgressSection
                filterSection
            }
            cardsSection
            lastSessionSection
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
                    Button(role: .destructive) { showResetFlashcardConfirm = true } label: {
                        Label("Reset Flashcards", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }
                    Button(role: .destructive) { showResetTypingConfirm = true } label: {
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
            .presentationDetents([.large])
        }
        .onAppear {
            reloadSavedIndices()
            sessionRecords = SessionHistory.records(for: deck.name)
        }
        .onChange(of: isSessionActive) { old, new in
            if old && !new {
                reloadSavedIndices()
                sessionRecords = SessionHistory.records(for: deck.name)
            }
        }
        .fullScreenCover(isPresented: $isSessionActive) {
            if let config = activeStudyConfig {
                StudySessionView(deck: deck, specificCards: config.cards, reverseMode: config.reverseMode, typingMode: config.typingMode, shuffleMode: config.shuffleMode, isPresented: $isSessionActive)
            }
        }
        .sheet(isPresented: $showingWordCountPicker) {
            wordCountPickerSheet
                .presentationDetents([.medium])
        }
    }

    private var wordCountPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach([100, 250, 500, 1000], id: \.self) { count in
                        if count <= deck.cards.count {
                            Button {
                                launchSessionWithCount(count)
                            } label: {
                                HStack {
                                    Text("\(count) words")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }
                    if deck.cards.count > 1000 {
                        Button {
                            launchSessionWithCount(deck.cards.count)
                        } label: {
                            HStack {
                                Text("All \(deck.cards.count) words")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                    }
                } header: {
                    Text("How many words?")
                }
                Section {
                    HStack {
                        TextField("Enter a number", text: $customWordCount)
                            .keyboardType(.numberPad)
                        Button("Go") {
                            if let count = Int(customWordCount), count > 0 {
                                launchSessionWithCount(min(count, deck.cards.count))
                            }
                        }
                        .foregroundStyle(.indigo)
                        .disabled(Int(customWordCount) == nil || Int(customWordCount)! < 1)
                    }
                } header: {
                    Text("Custom")
                }
            }
            .navigationTitle("Session Size")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.indigo)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingWordCountPicker = false }
                }
            }
        }
    }

    private func launchSessionWithCount(_ count: Int) {
        showingWordCountPicker = false
        let cards: [Flashcard]?
        if count >= deck.cards.count {
            cards = nil
        } else {
            let sorted = Array(deck.cards).sorted { $0.rank < $1.rank }
            cards = Array(sorted.prefix(count))
        }
        activeStudyConfig = StudyConfig(cards: cards, reverseMode: reverseMode, typingMode: pendingTypingMode, shuffleMode: shuffleMode)
        isSessionActive = true
    }

    // MARK: Study Section

    private var studyCards: [Flashcard]? {
        nil
    }

    private var savedFlashcardIndex: Int? {
        let _ = refreshID
        return StudySession.savedIndex(for: deck.name, typingMode: false)
    }
    private var savedTypingIndex: Int? {
        let _ = refreshID
        return StudySession.savedIndex(for: deck.name, typingMode: true)
    }

    private func reloadSavedIndices() {
        refreshID = UUID()
    }

    private var studySection: some View {
        Section {
            // Flashcards
            Button {
                if savedFlashcardIndex != nil {
                    let savedCount = StudySession.savedCardCount(for: deck.name, typingMode: false)
                    let cards: [Flashcard]? = savedCount.map { Array(deck.cards.prefix($0)) }
                    activeStudyConfig = StudyConfig(cards: cards, reverseMode: reverseMode, typingMode: false, shuffleMode: shuffleMode)
                    isSessionActive = true
                } else {
                    pendingTypingMode = false
                    customWordCount = ""
                    showingWordCountPicker = true
                }
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
                            let total = StudySession.savedCardCount(for: deck.name, typingMode: false) ?? deck.cards.count
                            Text("Card \(idx + 1) of \(total)")
                                .font(.caption)
                                .foregroundStyle(.indigo)
                        } else {
                            Text("Tap to flip · Swipe to skip")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if deck.flashcardStudied > 0 || savedFlashcardIndex != nil {
                        Button { showResetFlashcardConfirm = true } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    Image(systemName: savedFlashcardIndex != nil ? "arrow.uturn.right" : "play.fill")
                        .foregroundStyle(.indigo)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Type Answer
            Button {
                if savedTypingIndex != nil {
                    let savedCount = StudySession.savedCardCount(for: deck.name, typingMode: true)
                    let cards: [Flashcard]? = savedCount.map { Array(deck.cards.prefix($0)) }
                    activeStudyConfig = StudyConfig(cards: cards, reverseMode: reverseMode, typingMode: true, shuffleMode: shuffleMode)
                    isSessionActive = true
                } else {
                    pendingTypingMode = true
                    customWordCount = ""
                    showingWordCountPicker = true
                }
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
                            let total = StudySession.savedCardCount(for: deck.name, typingMode: true) ?? deck.cards.count
                            Text("Card \(idx + 1) of \(total)")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        } else {
                            Text("Type the translation")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if deck.typingStudied > 0 || savedTypingIndex != nil {
                        Button { showResetTypingConfirm = true } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    Image(systemName: savedTypingIndex != nil ? "arrow.uturn.right" : "play.fill")
                        .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
                        Text("Reverse · Shuffle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Progress Section

    @State private var showResetFlashcardConfirm = false
    @State private var showResetTypingConfirm = false
    @State private var flashcardProgressExpanded = true
    @State private var typingProgressExpanded = true

    private var flashcardProgressSection: some View {
        Section {
            Button {
                withAnimation { flashcardProgressExpanded.toggle() }
            } label: {
                HStack {
                    Text("Flashcards")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(flashcardProgressExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            if flashcardProgressExpanded {
                HStack(spacing: 16) {
                    progressStat(count: deck.flashcardCorrect, label: "Mastered", color: .green)
                    progressStat(count: deck.flashcardIncorrect, label: "Weak", color: .red)
                    progressStat(count: deck.cards.count - deck.flashcardStudied, label: "New", color: .secondary)
                }
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
            Button {
                withAnimation { typingProgressExpanded.toggle() }
            } label: {
                HStack {
                    Text("Typing")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(typingProgressExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)
            if typingProgressExpanded {
                HStack(spacing: 16) {
                    progressStat(count: deck.typingCorrect, label: "Correct", color: .green)
                    progressStat(count: deck.typingIncorrect, label: "Incorrect", color: .red)
                    progressStat(count: deck.cards.count - deck.typingStudied, label: "New", color: .secondary)
                }
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

    // MARK: Session History

    @State private var showAllHistory = false
    @State private var showClearHistoryConfirm = false
    @State private var recordToDelete: SessionRecord?

    private var lastSessionSection: some View {
        let visibleRecords = showAllHistory ? sessionRecords : Array(sessionRecords.prefix(3))

        return Section {
            if sessionRecords.isEmpty {
                Text("Complete a session to see results here")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(visibleRecords) { record in
                    NavigationLink {
                        SessionDetailView(record: record, languageCode: deck.languageCode)
                    } label: {
                        sessionHistoryRow(record: record)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                recordToDelete = record
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                }
                if sessionRecords.count > 3 {
                    Button {
                        withAnimation { showAllHistory.toggle() }
                    } label: {
                        Text(showAllHistory ? "Show Less" : "Show All (\(sessionRecords.count))")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Text("Clear All History")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Session History")
        }
        .alert("Delete Session?", isPresented: Binding(
            get: { recordToDelete != nil },
            set: { if !$0 { recordToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let record = recordToDelete {
                    deleteSessionRecord(record)
                }
                recordToDelete = nil
            }
            Button("Cancel", role: .cancel) { recordToDelete = nil }
        } message: {
            Text("Remove this session record?")
        }
        .alert("Clear Session History?", isPresented: $showClearHistoryConfirm) {
            Button("Clear All", role: .destructive) {
                SessionHistory.clear(for: deck.name)
                sessionRecords = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Delete all session history for \(deck.name)?")
        }
    }

    private func deleteSessionRecord(_ record: SessionRecord) {
        SessionHistory.delete(id: record.id)
        withAnimation {
            sessionRecords.removeAll { $0.id == record.id }
        }
    }

    private func sessionHistoryRow(record: SessionRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: record.typingMode ? "keyboard" : "rectangle.portrait.on.rectangle.portrait")
                .font(.caption)
                .foregroundStyle(record.typingMode ? .blue : .indigo)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text("\(record.correct)/\(record.total)")
                        .font(.subheadline.bold().monospacedDigit())
                    Text("\(record.percentage)%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(record.percentage >= 80 ? .green : record.percentage >= 50 ? .orange : .red)
                }
                Text(record.date.formatted(.dateTime.month(.abbreviated).day().year().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Text(record.modeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill((record.typingMode ? Color.blue : Color.indigo).opacity(0.1))
                )
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

    private func archiveProgress(typingMode: Bool) {
        let correctCards: [Flashcard]
        let incorrectCards: [Flashcard]
        if typingMode {
            correctCards = deck.cards.filter { $0.typingCorrectCount > 0 }
            incorrectCards = deck.cards.filter { $0.typingIncorrectCount > 0 }
        } else {
            correctCards = deck.cards.filter { $0.correctCount > 0 }
            incorrectCards = deck.cards.filter { $0.incorrectCount > 0 }
        }
        let correct = correctCards.count
        let incorrect = incorrectCards.count
        let total = correct + incorrect
        guard total > 0 else { return }
        SessionHistory.save(
            deckName: deck.name,
            typingMode: typingMode,
            correct: correct,
            incorrect: incorrect,
            total: total,
            correctWords: correctCards.map { WordResult(front: $0.front, back: $0.back) },
            incorrectWords: incorrectCards.map { WordResult(front: $0.front, back: $0.back) }
        )
        sessionRecords = SessionHistory.records(for: deck.name)
    }

    private func resetFlashcardProgress() {
        archiveProgress(typingMode: false)
        for card in deck.cards {
            card.correctCount = 0
            card.incorrectCount = 0
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: false)
        reloadSavedIndices()
    }

    private func resetTypingProgress() {
        archiveProgress(typingMode: true)
        for card in deck.cards {
            card.typingCorrectCount = 0
            card.typingIncorrectCount = 0
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: true)
        reloadSavedIndices()
    }

    private func resetAllProgress() {
        archiveProgress(typingMode: false)
        archiveProgress(typingMode: true)
        for card in deck.cards {
            card.correctCount = 0
            card.incorrectCount = 0
            card.typingCorrectCount = 0
            card.typingIncorrectCount = 0
            card.lastReviewedAt = nil
        }
        StudySession.clearSavedSession(for: deck.name, typingMode: false)
        StudySession.clearSavedSession(for: deck.name, typingMode: true)
        reloadSavedIndices()
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

enum FlashcardCardSet: String, CaseIterable {
    case all = "All"
    case mastered = "Mastered"
    case weak = "Weak"
    case unseen = "New"
}

enum TypingCardSet: String, CaseIterable {
    case all = "All"
    case correct = "Correct"
    case incorrect = "Incorrect"
    case unseen = "New"
}

struct StudyModePicker: View {
    let deck: Deck
    let onSelect: ([Flashcard]?, Bool, Bool, Bool) -> Void
    @AppStorage("studyReverse") private var reverseMode = false
    @AppStorage("studyTyping") private var typingMode = false
    @AppStorage("studyShuffle") private var shuffleMode = true
    @State private var selectedFlashcardSet: FlashcardCardSet = .all
    @State private var selectedTypingSet: TypingCardSet = .all
    @State private var showingNextSessionAlert = false

    private var hasActiveSession: Bool {
        StudySession.savedIndex(for: deck.name, typingMode: false) != nil ||
        StudySession.savedIndex(for: deck.name, typingMode: true) != nil
    }

    private var selectedCards: [Flashcard] {
        var cards = Array(deck.cards)

        switch selectedFlashcardSet {
        case .all: break
        case .mastered: cards = cards.filter { $0.totalReviews > 0 && $0.accuracy >= 0.8 }
        case .weak: cards = cards.filter { $0.totalReviews > 0 && $0.accuracy < 0.8 }
        case .unseen: cards = cards.filter { $0.totalReviews == 0 }
        }

        switch selectedTypingSet {
        case .all: break
        case .correct: cards = cards.filter { $0.typingTotalReviews > 0 && $0.typingAccuracy >= 0.8 }
        case .incorrect: cards = cards.filter { $0.typingTotalReviews > 0 && $0.typingAccuracy < 0.8 }
        case .unseen: cards = cards.filter { $0.typingTotalReviews == 0 }
        }

        return cards
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section("Flashcards") {
                        Picker("Flashcards", selection: $selectedFlashcardSet) {
                            ForEach(FlashcardCardSet.allCases, id: \.self) { set in
                                Text(set.rawValue).tag(set)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Typing") {
                        Picker("Typing", selection: $selectedTypingSet) {
                            ForEach(TypingCardSet.allCases, id: \.self) { set in
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

                    Section {
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
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Study Mode")
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

// MARK: - Session Detail View

struct SessionDetailView: View {
    let record: SessionRecord
    let languageCode: String

    var body: some View {
        List {
            Section {
                ResultRow(label: "Mode", value: record.modeLabel, color: record.typingMode ? .blue : .indigo)
                ResultRow(label: "Total", value: "\(record.total) words", color: .primary)
                ResultRow(label: record.typingMode ? "Correct" : "Mastered", value: "\(record.correct)", color: .green)
                ResultRow(label: record.typingMode ? "Incorrect" : "Weak", value: "\(record.incorrect)", color: .red)
                ResultRow(label: "Accuracy", value: "\(record.percentage)%", color: record.percentage >= 80 ? .green : record.percentage >= 50 ? .orange : .red)
            }

            if let words = record.incorrectWords, !words.isEmpty {
                Section {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.front)
                                    .font(.body.bold())
                                Text(word.back)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                SpeechHelper.shared.speak(word.front, languageCode: languageCode)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label("\(record.typingMode ? "Incorrect" : "Weak") (\(words.count))", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if let words = record.correctWords, !words.isEmpty {
                Section {
                    ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(word.front)
                                    .font(.body.bold())
                                Text(word.back)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                SpeechHelper.shared.speak(word.front, languageCode: languageCode)
                            } label: {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(.tint)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Label("\(record.typingMode ? "Correct" : "Mastered") (\(words.count))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            if record.correctWords == nil && record.incorrectWords == nil {
                Section {
                    Text("Word details not available for this session")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .navigationTitle(record.date.formatted(.dateTime.month(.abbreviated).day().year()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DeckListView()
        .modelContainer(for: [Deck.self, Flashcard.self], inMemory: true)
}

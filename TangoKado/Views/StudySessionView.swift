import SwiftUI
import UIKit

// MARK: - Session State

@Observable
final class StudySession {
    let deck: Deck
    let languageCode: String
    let reverseMode: Bool
    let typingMode: Bool
    var shuffledCards: [Flashcard]
    var currentIndex = 0
    var isFlipped = false
    var cardRotation: Double = 0
    var correctCount = 0
    var incorrectCount = 0
    var showingResults = false
    var correctCards: [Flashcard] = []
    var incorrectCards: [Flashcard] = []
    var typedAnswer = ""
    var answerSubmitted = false
    var answerCorrect = false

    init(deck: Deck, specificCards: [Flashcard]?, reverseMode: Bool = false, typingMode: Bool = false) {
        self.deck = deck
        self.languageCode = deck.languageCode
        self.reverseMode = reverseMode
        self.typingMode = typingMode
        if let specific = specificCards {
            self.shuffledCards = specific.shuffled()
        } else {
            self.shuffledCards = Array(deck.cards).shuffled()
        }
    }

    var currentCard: Flashcard? {
        guard currentIndex >= 0, currentIndex < shuffledCards.count else { return nil }
        return shuffledCards[currentIndex]
    }

    // In reverse mode, front shows English and back shows the foreign word
    var displayFront: String {
        guard let card = currentCard else { return "" }
        return reverseMode ? card.back : card.front
    }

    var displayBack: String {
        guard let card = currentCard else { return "" }
        return reverseMode ? card.front : card.back
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex + 1 < shuffledCards.count }

    func markCorrect() {
        guard let card = currentCard else { return }
        card.correctCount += 1
        card.lastReviewedAt = Date()
        correctCount += 1
        correctCards.append(card)
        haptic(.success)
        advance()
    }

    func markIncorrect() {
        guard let card = currentCard else { return }
        card.incorrectCount += 1
        card.lastReviewedAt = Date()
        incorrectCount += 1
        incorrectCards.append(card)
        haptic(.error)
        advance()
    }

    func advance() {
        if canGoForward {
            currentIndex += 1
            resetCardState()
        } else {
            showingResults = true
        }
    }

    func goForward() {
        guard canGoForward else { return }
        currentIndex += 1
        resetCardState()
    }

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        resetCardState()
    }

    func flipCard() {
        cardRotation += 180
        isFlipped.toggle()
        haptic(.light)
    }

    func submitTypedAnswer() {
        guard !answerSubmitted else { return }
        answerSubmitted = true

        let typed = normalize(typedAnswer)
        guard !typed.isEmpty else {
            answerCorrect = false
            guard let card = currentCard else { return }
            card.incorrectCount += 1
            card.lastReviewedAt = Date()
            incorrectCount += 1
            incorrectCards.append(card)
            haptic(.error)
            return
        }

        let correctRaw = displayBack
        var acceptable: Set<String> = []

        // Split by "/" for alternatives
        let slashParts = correctRaw.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in slashParts {
            addVariants(of: part, to: &acceptable)
        }
        // Full string too
        addVariants(of: correctRaw, to: &acceptable)

        // Check exact match first, then check if typed is contained in any acceptable or vice versa
        answerCorrect = acceptable.contains(typed) || acceptable.contains(where: { typed.contains($0) || $0.contains(typed) })

        guard let card = currentCard else { return }
        if answerCorrect {
            card.correctCount += 1
            card.lastReviewedAt = Date()
            correctCount += 1
            correctCards.append(card)
            haptic(.success)
        } else {
            card.incorrectCount += 1
            card.lastReviewedAt = Date()
            incorrectCount += 1
            incorrectCards.append(card)
            haptic(.error)
        }
    }

    private static let synonyms: [String: [String]] = [
        "yes": ["ok", "okay", "yeah", "yep", "yea", "sure"],
        "no": ["nope", "nah"],
        "hello": ["hi", "hey", "greetings"],
        "goodbye": ["bye", "see you", "farewell"],
        "thank you": ["thanks", "cheers"],
        "please": ["pls"],
        "excuse me": ["sorry", "pardon"],
        "good": ["fine", "well", "great", "nice"],
        "bad": ["poor", "terrible"],
        "big": ["large", "huge"],
        "small": ["little", "tiny"],
        "beautiful": ["pretty", "lovely", "gorgeous"],
        "happy": ["glad", "joyful", "cheerful"],
        "sad": ["unhappy", "upset"],
        "man": ["guy", "male"],
        "woman": ["lady", "female"],
        "child": ["kid"],
        "house": ["home"],
        "car": ["automobile", "vehicle"],
        "food": ["meal"],
        "water": ["h2o"],
        "money": ["cash"],
        "work": ["job"],
        "friend": ["pal", "buddy", "mate"],
        "speak": ["talk"],
        "eat": ["consume"],
        "drink": ["sip"],
        "walk": ["stroll"],
        "run": ["sprint", "jog"],
        "fast": ["quick", "rapid"],
        "slow": ["sluggish"],
        "begin": ["start"],
        "end": ["finish", "stop"],
        "buy": ["purchase"],
        "sell": ["vend"],
        "give": ["offer"],
        "take": ["grab", "get"],
        "look": ["watch", "see"],
        "listen": ["hear"],
        "want": ["desire", "wish"],
        "need": ["require"],
        "like": ["enjoy"],
        "love": ["adore"],
        "hate": ["despise", "detest"],
        "think": ["believe", "consider"],
        "know": ["understand"],
        "learn": ["study"],
        "help": ["assist", "aid"],
        "try": ["attempt"],
        "also": ["too", "as well"],
        "very": ["really", "extremely"],
        "always": ["forever"],
        "never": ["not ever"],
        "maybe": ["perhaps", "possibly"],
        "now": ["currently", "at the moment"],
        "difficult": ["hard", "tough"],
        "easy": ["simple"],
    ]

    private func addVariants(of text: String, to set: inout Set<String>) {
        let n = normalize(text)
        set.insert(n)

        // Strip "to " prefix for verbs
        if n.hasPrefix("to ") {
            set.insert(String(n.dropFirst(3)))
        }
        // Strip "a/an/the " prefix
        if n.hasPrefix("a ") { set.insert(String(n.dropFirst(2))) }
        if n.hasPrefix("an ") { set.insert(String(n.dropFirst(3))) }
        if n.hasPrefix("the ") { set.insert(String(n.dropFirst(4))) }

        // Strip parenthetical like "(informal)", "(m.)", "(wa)"
        let stripped = normalize(text.replacingOccurrences(of: "\\s*\\(.*?\\)", with: "", options: .regularExpression))
        set.insert(stripped)
        if stripped.hasPrefix("to ") { set.insert(String(stripped.dropFirst(3))) }
        if stripped.hasPrefix("a ") { set.insert(String(stripped.dropFirst(2))) }
        if stripped.hasPrefix("an ") { set.insert(String(stripped.dropFirst(3))) }
        if stripped.hasPrefix("the ") { set.insert(String(stripped.dropFirst(4))) }

        // Add synonyms
        for word in set {
            if let syns = Self.synonyms[word] {
                for s in syns { set.insert(s) }
            }
        }
        // Reverse lookup — if a synonym is the correct answer, accept the base word too
        for (base, syns) in Self.synonyms {
            if set.contains(where: { syns.contains($0) }) {
                set.insert(base)
            }
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    func revealAnswer() {
        guard !answerSubmitted else { return }
        answerSubmitted = true
        answerCorrect = false
        guard let card = currentCard else { return }
        card.incorrectCount += 1
        card.lastReviewedAt = Date()
        incorrectCount += 1
        incorrectCards.append(card)
        haptic(.error)
    }

    func typingNextCard() {
        advance()
    }

    private func resetCardState() {
        isFlipped = false
        cardRotation = 0
        typedAnswer = ""
        answerSubmitted = false
        answerCorrect = false
    }

    private func haptic(_ type: HapticType) {
        switch type {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    enum HapticType { case success, error, light }

    var percentage: Int {
        guard !shuffledCards.isEmpty else { return 0 }
        return Int(Double(correctCount) / Double(shuffledCards.count) * 100)
    }
}

// MARK: - Study Session View

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: StudySession
    @State private var showingReStudy = false
    @State private var dragOffset: CGFloat = 0
    @State private var typedText = ""

    init(deck: Deck, specificCards: [Flashcard]? = nil, reverseMode: Bool = false, typingMode: Bool = false) {
        _session = State(initialValue: StudySession(deck: deck, specificCards: specificCards, reverseMode: reverseMode, typingMode: typingMode))
    }

    var body: some View {
        NavigationStack {
            if session.showingResults {
                resultsView
            } else if session.shuffledCards.isEmpty {
                ContentUnavailableView("No Cards", systemImage: "rectangle.slash")
            } else {
                studyView
            }
        }
    }

    // MARK: - Study View

    private var studyView: some View {
        VStack(spacing: 0) {
            studyHeader
                .padding(.bottom, 8)

            if session.typingMode {
                typingArea
                    .frame(maxHeight: .infinity)
            } else {
                cardArea
                    .frame(maxHeight: .infinity)

                Text("Tap to flip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                actionButtons
            }
        }
        .navigationTitle(session.deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Quit") { dismiss() }
            }
        }
    }

    private var studyHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.currentIndex + 1) / \(session.shuffledCards.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(session.correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(session.incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            ProgressView(value: Double(session.currentIndex), total: Double(session.shuffledCards.count))
                .tint(.indigo)
                .padding(.horizontal)
        }
    }

    private var cardArea: some View {
        ZStack {
            cardBack
            cardFront
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(dragOffset / 30))
        .gesture(dragGesture)
    }

    private var cardFront: some View {
        let card = session.currentCard
        let subtitle = session.reverseMode ? "English" : (card?.rank ?? 0 > 0 ? "#\(card?.rank ?? 0)" : "Word")
        return StudyCardFace(
            text: session.displayFront,
            subtitle: subtitle,
            color: session.reverseMode ? .blue : .indigo,
            speakLanguage: session.reverseMode ? "en-US" : session.languageCode
        )
        .rotation3DEffect(.degrees(session.cardRotation), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(session.cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 0 : 1)
    }

    private var cardBack: some View {
        StudyCardFace(
            text: session.displayBack,
            subtitle: session.reverseMode ? "#\(session.currentCard?.rank ?? 0)" : "Answer",
            color: session.reverseMode ? .indigo : .blue,
            speakLanguage: session.reverseMode ? session.languageCode : "en-US"
        )
        .rotation3DEffect(.degrees(session.cardRotation + 180), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(session.cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 1 : 0)
    }

    // MARK: - Typing Mode

    @FocusState private var typingFocused: Bool

    private var typingArea: some View {
        VStack(spacing: 0) {
            // Card prompt
            VStack(spacing: 10) {
                Text(session.reverseMode ? "TRANSLATE TO" : "#\(session.currentCard?.rank ?? 0)")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1)

                Text(session.displayFront)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 20)

                Button {
                    let lang = session.reverseMode ? "en-US" : session.languageCode
                    SpeechHelper.shared.speak(session.displayFront, languageCode: lang)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill((session.reverseMode ? Color.blue : Color.indigo).gradient)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer().frame(height: 20)

            // Answer area
            if session.answerSubmitted {
                typingResultFeedback
            } else {
                typingInputField
            }

            Spacer()

            // Bottom actions
            if !session.answerSubmitted {
                HStack(spacing: 28) {
                    if session.canGoBack {
                        Button {
                            session.goBack()
                            typingFocused = true
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button {
                        session.revealAnswer()
                    } label: {
                        Label("Reveal", systemImage: "eye")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        session.typingNextCard()
                        typedText = ""
                        typingFocused = true
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 20)
            } else {
                Color.clear.frame(height: 48)
            }
        }
        .onAppear { typingFocused = true }
    }

    private var typingInputField: some View {
        VStack(spacing: 14) {
            TextField("Your answer...", text: $typedText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($typingFocused)
                .onSubmit {
                    if !typedText.isEmpty {
                        session.typedAnswer = typedText
                        session.submitTypedAnswer()
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 24)

            Button {
                session.typedAnswer = typedText
                session.submitTypedAnswer()
            } label: {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(typedText.isEmpty ? Color(.systemGray4) : .indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(typedText.isEmpty)
            .padding(.horizontal, 24)
        }
    }

    private var typingResultFeedback: some View {
        VStack(spacing: 16) {
            // Result badge
            VStack(spacing: 8) {
                Image(systemName: session.answerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(session.answerCorrect ? .green : .red)

                if session.answerCorrect {
                    Text("Correct!")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(session.displayBack)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if !session.typedAnswer.isEmpty {
                        Text(session.typedAnswer)
                            .font(.body)
                            .strikethrough()
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    Text(session.displayBack)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(session.answerCorrect ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
            )
            .padding(.horizontal, 24)

            Button {
                session.typingNextCard()
                typedText = ""
                typingFocused = true
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(session.answerCorrect ? .green : .indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width
                if abs(dx) > 10 {
                    dragOffset = dx
                }
            }
            .onEnded { value in
                let dx = value.translation.width

                if abs(dx) <= 10 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        session.flipCard()
                    }
                } else if dx > 80 && session.canGoBack {
                    session.goBack()
                } else if dx < -80 && session.canGoForward {
                    session.goForward()
                }

                withAnimation(.spring()) {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack {
            Button { session.markIncorrect() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                    Text("Don't Know")
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }

            Button { session.markCorrect() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                    Text("Know It")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 16)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                resultsSummaryHeader
                resultsStatsCard

                if !session.incorrectCards.isEmpty {
                    reStudyButton
                }

                if !session.incorrectCards.isEmpty {
                    resultsSection(title: "Incorrect", icon: "xmark.circle.fill", color: .red, cards: session.incorrectCards)
                }

                if !session.correctCards.isEmpty {
                    resultsSection(title: "Correct", icon: "checkmark.circle.fill", color: .green, cards: session.correctCards)
                }

                doneButton
            }
            .padding()
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingReStudy) {
            StudySessionView(deck: session.deck, specificCards: session.incorrectCards, reverseMode: session.reverseMode)
        }
        .onAppear {
            // Record study date for streak
            UserDefaults.standard.set(Date(), forKey: "lastStudyDate")
            updateStreak()
        }
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        let lastDateRaw = UserDefaults.standard.object(forKey: "streakDate") as? Date
        let lastDate = lastDateRaw.map { calendar.startOfDay(for: $0) }

        if let last = lastDate {
            let diff = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            if diff == 0 {
                // Already studied today
            } else if diff == 1 {
                UserDefaults.standard.set(lastStreak + 1, forKey: "currentStreak")
            } else {
                UserDefaults.standard.set(1, forKey: "currentStreak")
            }
        } else {
            UserDefaults.standard.set(1, forKey: "currentStreak")
        }
        UserDefaults.standard.set(today, forKey: "streakDate")
    }

    private var resultsSummaryHeader: some View {
        let p = session.percentage
        let icon = p >= 80 ? "star.fill" : p >= 50 ? "hand.thumbsup.fill" : "arrow.clockwise"
        let iconColor: Color = p >= 80 ? .yellow : p >= 50 ? .blue : .orange
        let message = p >= 80 ? "Great Job!" : p >= 50 ? "Good Effort!" : "Keep Practicing!"

        return VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.title.bold())
            Text(session.deck.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var resultsStatsCard: some View {
        VStack(spacing: 12) {
            ResultRow(label: "Total", value: "\(session.shuffledCards.count) cards", color: .primary)
            ResultRow(label: "Correct", value: "\(session.correctCount)", color: .green)
            ResultRow(label: "Incorrect", value: "\(session.incorrectCount)", color: .red)
            ResultRow(label: "Accuracy", value: "\(session.percentage)%", color: .indigo)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reStudyButton: some View {
        Button { showingReStudy = true } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Re-study \(session.incorrectCards.count) Mistakes")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.red.opacity(0.12))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func resultsSection(title: String, icon: String, color: Color, cards: [Flashcard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title) (\(cards.count))", systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    ResultCardRow(card: card, languageCode: session.languageCode)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct StudyCardFace: View {
    let text: String
    let subtitle: String
    let color: Color
    let speakLanguage: String?

    var body: some View {
        VStack(spacing: 12) {
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1)

            Text(text)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)

            if let lang = speakLanguage {
                Button {
                    SpeechHelper.shared.speak(text, languageCode: lang)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(color.gradient)
                .shadow(color: color.opacity(0.3), radius: 12, y: 6)
        )
        .padding(.horizontal)
    }
}

struct ResultCardRow: View {
    let card: Flashcard
    let languageCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.front)
                    .font(.body.bold())
                Text(card.back)
                    .font(.subheadline)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

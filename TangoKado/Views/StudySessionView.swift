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

    init(deck: Deck, specificCards: [Flashcard]?, reverseMode: Bool = false, typingMode: Bool = false, shuffleMode: Bool = true) {
        self.deck = deck
        self.languageCode = deck.languageCode
        self.reverseMode = reverseMode
        self.typingMode = typingMode
        let cards: [Flashcard]
        if let specific = specificCards {
            cards = specific
        } else {
            cards = Array(deck.cards)
        }
        self.shuffledCards = shuffleMode ? cards.shuffled() : cards.sorted { $0.rank < $1.rank }
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

    func saveProgress() {
        let key = "session_\(deck.name)_\(typingMode ? "type" : "flash")"
        UserDefaults.standard.set(currentIndex, forKey: key)
    }

    static func savedIndex(for deckName: String, typingMode: Bool) -> Int? {
        let key = "session_\(deckName)_\(typingMode ? "type" : "flash")"
        let val = UserDefaults.standard.integer(forKey: key)
        return val > 0 ? val : nil
    }

    static func clearSavedSession(for deckName: String, typingMode: Bool) {
        let key = "session_\(deckName)_\(typingMode ? "type" : "flash")"
        UserDefaults.standard.removeObject(forKey: key)
    }

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
            StudySession.clearSavedSession(for: deck.name, typingMode: typingMode)
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
        // Greetings & expressions
        "yes": ["ok", "okay", "yeah", "yep", "yea", "sure"],
        "no": ["nope", "nah"],
        "hello": ["hi", "hey", "greetings", "howdy"],
        "goodbye": ["bye", "see you", "farewell", "later"],
        "thank you": ["thanks", "cheers", "ty"],
        "please": ["pls"],
        "excuse me": ["sorry", "pardon"],
        "sorry": ["apologies", "excuse me", "pardon"],
        // Adjectives
        "good": ["fine", "well", "great", "nice", "decent"],
        "bad": ["poor", "terrible", "awful", "horrible"],
        "big": ["large", "huge", "enormous", "giant"],
        "small": ["little", "tiny", "mini", "miniature"],
        "beautiful": ["pretty", "lovely", "gorgeous", "attractive", "handsome"],
        "ugly": ["hideous", "unattractive"],
        "happy": ["glad", "joyful", "cheerful", "pleased", "content"],
        "sad": ["unhappy", "upset", "miserable", "depressed"],
        "angry": ["mad", "furious", "upset", "annoyed"],
        "afraid": ["scared", "frightened", "terrified", "fearful"],
        "strong": ["powerful", "mighty", "tough"],
        "weak": ["feeble", "frail"],
        "fast": ["quick", "rapid", "swift", "speedy"],
        "slow": ["sluggish", "gradual"],
        "hot": ["warm", "boiling", "burning"],
        "cold": ["cool", "chilly", "freezing", "frigid"],
        "new": ["fresh", "modern", "recent"],
        "old": ["ancient", "aged", "elderly"],
        "young": ["youthful", "juvenile"],
        "rich": ["wealthy", "affluent", "prosperous"],
        "poor": ["impoverished", "needy", "broke"],
        "clean": ["tidy", "neat", "spotless"],
        "dirty": ["filthy", "messy", "unclean"],
        "quiet": ["silent", "calm", "peaceful", "still"],
        "loud": ["noisy", "boisterous"],
        "easy": ["simple", "effortless", "straightforward"],
        "difficult": ["hard", "tough", "challenging", "complicated"],
        "important": ["significant", "crucial", "vital", "essential"],
        "dangerous": ["risky", "hazardous", "perilous", "unsafe"],
        "safe": ["secure", "protected"],
        "correct": ["right", "accurate", "proper"],
        "wrong": ["incorrect", "mistaken", "false"],
        "true": ["real", "genuine", "authentic"],
        "false": ["fake", "untrue", "incorrect"],
        "full": ["complete", "filled", "packed"],
        "empty": ["vacant", "bare", "hollow"],
        "near": ["close", "nearby", "adjacent"],
        "far": ["distant", "remote"],
        // People
        "man": ["guy", "male", "gentleman", "fellow"],
        "woman": ["lady", "female", "gal"],
        "child": ["kid", "youngster"],
        "baby": ["infant", "newborn"],
        "doctor": ["physician", "medic"],
        "teacher": ["instructor", "educator", "professor"],
        "student": ["pupil", "learner"],
        "friend": ["pal", "buddy", "mate", "companion"],
        "enemy": ["foe", "opponent", "rival"],
        // Places & things
        "house": ["home", "dwelling", "residence"],
        "room": ["chamber", "space"],
        "car": ["automobile", "vehicle", "auto"],
        "food": ["meal", "cuisine", "nourishment"],
        "water": ["h2o"],
        "money": ["cash", "currency", "funds"],
        "work": ["job", "employment", "occupation", "labor"],
        "shop": ["store", "market"],
        "road": ["street", "path", "way"],
        "town": ["city", "village"],
        "country": ["nation", "land", "state"],
        "world": ["earth", "globe"],
        // Verbs
        "speak": ["talk", "say", "tell", "communicate"],
        "eat": ["consume", "dine", "feed"],
        "drink": ["sip", "consume", "gulp"],
        "walk": ["stroll", "wander", "hike", "march"],
        "run": ["sprint", "jog", "dash", "race"],
        "begin": ["start", "commence", "initiate"],
        "end": ["finish", "stop", "complete", "conclude"],
        "buy": ["purchase", "acquire", "get"],
        "sell": ["vend", "trade"],
        "give": ["offer", "provide", "donate", "grant"],
        "take": ["grab", "get", "seize", "obtain"],
        "look": ["watch", "see", "observe", "view", "gaze"],
        "listen": ["hear"],
        "want": ["desire", "wish", "crave"],
        "need": ["require", "must have"],
        "like": ["enjoy", "appreciate", "fancy"],
        "love": ["adore", "cherish", "treasure"],
        "hate": ["despise", "detest", "loathe"],
        "think": ["believe", "consider", "ponder", "reflect"],
        "know": ["understand", "comprehend", "realize"],
        "learn": ["study", "discover", "master"],
        "teach": ["instruct", "educate", "train"],
        "help": ["assist", "aid", "support"],
        "try": ["attempt", "endeavor"],
        "make": ["create", "build", "construct", "produce"],
        "break": ["smash", "shatter", "crack", "destroy"],
        "fix": ["repair", "mend", "restore"],
        "send": ["deliver", "ship", "dispatch"],
        "receive": ["get", "obtain", "accept"],
        "open": ["unlock", "uncover"],
        "close": ["shut", "seal"],
        "come": ["arrive", "approach"],
        "go": ["leave", "depart", "travel"],
        "return": ["come back", "go back"],
        "wait": ["hold on", "stay", "remain"],
        "sleep": ["rest", "nap", "doze"],
        "wake": ["awaken", "get up", "rise"],
        "live": ["reside", "dwell", "exist"],
        "die": ["perish", "pass away"],
        "laugh": ["chuckle", "giggle"],
        "cry": ["weep", "sob"],
        "sing": ["chant", "vocalize"],
        "dance": ["boogie", "groove"],
        "play": ["perform", "act"],
        "write": ["compose", "author", "pen"],
        "read": ["peruse", "study"],
        "cook": ["prepare", "make food"],
        "wash": ["clean", "rinse", "scrub"],
        "wear": ["put on", "dress in"],
        "carry": ["hold", "bear", "transport"],
        "throw": ["toss", "hurl", "fling"],
        "catch": ["grab", "seize", "capture"],
        "cut": ["slice", "chop", "trim"],
        "pull": ["drag", "tug", "yank"],
        "push": ["shove", "press"],
        "choose": ["select", "pick", "opt"],
        "decide": ["determine", "resolve"],
        "change": ["alter", "modify", "adjust"],
        "grow": ["expand", "develop", "increase"],
        "fall": ["drop", "tumble", "collapse"],
        "fly": ["soar", "glide"],
        "swim": ["float", "paddle"],
        "drive": ["operate", "steer"],
        "travel": ["journey", "voyage", "tour"],
        "search": ["look for", "seek", "hunt"],
        "find": ["discover", "locate", "uncover"],
        "lose": ["misplace"],
        "win": ["triumph", "succeed", "prevail"],
        "fight": ["battle", "combat", "struggle"],
        "treat": ["cure", "heal", "remedy", "care for"],
        "cure": ["heal", "treat", "remedy"],
        "heal": ["cure", "treat", "recover", "mend"],
        "ill": ["sick", "unwell", "diseased"],
        "sick": ["ill", "unwell"],
        "pain": ["ache", "hurt", "suffering"],
        "answer": ["reply", "respond"],
        "ask": ["question", "inquire", "request"],
        "explain": ["describe", "clarify"],
        "show": ["display", "demonstrate", "present", "reveal"],
        "hide": ["conceal", "cover"],
        "call": ["phone", "ring", "contact"],
        "meet": ["encounter", "greet"],
        "leave": ["depart", "exit", "go"],
        "stay": ["remain", "linger"],
        "forget": ["overlook"],
        "remember": ["recall", "recollect"],
        // Adverbs
        "also": ["too", "as well", "additionally"],
        "very": ["really", "extremely", "incredibly", "highly"],
        "always": ["forever", "constantly", "perpetually"],
        "never": ["not ever", "at no time"],
        "often": ["frequently", "regularly"],
        "sometimes": ["occasionally", "at times"],
        "maybe": ["perhaps", "possibly", "potentially"],
        "now": ["currently", "at the moment", "presently"],
        "already": ["previously"],
        "soon": ["shortly", "before long"],
        "quickly": ["rapidly", "swiftly", "fast"],
        "slowly": ["gradually", "unhurriedly"],
        "enough": ["sufficient", "adequate"],
        "together": ["jointly", "collectively"],
        "alone": ["by oneself", "solo"],
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

    init(deck: Deck, specificCards: [Flashcard]? = nil, reverseMode: Bool = false, typingMode: Bool = false, shuffleMode: Bool = true) {
        let session = StudySession(deck: deck, specificCards: specificCards, reverseMode: reverseMode, typingMode: typingMode, shuffleMode: shuffleMode)
        // Resume from saved position if available
        if let savedIdx = StudySession.savedIndex(for: deck.name, typingMode: typingMode),
           savedIdx < session.shuffledCards.count {
            session.currentIndex = savedIdx
        }
        _session = State(initialValue: session)
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
                Button("Quit") {
                    session.saveProgress()
                    dismiss()
                }
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
            speakLanguage: session.reverseMode ? session.languageCode : "en-US",
            example: session.currentCard?.example ?? ""
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
                            .foregroundStyle(.red)
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
                    .foregroundStyle(session.answerCorrect ? .green : .orange)

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
    var example: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1)

            Text(text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)

            if !example.isEmpty {
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }

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

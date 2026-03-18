import SwiftUI

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    let deck: Deck

    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var cardRotation: Double = 0
    @State private var correctCount = 0
    @State private var incorrectCount = 0
    @State private var showingResults = false
    @State private var shuffledCards: [Flashcard] = []
    @State private var dragOffset: CGSize = .zero
    @State private var history: [(index: Int, wasCorrect: Bool)] = []
    @State private var correctCards: [Flashcard] = []
    @State private var incorrectCards: [Flashcard] = []
    @State private var showingReStudy = false
    @State private var sessionId = UUID()

    private let sourceCards: [Flashcard]

    init(deck: Deck, specificCards: [Flashcard]? = nil) {
        self.deck = deck
        if let specific = specificCards {
            self.sourceCards = specific
        } else {
            self.sourceCards = Array(deck.cards)
        }
    }

    var body: some View {
        NavigationStack {
            if showingResults {
                resultsView
            } else if shuffledCards.isEmpty {
                ProgressView()
            } else {
                studyView
            }
        }
        .task(id: sessionId) {
            if shuffledCards.isEmpty {
                shuffledCards = sourceCards.shuffled()
            }
        }
    }

    // MARK: - Study View

    private var studyView: some View {
        VStack(spacing: 16) {
            studyHeader
            Spacer()
            studyCard
            Spacer()
            swipeHints
            actionButtons
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Quit") { dismiss() }
            }
        }
    }

    private var studyHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(currentIndex + 1) / \(shuffledCards.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            ProgressView(value: Double(currentIndex), total: Double(shuffledCards.count))
                .tint(.indigo)
                .padding(.horizontal)
        }
    }

    private var studyCard: some View {
        ZStack {
            cardBack
            cardFront
        }
        .id(currentIndex)
        .offset(x: dragOffset.width)
        .rotationEffect(.degrees(dragOffset.width / 30))
        .gesture(swipeGesture)
        .onTapGesture { flipCard() }
    }

    private var cardFront: some View {
        let card = shuffledCards[currentIndex]
        return StudyCardFace(
            text: card.front,
            subtitle: card.rank > 0 ? "#\(card.rank)" : "Word",
            color: .indigo,
            speakLanguage: deck.languageCode
        )
        .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 0 : 1)
    }

    private var cardBack: some View {
        StudyCardFace(
            text: shuffledCards[currentIndex].back,
            subtitle: "Answer",
            color: .blue,
            speakLanguage: "en-US"
        )
        .rotation3DEffect(.degrees(cardRotation + 180), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 1 : 0)
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in dragOffset = value.translation }
            .onEnded { value in
                if value.translation.width > 100 {
                    markCorrect()
                } else if value.translation.width < -100 {
                    markIncorrect()
                } else {
                    withAnimation(.spring()) { dragOffset = .zero }
                }
            }
    }

    private var swipeHints: some View {
        HStack {
            Image(systemName: "hand.point.left.fill")
                .foregroundStyle(.red.opacity(0.5))
            Text("Don't Know")
                .foregroundStyle(.red.opacity(0.7))
            Spacer()
            Text("Tap to flip")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Got It")
                .foregroundStyle(.green.opacity(0.7))
            Image(systemName: "hand.point.right.fill")
                .foregroundStyle(.green.opacity(0.5))
        }
        .font(.caption)
        .padding(.horizontal, 24)
    }

    private var actionButtons: some View {
        HStack(spacing: 30) {
            Button { goBack() } label: {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
            .disabled(history.isEmpty)

            Button { markIncorrect() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.red)
            }

            Button { markCorrect() } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.green)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            cardRotation += 180
            isFlipped.toggle()
        }
    }

    private func markCorrect() {
        let card = shuffledCards[currentIndex]
        card.correctCount += 1
        card.lastReviewedAt = Date()
        correctCount += 1
        correctCards.append(card)
        history.append((index: currentIndex, wasCorrect: true))
        nextCard()
    }

    private func markIncorrect() {
        let card = shuffledCards[currentIndex]
        card.incorrectCount += 1
        card.lastReviewedAt = Date()
        incorrectCount += 1
        incorrectCards.append(card)
        history.append((index: currentIndex, wasCorrect: false))
        nextCard()
    }

    private func nextCard() {
        // Reset drag instantly (no animation) to prevent visual glitch
        dragOffset = .zero

        if currentIndex + 1 < shuffledCards.count {
            currentIndex += 1
            isFlipped = false
            cardRotation = 0
        } else {
            showingResults = true
        }
    }

    private func goBack() {
        guard let entry = history.popLast() else { return }
        let card = shuffledCards[entry.index]
        if entry.wasCorrect {
            card.correctCount = max(0, card.correctCount - 1)
            correctCount = max(0, correctCount - 1)
            correctCards.removeAll { $0 === card }
        } else {
            card.incorrectCount = max(0, card.incorrectCount - 1)
            incorrectCount = max(0, incorrectCount - 1)
            incorrectCards.removeAll { $0 === card }
        }
        dragOffset = .zero
        currentIndex = entry.index
        isFlipped = false
        cardRotation = 0
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                resultsSummaryHeader
                resultsStatsCard

                if !incorrectCards.isEmpty {
                    reStudyButton
                }

                if !incorrectCards.isEmpty {
                    resultsSection(title: "Incorrect", icon: "xmark.circle.fill", color: .red, cards: incorrectCards)
                }

                if !correctCards.isEmpty {
                    resultsSection(title: "Correct", icon: "checkmark.circle.fill", color: .green, cards: correctCards)
                }

                doneButton
            }
            .padding()
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingReStudy) {
            StudySessionView(deck: deck, specificCards: incorrectCards)
        }
    }

    private var resultsSummaryHeader: some View {
        let percentage = shuffledCards.isEmpty ? 0 : Int(Double(correctCount) / Double(shuffledCards.count) * 100)
        let icon = percentage >= 80 ? "star.fill" : percentage >= 50 ? "hand.thumbsup.fill" : "arrow.clockwise"
        let iconColor: Color = percentage >= 80 ? .yellow : percentage >= 50 ? .blue : .orange
        let message = percentage >= 80 ? "Great Job!" : percentage >= 50 ? "Good Effort!" : "Keep Practicing!"

        return VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.title.bold())
            Text(deck.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var resultsStatsCard: some View {
        let percentage = shuffledCards.isEmpty ? 0 : Int(Double(correctCount) / Double(shuffledCards.count) * 100)
        return VStack(spacing: 12) {
            ResultRow(label: "Total", value: "\(shuffledCards.count) cards", color: .primary)
            ResultRow(label: "Correct", value: "\(correctCount)", color: .green)
            ResultRow(label: "Incorrect", value: "\(incorrectCount)", color: .red)
            ResultRow(label: "Accuracy", value: "\(percentage)%", color: .indigo)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reStudyButton: some View {
        Button { showingReStudy = true } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Re-study \(incorrectCards.count) Mistakes")
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
                    ResultCardRow(card: card, languageCode: deck.languageCode)
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

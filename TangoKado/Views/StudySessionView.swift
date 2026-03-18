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
    @State private var shuffledCards: [Flashcard]
    @State private var dragOffset: CGSize = .zero
    @State private var history: [(index: Int, wasCorrect: Bool)] = []

    init(deck: Deck) {
        self.deck = deck
        _shuffledCards = State(initialValue: deck.cards.shuffled())
    }

    var body: some View {
        NavigationStack {
            if showingResults {
                resultsView
            } else if shuffledCards.isEmpty {
                ContentUnavailableView("No Cards", systemImage: "rectangle.slash")
            } else {
                studyView
            }
        }
    }

    private var studyView: some View {
        VStack(spacing: 16) {
            // Progress bar
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

            Spacer()

            // Card
            ZStack {
                cardFace(
                    text: shuffledCards[currentIndex].back,
                    subtitle: "Answer",
                    color: .blue,
                    speakLanguage: "en-US"
                )
                .rotation3DEffect(.degrees(cardRotation + 180), axis: (x: 0, y: 1, z: 0))
                .opacity(abs(cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 1 : 0)

                cardFace(
                    text: shuffledCards[currentIndex].front,
                    subtitle: shuffledCards[currentIndex].rank > 0 ? "#\(shuffledCards[currentIndex].rank)" : "Word",
                    color: .indigo,
                    speakLanguage: deck.languageCode
                )
                .rotation3DEffect(.degrees(cardRotation), axis: (x: 0, y: 1, z: 0))
                .opacity(abs(cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 0 : 1)
            }
            .offset(x: dragOffset.width)
            .rotationEffect(.degrees(dragOffset.width / 30))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        if value.translation.width > 100 {
                            markCorrect()
                        } else if value.translation.width < -100 {
                            markIncorrect()
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .onTapGesture {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    cardRotation += 180
                    isFlipped.toggle()
                }
            }

            Spacer()

            // Swipe hints
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

            // Action buttons
            HStack(spacing: 30) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                }
                .disabled(history.isEmpty)

                Button {
                    markIncorrect()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.red)
                }

                Button {
                    markCorrect()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(.green)
                }
            }
            .padding(.bottom, 8)
        }
        .navigationTitle(deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Quit") {
                    dismiss()
                }
            }
        }
    }

    private func cardFace(text: String, subtitle: String, color: Color, speakLanguage: String? = nil) -> some View {
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

    private func markCorrect() {
        let card = shuffledCards[currentIndex]
        card.correctCount += 1
        card.lastReviewedAt = Date()
        correctCount += 1
        history.append((index: currentIndex, wasCorrect: true))
        nextCard()
    }

    private func markIncorrect() {
        let card = shuffledCards[currentIndex]
        card.incorrectCount += 1
        card.lastReviewedAt = Date()
        incorrectCount += 1
        history.append((index: currentIndex, wasCorrect: false))
        nextCard()
    }

    private func nextCard() {
        withAnimation(.spring()) {
            dragOffset = .zero
        }

        if currentIndex + 1 < shuffledCards.count {
            withAnimation {
                currentIndex += 1
                isFlipped = false
                cardRotation = 0
            }
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
        } else {
            card.incorrectCount = max(0, card.incorrectCount - 1)
            incorrectCount = max(0, incorrectCount - 1)
        }

        withAnimation {
            currentIndex = entry.index
            isFlipped = false
            cardRotation = 0
        }
    }

    private var resultsView: some View {
        VStack(spacing: 24) {
            Spacer()

            let percentage = shuffledCards.isEmpty ? 0 : Int(Double(correctCount) / Double(shuffledCards.count) * 100)
            let emoji = percentage >= 80 ? "star.fill" : percentage >= 50 ? "hand.thumbsup.fill" : "arrow.clockwise"

            Image(systemName: emoji)
                .font(.system(size: 60))
                .foregroundStyle(percentage >= 80 ? .yellow : percentage >= 50 ? .blue : .orange)

            Text(percentage >= 80 ? "Great Job!" : percentage >= 50 ? "Good Effort!" : "Keep Practicing!")
                .font(.largeTitle.bold())

            Text(deck.name)
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ResultRow(label: "Total", value: "\(shuffledCards.count) cards", color: .primary)
                ResultRow(label: "Correct", value: "\(correctCount)", color: .green)
                ResultRow(label: "Incorrect", value: "\(incorrectCount)", color: .red)
                ResultRow(label: "Accuracy", value: "\(percentage)%", color: .indigo)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
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

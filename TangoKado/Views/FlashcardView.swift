import SwiftUI

struct FlashcardView: View {
    let card: Flashcard
    @State private var isFlipped = false
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Back side
            cardFace(text: card.back, subtitle: "答え", color: .blue)
                .rotation3DEffect(.degrees(rotation + 180), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation < -90 || rotation > 90 ? 0 : 1)

            // Front side
            cardFace(text: card.front, subtitle: "問題", color: .indigo)
                .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation < -90 || rotation > 90 ? 0 : 1)
        }
        .onTapGesture {
            flipCard()
        }
    }

    private func cardFace(text: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 16) {
            Text(subtitle)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))

            Text(text)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(color.gradient)
                .shadow(radius: 10)
        )
        .padding()
    }

    private func flipCard() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            rotation += 180
        }
        isFlipped.toggle()
    }

    func reset() {
        isFlipped = false
        rotation = 0
    }
}

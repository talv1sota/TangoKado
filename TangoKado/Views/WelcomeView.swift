import SwiftUI

struct WelcomeView: View {
    @Binding var hasSeenWelcome: Bool
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage(
                    icon: "character.book.closed.fill",
                    title: "TangoKado",
                    subtitle: "Learn the most common words\nin any language",
                    color: .indigo
                )
                .tag(0)

                welcomePage(
                    icon: "rectangle.portrait.on.rectangle.portrait.fill",
                    title: "Study Smart",
                    subtitle: "Tap to flip cards\nSwipe to navigate\nTrack your mastery",
                    color: .blue
                )
                .tag(1)

                welcomePage(
                    icon: "chart.bar.fill",
                    title: "Track Progress",
                    subtitle: "See which words you've mastered\nand which need more practice",
                    color: .green
                )
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if currentPage < 2 {
                    withAnimation {
                        currentPage += 1
                    }
                } else {
                    hasSeenWelcome = true
                }
            } label: {
                Text(currentPage < 2 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Button("Skip") {
                hasSeenWelcome = true
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .opacity(currentPage < 2 ? 1 : 0)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
    }

    private func welcomePage(icon: String, title: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 72))
                .foregroundStyle(color)
                .padding(.bottom, 8)

            Text(title)
                .font(.largeTitle.bold())

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

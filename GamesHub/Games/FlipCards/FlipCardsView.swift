import SwiftUI

struct FlipCardsCard: Identifiable {
    let id: Int
    let value: Int
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

enum FlipCardsPhase {
    case start, playing, won
}

struct FlipCardsView: View {
    @State private var cards: [FlipCardsCard] = []
    @State private var phase: FlipCardsPhase = .start
    @State private var moves: Int = 0
    @State private var firstIndex: Int? = nil
    @State private var isLocked: Bool = false
    @State private var recentResults: [Bool] = []
    @State private var flipBackDelay: Double = 0.8

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.25, green: 0.1, blue: 0.55), Color(red: 0.05, green: 0.35, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .won:
                wonScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Flip Cards")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Match all 8 pairs.\nTap two cards to reveal them.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
            glassButton("Start Game", action: startGame)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 40)
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MOVES")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(moves)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SPEED")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Text(flipBackDelay < 0.65 ? "FAST" : (flipBackDelay < 0.75 ? "MEDIUM" : "NORMAL"))
                        .font(.caption.bold())
                        .foregroundColor(flipBackDelay < 0.65 ? .orange : .white.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cards) { card in
                    FlipCardsCardCell(card: card)
                        .onTapGesture { handleTap(card: card) }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 20)
    }

    var wonScreen: some View {
        VStack(spacing: 24) {
            Text("You Won!")
                .font(.largeTitle.bold())
                .foregroundColor(.yellow)
            Text("Completed in \(moves) moves")
                .foregroundColor(.white.opacity(0.85))
                .font(.title3)
            glassButton("Play Again", action: startGame)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 40)
    }

    @ViewBuilder
    func glassButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    func startGame() {
        let values = (1...8).flatMap { [$0, $0] }.shuffled()
        cards = values.enumerated().map { FlipCardsCard(id: $0.offset, value: $0.element) }
        moves = 0
        firstIndex = nil
        isLocked = false

        adjustDifficulty()
    }

    func adjustDifficulty() {
        guard recentResults.count >= 5 else { return }
        let last5 = recentResults.suffix(5)
        let successCount = last5.filter { $0 }.count
        if successCount > 4 {
            flipBackDelay = max(0.4, flipBackDelay * 0.8)
        }
    }

    func handleTap(card: FlipCardsCard) {
        guard !isLocked,
              !card.isFaceUp,
              !card.isMatched,
              let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }

        withAnimation(.easeInOut(duration: 0.3)) {
            cards[idx].isFaceUp = true
        }

        if let first = firstIndex {
            moves += 1
            firstIndex = nil
            isLocked = true
            let matched = cards[first].value == cards[idx].value
            if matched {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    cards[first].isMatched = true
                    cards[idx].isMatched = true
                    isLocked = false
                    if cards.allSatisfy({ $0.isMatched }) {
                        recentResults.append(true)
                        phase = .won
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + flipBackDelay) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cards[first].isFaceUp = false
                        cards[idx].isFaceUp = false
                    }
                    recentResults.append(false)
                    isLocked = false
                }
            }
        } else {
            firstIndex = idx
        }
    }
}

struct FlipCardsCardCell: View {
    let card: FlipCardsCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(card.isMatched
                    ? Color.green.opacity(0.35)
                    : (card.isFaceUp ? Color.white.opacity(0.25) : Color.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))

            if card.isFaceUp || card.isMatched {
                Text("\(card.value)")
                    .font(.title.bold())
                    .foregroundColor(card.isMatched ? .green : .white)
            } else {
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(height: 75)
        .scaleEffect(card.isFaceUp ? 1.06 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: card.isFaceUp)
    }
}

#Preview { FlipCardsView() }

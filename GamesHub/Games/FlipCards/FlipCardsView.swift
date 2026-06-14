import SwiftUI

struct FlCdCard: Identifiable {
    let id: Int
    let value: Int
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

enum FlCdPhase {
    case start, playing, won
}

struct FlipCardsView: View {
    @State private var cards: [FlCdCard] = []
    @State private var phase: FlCdPhase = .start
    @State private var moves: Int = 0
    @State private var firstIndex: Int? = nil
    @State private var isLocked: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
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
        VStack(spacing: 24) {
            Text("Flip Cards")
                .font(.largeTitle.bold())
            Text("Match all 8 pairs of numbers.\nTap two cards to flip them.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.title2.bold())
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            Text("Moves: \(moves)")
                .font(.title2.bold())
            let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cards) { card in
                    FlCdCardCell(card: card)
                        .onTapGesture {
                            handleTap(card: card)
                        }
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
                .foregroundColor(.green)
            Text("Completed in \(moves) moves")
                .font(.title2)
                .foregroundStyle(.secondary)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }

    func startGame() {
        let values = (1...8).flatMap { [$0, $0] }.shuffled()
        cards = values.enumerated().map { FlCdCard(id: $0.offset, value: $0.element) }
        moves = 0
        firstIndex = nil
        isLocked = false
        phase = .playing
    }

    func handleTap(card: FlCdCard) {
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
            if cards[first].value == cards[idx].value {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    cards[first].isMatched = true
                    cards[idx].isMatched = true
                    isLocked = false
                    if cards.allSatisfy({ $0.isMatched }) {
                        phase = .won
                    }
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        cards[first].isFaceUp = false
                        cards[idx].isFaceUp = false
                    }
                    isLocked = false
                }
            }
        } else {
            firstIndex = idx
        }
    }
}

struct FlCdCardCell: View {
    let card: FlCdCard

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(card.isMatched ? Color.green.opacity(0.3) : (card.isFaceUp ? Color.blue.opacity(0.15) : Color.blue))
            if card.isFaceUp || card.isMatched {
                Text("\(card.value)")
                    .font(.title.bold())
                    .foregroundColor(card.isMatched ? .green : .blue)
            } else {
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .frame(height: 75)
        .scaleEffect(card.isFaceUp ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: card.isFaceUp)
    }
}

#Preview { FlipCardsView() }

import SwiftUI

struct FlCdLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct FlCdV3Card: Identifiable {
    let id: Int
    let value: Int
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

enum FlCdV3Phase {
    case start, playing, won
}

struct FlipCardsViewV3: View {
    @State private var cards: [FlCdV3Card] = []
    @State private var phase: FlCdV3Phase = .start
    @State private var moves: Int = 0
    @State private var firstIndex: Int? = nil
    @State private var isLocked: Bool = false
    @State private var seedInt: Int = 1

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                .foregroundColor(.primary)
            Text("Match all 8 pairs of numbers.\nTap two cards to reveal them.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.title2.bold())
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .foregroundColor(.primary)
            }
            .neumorphicCard(radius: 14)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(.horizontal, 40)
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MOVES")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("\(moves)")
                        .font(.title.bold())
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(cards) { card in
                    FlCdV3CardCell(card: card)
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
                .foregroundColor(.green)
            Text("Completed in \(moves) moves")
                .font(.title3)
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .foregroundColor(.primary)
            }
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(.horizontal, 40)
    }

    func startGame() {
        seedInt += 1
        var lcg = FlCdLCG(seed: seedInt)
        var values = (1...8).flatMap { [$0, $0] }
        for i in stride(from: values.count - 1, through: 1, by: -1) {
            let j = lcg.nextInt(i + 1)
            values.swapAt(i, j)
        }
        cards = values.enumerated().map { FlCdV3Card(id: $0.offset, value: $0.element) }
        moves = 0
        firstIndex = nil
        isLocked = false
        phase = .playing
    }

    func handleTap(card: FlCdV3Card) {
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        cards[first].isMatched = true
                        cards[idx].isMatched = true
                    }
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

struct FlCdV3CardCell: View {
    let card: FlCdV3Card

    var body: some View {
        ZStack {
            if card.isFaceUp || card.isMatched {
                Text("\(card.value)")
                    .font(.title.bold())
                    .foregroundColor(card.isMatched ? .green : .primary)
            } else {
                Image(systemName: "questionmark")
                    .font(.title2.bold())
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 72)
        .frame(maxWidth: .infinity)
        .neumorphicCard(radius: 12)
        .scaleEffect(card.isFaceUp ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: card.isFaceUp)
    }
}

#Preview { FlipCardsViewV3() }

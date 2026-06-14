import SwiftUI

// MARK: - LCG Seeded RNG

struct HLLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

enum HLV3Suit: String, CaseIterable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum HLV3Rank: Int, CaseIterable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    var display: String {
        switch self {
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return "\(rawValue)"
        }
    }
}

struct HLV3Card: Equatable {
    let rank: HLV3Rank
    let suit: HLV3Suit
}

enum HLV3Phase { case start, playing, gameOver }

// MARK: - View

struct HighLowViewV3: View {
    @State private var phase: HLV3Phase = .start
    @State private var deck: [HLV3Card] = []
    @State private var currentCard: HLV3Card? = nil
    @State private var score: Int = 0
    @AppStorage("hlV3HighScore") private var highScore: Int = 0
    @State private var seedInt: Int = 1
    @State private var showResult: Bool = false
    @State private var resultCorrect: Bool = false
    @State private var cardFlipAngle: Double = 0
    @State private var decorOffsets: [CGSize] = []

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            decorativeBackground
            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
        .onAppear { generateDecorations() }
    }

    // MARK: Decorative Background

    private var decorativeBackground: some View {
        GeometryReader { geo in
            ForEach(0..<decorOffsets.count, id: \.self) { i in
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .offset(decorOffsets[i])
            }
        }
        .ignoresSafeArea()
    }

    private func generateDecorations() {
        var lcg = HLLCG(seed: seedInt)
        decorOffsets = (0..<8).map { _ in
            CGSize(
                width: lcg.nextDouble() * 350 - 50,
                height: lcg.nextDouble() * 700 - 50
            )
        }
    }

    // MARK: Screens

    private var startScreen: some View {
        VStack(spacing: 30) {
            VStack(spacing: 8) {
                Text("High Low")
                    .font(.system(size: 44, weight: .bold))
                Text("Seeded Edition")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .neumorphicCard(radius: 20)

            VStack(spacing: 10) {
                Text("Guess if the next card is\nHigher or Lower")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Text("Best: \(highScore)")
                    .font(.headline)
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("Start Game")
                    .font(.title2.bold())
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
            }
        }
        .padding(24)
    }

    private var gameScreen: some View {
        VStack(spacing: 22) {
            HStack {
                neuStatBox(label: "Score", value: "\(score)")
                Spacer()
                neuStatBox(label: "Best", value: "\(highScore)")
            }
            .padding(.horizontal)

            if let card = currentCard {
                neuCardView(card)
                    .frame(width: 170, height: 230)
                    .rotation3DEffect(.degrees(cardFlipAngle), axis: (x: 0, y: 1, z: 0))
            }

            if showResult {
                Text(resultCorrect ? "Correct!" : "Wrong!")
                    .font(.headline.bold())
                    .foregroundColor(resultCorrect ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 16) {
                neuActionButton("↓ Lower") { guess(higher: false) }
                neuActionButton("Higher ↑") { guess(higher: true) }
            }
            .padding(.horizontal)

            Text("SEED: #\(seedInt)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color(.systemGray3))
        }
        .padding(.vertical)
    }

    private var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.largeTitle.bold())

            VStack(spacing: 16) {
                Text("Streak")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(score)")
                    .font(.system(size: 64, weight: .bold))
                if score >= highScore && score > 0 {
                    Text("New High Score!")
                        .font(.headline.bold())
                        .foregroundColor(.orange)
                }
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(.systemGray3))
            }
            .padding(28)
            .neumorphicCard(radius: 20)

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
            }
        }
        .padding(24)
    }

    // MARK: Components

    private func neuStatBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title.bold())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .neumorphicCard(radius: 12)
    }

    private func neuCardView(_ card: HLV3Card) -> some View {
        ZStack {
            VStack {
                HStack {
                    Text(card.rank.display).font(.title2.bold())
                    Text(card.suit.rawValue).font(.title2)
                    Spacer()
                }
                Spacer()
                Text(card.suit.rawValue).font(.system(size: 56))
                Spacer()
                HStack {
                    Spacer()
                    Text(card.rank.display).font(.title2.bold())
                    Text(card.suit.rawValue).font(.title2)
                }
            }
            .padding(14)
            .foregroundColor(card.suit.isRed ? .red : .primary)
        }
        .neumorphicCard(radius: 18)
    }

    private func neuActionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundColor(.primary)
        }
        .neumorphicCard(radius: 14)
    }

    // MARK: Logic

    private func buildDeck(lcg: inout HLLCG) -> [HLV3Card] {
        var allCards: [HLV3Card] = []
        for suit in HLV3Suit.allCases {
            for rank in HLV3Rank.allCases {
                allCards.append(HLV3Card(rank: rank, suit: suit))
            }
        }
        // LCG-based Fisher-Yates shuffle
        for i in stride(from: allCards.count - 1, through: 1, by: -1) {
            let j = lcg.nextInt(i + 1)
            allCards.swapAt(i, j)
        }
        return allCards
    }

    private func startGame() {
        seedInt += 1
        var lcg = HLLCG(seed: seedInt)
        deck = buildDeck(lcg: &lcg)
        score = 0
        showResult = false
        cardFlipAngle = 0
        currentCard = deck.removeFirst()
        phase = .playing
        generateDecorations()
    }

    private func guess(higher: Bool) {
        guard let current = currentCard, !deck.isEmpty else {
            endGame()
            return
        }
        let next = deck.removeFirst()
        let correct: Bool
        if next.rank == current.rank {
            correct = true
        } else {
            correct = higher ? (next.rank.rawValue > current.rank.rawValue)
                             : (next.rank.rawValue < current.rank.rawValue)
        }

        // Flip animation
        withAnimation(.easeIn(duration: 0.15)) { cardFlipAngle = 90 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentCard = next
            withAnimation(.easeOut(duration: 0.15)) { cardFlipAngle = 0 }
        }

        resultCorrect = correct
        if correct {
            score += 1
            if score > highScore { highScore = score }
            withAnimation { showResult = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { showResult = false }
            }
        } else {
            withAnimation { showResult = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { endGame() }
        }
    }

    private func endGame() {
        phase = .gameOver
    }
}

#Preview { HighLowViewV3() }

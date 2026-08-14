import SwiftUI

// MARK: - Models

enum HLSuit: String, CaseIterable {
    case spades = "♠", hearts = "♥", diamonds = "♦", clubs = "♣"
    var isRed: Bool { self == .hearts || self == .diamonds }
}

enum HLRank: Int, CaseIterable {
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

struct HLCard: Equatable {
    let rank: HLRank
    let suit: HLSuit
}

enum HLPhase { case start, playing, gameOver }

// MARK: - View

struct HighLowView: View {
    @State private var phase: HLPhase = .start
    @State private var deck: [HLCard] = []
    @State private var currentCard: HLCard? = nil
    @State private var score: Int = 0
    @AppStorage("highLowHighScore") private var highScore: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false
    @State private var cardScale: CGFloat = 1.0

    private let gradient = LinearGradient(
        colors: [Color(red: 0.1, green: 0.1, blue: 0.35), Color(red: 0.3, green: 0.1, blue: 0.4)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            gradient.ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
    }

    // MARK: Screens

    private var startScreen: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("High Low")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
                Text("Adaptive Difficulty")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }

            glassPanel {
                VStack(spacing: 12) {
                    Text("Guess if the next card is Higher or Lower")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.white.opacity(0.9))
                    Text("Best: \(highScore)")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
            }

            actionButton("Start Game", color: Color.purple.opacity(0.8)) { startGame() }
        }
        .padding(24)
    }

    private var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                statBox(label: "Score", value: "\(score)")
                Spacer()
                statBox(label: "Best", value: "\(highScore)")
            }
            .padding(.horizontal)

            if difficultyMultiplier > 1.05 {
                Text("HARD MODE")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if let card = currentCard {
                glassCardView(card)
                    .frame(width: 170, height: 230)
                    .scaleEffect(cardScale)
            }

            if showResult {
                Text(resultMessage)
                    .font(.headline.bold())
                    .foregroundColor(resultMessage == "Correct!" ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }

            HStack(spacing: 16) {
                glassActionButton("↓ Lower", color: .red) { guess(higher: false) }
                glassActionButton("Higher ↑", color: .green) { guess(higher: true) }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }

    private var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundColor(.white)

            glassPanel {
                VStack(spacing: 16) {
                    Text("Streak")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(score)")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                    if score >= highScore && score > 0 {
                        Text("New Best!")
                            .font(.headline.bold())
                            .foregroundColor(.orange)
                    }
                }
                .padding(24)
            }

            actionButton("Play Again", color: Color.purple.opacity(0.8)) { startGame() }
        }
        .padding(24)
    }

    // MARK: Components

    private func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func statBox(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundColor(.white.opacity(0.6))
            Text(value).font(.title.bold()).foregroundColor(.white)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func glassCardView(_ card: HLCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.4), lineWidth: 1.5)
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
            .foregroundColor(card.suit.isRed ? Color(red: 1, green: 0.3, blue: 0.3) : .white)
        }
    }

    private func glassActionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color.opacity(0.5))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    private func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(color)
                .foregroundColor(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: Logic

    private func buildDeck() -> [HLCard] {
        var cards: [HLCard] = []
        for suit in HLSuit.allCases {
            for rank in HLRank.allCases {
                cards.append(HLCard(rank: rank, suit: suit))
            }
        }
        return cards.shuffled()
    }

    private func startGame() {
        deck = buildDeck()
        score = 0
        recentResults = []
        difficultyMultiplier = 1.0
        showResult = false
        currentCard = deck.removeFirst()
        phase = .playing
    }

    private func updateDifficulty(correct: Bool) {
        recentResults.append(correct)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 {
            let trueCount = recentResults.filter { $0 }.count
            if trueCount > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
                recentResults = []
            }
        }
    }

    /// As the streak grows, the next card is drawn closer in rank to the
    /// current one, so the call gets nearer to a coin flip.
    private func drawNext(after current: HLCard) -> HLCard {
        if deck.isEmpty { deck = buildDeck() }
        let band = max(1, Int(5.0 / difficultyMultiplier))
        if difficultyMultiplier > 1.05,
           let idx = deck.firstIndex(where: { abs($0.rank.rawValue - current.rank.rawValue) <= band }) {
            return deck.remove(at: idx)
        }
        return deck.removeFirst()
    }

    private func guess(higher: Bool) {
        guard let current = currentCard else {
            endGame()
            return
        }
        let next = drawNext(after: current)
        let correct: Bool
        if next.rank == current.rank {
            correct = true
        } else {
            correct = higher ? (next.rank.rawValue > current.rank.rawValue)
                             : (next.rank.rawValue < current.rank.rawValue)
        }
        updateDifficulty(correct: correct)
        withAnimation(.spring(response: 0.3)) { cardScale = 0.9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            currentCard = next
            withAnimation(.spring(response: 0.3)) { cardScale = 1.0 }
        }
        if correct {
            score += 1
            if score > highScore { highScore = score }
            resultMessage = "Correct!"
            withAnimation { showResult = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation { showResult = false }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { endGame() }
        }
    }

    private func endGame() {
        phase = .gameOver
    }
}

#Preview { HighLowView() }

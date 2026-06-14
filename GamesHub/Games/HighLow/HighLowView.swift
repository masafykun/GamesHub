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
    @AppStorage("hlHighScore") private var highScore: Int = 0
    @State private var resultMessage: String = ""
    @State private var showResult: Bool = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
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
            Text("High Low")
                .font(.system(size: 42, weight: .bold))
            Text("Guess if the next card\nis Higher or Lower")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Best: \(highScore)")
                .font(.headline)
                .foregroundStyle(.secondary)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.title2.bold())
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    private var gameScreen: some View {
        VStack(spacing: 28) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Score").font(.caption).foregroundStyle(.secondary)
                    Text("\(score)").font(.title.bold())
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Best").font(.caption).foregroundStyle(.secondary)
                    Text("\(highScore)").font(.title.bold())
                }
            }
            .padding(.horizontal)

            if let card = currentCard {
                cardView(card)
                    .frame(width: 160, height: 220)
            }

            if showResult {
                Text(resultMessage)
                    .font(.headline)
                    .foregroundStyle(resultMessage == "Correct!" ? .green : .red)
                    .transition(.opacity)
            }

            HStack(spacing: 24) {
                actionButton("Lower ↓", color: .red) { guess(higher: false) }
                actionButton("Higher ↑", color: .green) { guess(higher: true) }
            }
            .padding(.horizontal)
        }
        .padding()
    }

    private var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.largeTitle.bold())
            Text("Streak: \(score)")
                .font(.title2)
            if score >= highScore && score > 0 {
                Text("New High Score!")
                    .font(.headline)
                    .foregroundStyle(.orange)
            } else {
                Text("Best: \(highScore)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Button(action: startGame) {
                Text("Play Again")
                    .font(.title2.bold())
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: Components

    private func cardView(_ card: HLCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
            VStack {
                HStack {
                    Text(card.rank.display)
                        .font(.title2.bold())
                    Text(card.suit.rawValue)
                        .font(.title2)
                    Spacer()
                }
                Spacer()
                Text(card.suit.rawValue)
                    .font(.system(size: 52))
                Spacer()
                HStack {
                    Spacer()
                    Text(card.rank.display)
                        .font(.title2.bold())
                    Text(card.suit.rawValue)
                        .font(.title2)
                }
            }
            .padding(12)
            .foregroundColor(card.suit.isRed ? .red : .primary)
        }
    }

    private func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(color)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
        showResult = false
        currentCard = deck.removeFirst()
        phase = .playing
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
        currentCard = next
        if correct {
            score += 1
            if score > highScore { highScore = score }
            resultMessage = "Correct!"
            withAnimation { showResult = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { showResult = false }
        } else {
            endGame()
        }
    }

    private func endGame() {
        phase = .gameOver
    }
}

#Preview { HighLowView() }

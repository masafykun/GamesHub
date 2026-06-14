import SwiftUI

// MARK: - Models

enum EmMtGamePhase {
    case start, playing, won
}

struct EmMtCard: Identifiable {
    let id: Int
    let emoji: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - Main View

struct EmojiMatchView: View {
    @State private var phase: EmMtGamePhase = .start
    @State private var cards: [EmMtCard] = []
    @State private var firstFlippedIndex: Int? = nil
    @State private var isProcessing: Bool = false
    @State private var moves: Int = 0
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @State private var timer: Timer? = nil

    let emojis = ["🐶", "🐱", "🦊", "🐸", "🐼", "🦁", "🐨", "🦄"]

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

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Emoji Match")
                .font(.largeTitle).bold()
            Text("Find all 8 matching pairs!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Label("\(moves)", systemImage: "hand.tap")
                Spacer()
                Label(timeString, systemImage: "clock")
                Spacer()
                Label("\(score)", systemImage: "star.fill")
                    .foregroundStyle(.yellow)
            }
            .font(.headline)
            .padding(.horizontal)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(cards.indices, id: \.self) { i in
                    cardView(for: i)
                        .onTapGesture { handleTap(index: i) }
                }
            }
            .padding(.horizontal)
        }
    }

    var wonScreen: some View {
        VStack(spacing: 20) {
            Text("You Won!").font(.largeTitle).bold()
            Text("Moves: \(moves)").font(.title2)
            Text("Time: \(timeString)").font(.title2)
            Text("Score: \(score)").font(.title2).foregroundStyle(.yellow)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    // MARK: - Card View

    func cardView(for index: Int) -> some View {
        let card = cards[index]
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(card.isMatched ? Color.green.opacity(0.3) : (card.isFaceUp ? Color.blue.opacity(0.15) : Color.blue))
            if card.isFaceUp || card.isMatched {
                Text(card.emoji).font(.system(size: 32))
            } else {
                Image(systemName: "questionmark")
                    .font(.title).foregroundStyle(.white)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .scaleEffect(card.isMatched ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: card.isFaceUp)
    }

    // MARK: - Logic

    var timeString: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func startGame() {
        let pairs = emojis.flatMap { [$0, $0] }.shuffled()
        cards = pairs.enumerated().map { EmMtCard(id: $0.offset, emoji: $0.element) }
        firstFlippedIndex = nil
        isProcessing = false
        moves = 0
        score = 0
        elapsedTime = 0
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    func handleTap(index: Int) {
        guard !isProcessing,
              !cards[index].isMatched,
              !cards[index].isFaceUp else { return }

        cards[index].isFaceUp = true

        if let first = firstFlippedIndex {
            moves += 1
            isProcessing = true
            if cards[first].emoji == cards[index].emoji {
                cards[first].isMatched = true
                cards[index].isMatched = true
                score += 10
                firstFlippedIndex = nil
                isProcessing = false
                if cards.allSatisfy({ $0.isMatched }) {
                    timer?.invalidate()
                    phase = .won
                }
            } else {
                let second = index
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    cards[first].isFaceUp = false
                    cards[second].isFaceUp = false
                    firstFlippedIndex = nil
                    isProcessing = false
                }
            }
        } else {
            firstFlippedIndex = index
        }
    }
}

#Preview { EmojiMatchView() }

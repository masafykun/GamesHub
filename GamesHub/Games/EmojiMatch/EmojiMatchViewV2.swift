import SwiftUI

// MARK: - Models

enum EmMtV2Phase {
    case start, playing, won
}

struct EmMtV2Card: Identifiable {
    let id: Int
    let emoji: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - V2 View (Glassmorphism + Adaptive Difficulty)

struct EmojiMatchViewV2: View {
    @State private var phase: EmMtV2Phase = .start
    @State private var cards: [EmMtV2Card] = []
    @State private var firstFlippedIndex: Int? = nil
    @State private var isProcessing: Bool = false
    @State private var moves: Int = 0
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @State private var gameTimer: Timer? = nil

    // Adaptive difficulty
    @State private var recentResults: [Bool] = []
    @State private var flipBackDelay: Double = 1.0
    @State private var difficultyLabel: String = "Normal"

    let baseEmojis = ["🐶", "🐱", "🦊", "🐸", "🐼", "🦁", "🐨", "🦄"]

    var gradientColors: [Color] { [Color(red: 0.4, green: 0.2, blue: 0.8), Color(red: 0.1, green: 0.5, blue: 0.9)] }

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: wonScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Emoji Match")
                .font(.largeTitle).bold().foregroundStyle(.white)
            Text("Flip & match all 8 pairs!")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            glassButton("Start Game", action: startGame)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                glassLabel("\(moves)", icon: "hand.tap")
                Spacer()
                glassLabel(timeString, icon: "clock")
                Spacer()
                glassLabel("\(score)", icon: "star.fill")
            }
            .padding(.horizontal)

            Text("Difficulty: \(difficultyLabel)")
                .font(.caption).foregroundStyle(.white.opacity(0.7))

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
            Text("You Won!").font(.largeTitle).bold().foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("Moves: \(moves)").foregroundStyle(.white)
                Text("Time: \(timeString)").foregroundStyle(.white)
                Text("Score: \(score)").foregroundStyle(.yellow)
                Text("Difficulty: \(difficultyLabel)").foregroundStyle(.white.opacity(0.8))
            }
            .font(.title3)
            glassButton("Play Again", action: startGame)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: - Card View

    func cardView(for index: Int) -> some View {
        let card = cards[index]
        return ZStack {
            if card.isMatched {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.35))
            } else if card.isFaceUp {
                Color.clear
            } else {
                Color.clear
            }
            if card.isFaceUp || card.isMatched {
                Text(card.emoji).font(.system(size: 30))
            } else {
                Image(systemName: "suit.spade.fill")
                    .font(.title2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
        .animation(.spring(response: 0.35), value: card.isFaceUp)
    }

    // MARK: - Helper Views

    func glassLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func glassButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline).foregroundStyle(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Logic

    var timeString: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func startGame() {
        let pairs = baseEmojis.flatMap { [$0, $0] }.shuffled()
        cards = pairs.enumerated().map { EmMtV2Card(id: $0.offset, emoji: $0.element) }
        firstFlippedIndex = nil
        isProcessing = false
        moves = 0
        score = 0
        elapsedTime = 0
        flipBackDelay = 1.0
        difficultyLabel = "Normal"
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedTime += 1
        }
    }

    func updateDifficulty(matched: Bool) {
        recentResults.append(matched)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 {
            let trueCount = recentResults.filter { $0 }.count
            if trueCount > 4 {
                flipBackDelay = max(0.4, flipBackDelay * 0.8)
                difficultyLabel = flipBackDelay < 0.7 ? "Hard" : "Medium"
            }
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
                updateDifficulty(matched: true)
                firstFlippedIndex = nil
                isProcessing = false
                if cards.allSatisfy({ $0.isMatched }) {
                    gameTimer?.invalidate()
                    phase = .won
                }
            } else {
                let second = index
                updateDifficulty(matched: false)
                DispatchQueue.main.asyncAfter(deadline: .now() + flipBackDelay) {
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

#Preview { EmojiMatchViewV2() }

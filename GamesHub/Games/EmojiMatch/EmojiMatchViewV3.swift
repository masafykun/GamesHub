import SwiftUI

// MARK: - LCG Seeded RNG

struct EmMtLCG {
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

enum EmMtV3Phase {
    case start, playing, won
}

struct EmMtV3Card: Identifiable {
    let id: Int
    let emoji: String
    var isFaceUp: Bool = false
    var isMatched: Bool = false
}

// MARK: - V3 View (Neumorphism + Seeded Generation)

struct EmojiMatchViewV3: View {
    @State private var phase: EmMtV3Phase = .start
    @State private var cards: [EmMtV3Card] = []
    @State private var firstFlippedIndex: Int? = nil
    @State private var isProcessing: Bool = false
    @State private var moves: Int = 0
    @State private var score: Int = 0
    @State private var elapsedTime: Double = 0
    @State private var gameTimer: Timer? = nil
    @State private var seedInt: Int = 1

    let allEmojis = ["🐶","🐱","🦊","🐸","🐼","🦁","🐨","🦄","🐯","🦋","🦀","🐙","🦜","🦩","🐬","🦓"]

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                .font(.largeTitle).bold()
                .foregroundStyle(Color(.label))
            Text("Find all 8 matching pairs!")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(.tertiaryLabel))
            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                neuLabel("\(moves)", icon: "hand.tap")
                Spacer()
                neuLabel(timeString, icon: "clock")
                Spacer()
                neuLabel("\(score)", icon: "star.fill")
            }
            .padding(.horizontal)

            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(.tertiaryLabel))

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
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
            Text("You Won!")
                .font(.largeTitle).bold()
                .foregroundStyle(Color(.label))
            VStack(spacing: 8) {
                Text("Moves: \(moves)").font(.title3).foregroundStyle(Color(.label))
                Text("Time: \(timeString)").font(.title3).foregroundStyle(Color(.label))
                Text("Score: \(score)").font(.title3).foregroundStyle(.orange)
            }
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(Color(.tertiaryLabel))
            Button(action: startGame) {
                Text("Play Again")
                    .font(.headline)
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: - Card View

    func cardView(for index: Int) -> some View {
        let card = cards[index]
        return ZStack {
            if card.isFaceUp || card.isMatched {
                Text(card.emoji)
                    .font(.system(size: 30))
            } else {
                Image(systemName: "questionmark")
                    .font(.title2)
                    .foregroundStyle(Color(.secondaryLabel))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .neumorphicCard(radius: 12)
        .overlay(
            card.isMatched
                ? RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.6), lineWidth: 2)
                : nil
        )
        .scaleEffect(card.isMatched ? 0.95 : 1.0)
        .animation(.spring(response: 0.3), value: card.isFaceUp)
    }

    // MARK: - Helper Views

    func neuLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline).bold()
            .foregroundStyle(Color(.label))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .neumorphicCard(radius: 10)
    }

    // MARK: - Logic

    var timeString: String {
        let mins = Int(elapsedTime) / 60
        let secs = Int(elapsedTime) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func generateCards(seed: Int) -> [EmMtV3Card] {
        var rng = EmMtLCG(seed: seed)
        // Pick 8 emojis using LCG
        var pool = allEmojis
        var chosen: [String] = []
        for _ in 0..<8 {
            let idx = rng.nextInt(pool.count)
            chosen.append(pool[idx])
            pool.remove(at: idx)
        }
        // Create pairs and shuffle using LCG Fisher-Yates
        var pairs = chosen.flatMap { [$0, $0] }
        for i in stride(from: pairs.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            pairs.swapAt(i, j)
        }
        return pairs.enumerated().map { EmMtV3Card(id: $0.offset, emoji: $0.element) }
    }

    func startGame() {
        cards = generateCards(seed: seedInt)
        firstFlippedIndex = nil
        isProcessing = false
        moves = 0
        score = 0
        elapsedTime = 0
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
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
                    gameTimer?.invalidate()
                    seedInt += 1
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

#Preview { EmojiMatchViewV3() }

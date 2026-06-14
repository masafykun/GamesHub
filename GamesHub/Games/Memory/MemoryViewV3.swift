import SwiftUI


// MARK: - LCG Seeded RNG

struct MemoryV3LCG {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &+ 1))
    }

    mutating func next() -> UInt64 {
        // Knuth LCG parameters
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(next() % UInt64(upperBound))
    }
}

func memoryV3SeededShuffle<T>(array: inout [T], seed: Int) {
    var rng = MemoryV3LCG(seed: seed)
    for i in stride(from: array.count - 1, through: 1, by: -1) {
        let j = rng.nextInt(upperBound: i + 1)
        if i != j {
            array.swapAt(i, j)
        }
    }
}

// MARK: - Model

struct MemoryV3Card: Identifiable {
    let id: Int
    let symbol: String
    var isFlipped: Bool = false
    var isMatched: Bool = false
}

enum MemoryV3GameState {
    case idle, playing, blocked, won
}

// MARK: - Symbol Colors (muted for neumorphism)

private let memoryV3SymbolColors: [String: Color] = [
    "heart.fill":   Color(red: 0.75, green: 0.30, blue: 0.35),
    "star.fill":    Color(red: 0.72, green: 0.62, blue: 0.20),
    "moon.fill":    Color(red: 0.40, green: 0.38, blue: 0.68),
    "sun.max.fill": Color(red: 0.78, green: 0.52, blue: 0.18),
    "bolt.fill":    Color(red: 0.22, green: 0.58, blue: 0.72),
    "flame.fill":   Color(red: 0.78, green: 0.40, blue: 0.18),
    "drop.fill":    Color(red: 0.25, green: 0.48, blue: 0.72),
    "leaf.fill":    Color(red: 0.28, green: 0.60, blue: 0.35)
]

// MARK: - ViewModel

class MemoryV3ViewModel: ObservableObject {
    private let symbols = ["heart.fill", "star.fill", "moon.fill", "sun.max.fill",
                           "bolt.fill", "flame.fill", "drop.fill", "leaf.fill"]

    @Published var cards: [MemoryV3Card] = []
    @Published var gameState: MemoryV3GameState = .idle
    @Published var matches: Int = 0
    @Published var moves: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var seedInt: Int = 1

    private var firstSelectedIndex: Int? = nil
    private var timer: Timer? = nil

    init() {
        setupCards()
    }

    func setupCards() {
        var deck: [MemoryV3Card] = []
        for (index, symbol) in symbols.enumerated() {
            deck.append(MemoryV3Card(id: index * 2,     symbol: symbol))
            deck.append(MemoryV3Card(id: index * 2 + 1, symbol: symbol))
        }
        memoryV3SeededShuffle(array: &deck, seed: seedInt)
        cards = deck
        firstSelectedIndex = nil
        gameState = .idle
        matches = 0
        moves = 0
        elapsedSeconds = 0
        stopTimer()
    }

    func restart() {
        seedInt += 1
        setupCards()
    }

    func tap(card: MemoryV3Card) {
        guard gameState != .blocked && gameState != .won else { return }
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        guard !cards[index].isFlipped && !cards[index].isMatched else { return }

        if gameState == .idle {
            gameState = .playing
            startTimer()
        }

        moves += 1
        cards[index].isFlipped = true

        if let first = firstSelectedIndex {
            firstSelectedIndex = nil
            if cards[first].symbol == cards[index].symbol {
                cards[first].isMatched = true
                cards[index].isMatched = true
                matches += 1
                if matches == symbols.count {
                    gameState = .won
                    stopTimer()
                } else {
                    gameState = .playing
                }
            } else {
                gameState = .blocked
                let firstId = cards[first].id
                let secondId = cards[index].id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self else { return }
                    if let fi = self.cards.firstIndex(where: { $0.id == firstId }) {
                        self.cards[fi].isFlipped = false
                    }
                    if let si = self.cards.firstIndex(where: { $0.id == secondId }) {
                        self.cards[si].isFlipped = false
                    }
                    self.gameState = .playing
                }
            }
        } else {
            firstSelectedIndex = index
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Neumorphic Card View

struct MemoryV3CardView: View {
    let card: MemoryV3Card

    private var symbolColor: Color {
        memoryV3SymbolColors[card.symbol] ?? Color(red: 0.4, green: 0.4, blue: 0.6)
    }

    var body: some View {
        ZStack {
            cardBack
                .rotation3DEffect(.degrees(card.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(card.isFlipped ? 0 : 1)

            cardFront
                .rotation3DEffect(.degrees(card.isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(card.isFlipped ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: card.isFlipped)
    }

    // Back: neumorphic pressed look (inner shadow)
    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(.systemGray6))
            .overlay(
                // Inner shadow simulation using offset shapes
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.black.opacity(0.08), lineWidth: 2)
                    .blur(radius: 2)
                    .offset(x: 1, y: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.5)
                    .blur(radius: 1)
                    .offset(x: -1, y: -1)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            )
            .shadow(color: Color.white.opacity(0.8), radius: 5, x: -3, y: -3)
            .shadow(color: Color.black.opacity(0.15), radius: 5, x: 3, y: 3)
    }

    // Front: neumorphic raised with muted symbol
    private var cardFront: some View {
        let color = symbolColor
        return ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))

            // Subtle circle behind symbol
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 44, height: 44)

            Image(systemName: card.symbol)
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(color.opacity(card.isMatched ? 1.0 : 0.75))
                .scaleEffect(card.isMatched ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: card.isMatched)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Color.white.opacity(0.85), radius: 5, x: -3, y: -3)
        .shadow(
            color: card.isMatched ? color.opacity(0.3) : Color.black.opacity(0.12),
            radius: card.isMatched ? 8 : 5,
            x: 3, y: 3
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    card.isMatched ? color.opacity(0.25) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Neumorphic HUD Panel

struct MemoryV3HUD: View {
    let matches: Int
    let moves: Int
    let elapsedSeconds: Int
    let seedInt: Int

    var body: some View {
        HStack(spacing: 0) {
            hudItem(icon: "rectangle.grid.2x2", title: "PAIRS", value: "\(matches)/8")
            divider
            hudItem(icon: "hand.tap", title: "MOVES", value: "\(moves)")
            divider
            hudItem(icon: "clock", title: "TIME", value: timeString)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.8), radius: 6, x: -4, y: -4)
                .shadow(color: Color.black.opacity(0.15), radius: 6, x: 4, y: 4)
        )
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1, height: 32)
            .padding(.horizontal, 4)
    }

    private func hudItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color.secondary.opacity(0.7))
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label).opacity(0.8))
        }
        .frame(minWidth: 72)
    }
}

// MARK: - Seed Badge

struct MemoryV3SeedBadge: View {
    let seedInt: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 13))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
            Text("SEED: #\(seedInt)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
                .shadow(color: Color.white.opacity(0.8), radius: 4, x: -2, y: -2)
                .shadow(color: Color.black.opacity(0.12), radius: 4, x: 2, y: 2)
        )
    }
}

// MARK: - Win Overlay V3

struct MemoryV3WinOverlay: View {
    let matches: Int
    let moves: Int
    let elapsedSeconds: Int
    let seedInt: Int
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Well Done!")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.5))

                // Seed display for sharing
                VStack(spacing: 6) {
                    Text("Completed With Seed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("#\(seedInt)")
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.65))
                    Text("Share this seed to replay the same layout!")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .neumorphicCard(radius: 18)

                // Stats
                VStack(spacing: 10) {
                    statRow(icon: "clock.fill", label: "Time", value: timeString)
                    statRow(icon: "hand.tap.fill", label: "Moves", value: "\(moves)")
                    statRow(icon: "checkmark.circle.fill", label: "Pairs", value: "\(matches) / 8")
                }
                .padding(18)
                .neumorphicCard(radius: 18)

                Button(action: onPlayAgain) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Next Seed")
                    }
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.4, green: 0.35, blue: 0.65))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                            .shadow(color: Color.white.opacity(0.8), radius: 6, x: -3, y: -3)
                            .shadow(color: Color.black.opacity(0.18), radius: 6, x: 3, y: 3)
                    )
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.white.opacity(0.85), radius: 12, x: -6, y: -6)
                    .shadow(color: Color.black.opacity(0.2), radius: 12, x: 6, y: 6)
            )
            .padding(.horizontal, 28)
        }
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Color(red: 0.4, green: 0.4, blue: 0.6))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.5))
        }
    }
}

// MARK: - Main View V3

struct MemoryViewV3: View {
    @StateObject private var viewModel = MemoryV3ViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            // Soft neumorphic background
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Title row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory Match")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.28, blue: 0.48))
                        Text("Procedural Generation")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.secondary.opacity(0.7))
                    }
                    Spacer()
                    Button(action: { viewModel.restart() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(red: 0.4, green: 0.38, blue: 0.62))
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .shadow(color: Color.white.opacity(0.8), radius: 4, x: -2, y: -2)
                                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 2, y: 2)
                            )
                    }
                }
                .padding(.horizontal, 20)

                // Seed badge
                MemoryV3SeedBadge(seedInt: viewModel.seedInt)

                // HUD
                MemoryV3HUD(
                    matches: viewModel.matches,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    seedInt: viewModel.seedInt
                )
                .padding(.horizontal, 20)

                // Card grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.cards) { card in
                        MemoryV3CardView(card: card)
                            .aspectRatio(0.75, contentMode: .fit)
                            .onTapGesture {
                                viewModel.tap(card: card)
                            }
                    }
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 0)
            }
            .padding(.top, 16)

            // Win overlay
            if viewModel.gameState == .won {
                MemoryV3WinOverlay(
                    matches: viewModel.matches,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    seedInt: viewModel.seedInt,
                    onPlayAgain: { viewModel.restart() }
                )
                .transition(.opacity)
                .animation(.easeIn(duration: 0.3), value: viewModel.gameState == .won)
            }
        }
    }
}

#Preview {
    MemoryViewV3()
}

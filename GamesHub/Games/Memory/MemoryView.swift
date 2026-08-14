import SwiftUI

// MARK: - Model

struct MemoryCard: Identifiable {
    let id: Int
    let symbol: String
    var isFlipped: Bool = false
    var isMatched: Bool = false
}

enum MemoryDifficulty {
    case easy, medium, hard

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var columns: Int {
        switch self {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var rows: Int {
        switch self {
        case .easy:   return 4
        case .medium: return 4
        case .hard:   return 4
        }
    }

    var pairCount: Int {
        return columns * rows / 2
    }
}

enum MemoryGameState {
    case idle, playing, blocked, won
}

// MARK: - ViewModel

class MemoryViewModel: ObservableObject {
    private let allSymbols = [
        "heart.fill", "star.fill", "moon.fill", "sun.max.fill",
        "bolt.fill", "flame.fill", "drop.fill", "leaf.fill",
        "cloud.fill", "snowflake", "wind", "tornado",
        "ant.fill", "bird.fill", "fish.fill", "pawprint.fill",
        "crown.fill", "diamond.fill", "triangle.fill", "seal.fill"
    ]

    @Published var cards: [MemoryCard] = []
    @Published var gameState: MemoryGameState = .idle
    @Published var matches: Int = 0
    @Published var moves: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var roundTimes: [Int] = []
    @Published var difficulty: MemoryDifficulty = .medium

    private var firstSelectedIndex: Int? = nil
    private var timer: Timer? = nil

    init() {
        setupCards()
    }

    private func computeDifficulty() -> MemoryDifficulty {
        let recentTimes = roundTimes.suffix(5)
        guard !recentTimes.isEmpty else { return .medium }
        let avg = recentTimes.reduce(0, +) / recentTimes.count
        if avg < 30 {
            return .hard
        } else if avg > 60 {
            return .easy
        } else {
            return .medium
        }
    }

    func setupCards() {
        let diff = computeDifficulty()
        difficulty = diff
        let pairCount = diff.pairCount
        let symbols = Array(allSymbols.shuffled().prefix(pairCount))
        var deck: [MemoryCard] = []
        for (index, symbol) in symbols.enumerated() {
            deck.append(MemoryCard(id: index * 2,     symbol: symbol))
            deck.append(MemoryCard(id: index * 2 + 1, symbol: symbol))
        }
        deck.shuffle()
        cards = deck
        firstSelectedIndex = nil
        gameState = .idle
        matches = 0
        moves = 0
        elapsedSeconds = 0
        stopTimer()
    }

    func restart() {
        setupCards()
    }

    func tap(card: MemoryCard) {
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
                if matches == difficulty.pairCount {
                    gameState = .won
                    stopTimer()
                    roundTimes.append(elapsedSeconds)
                    if roundTimes.count > 5 {
                        roundTimes.removeFirst()
                    }
                } else {
                    gameState = .playing
                }
            } else {
                gameState = .blocked
                let firstId = cards[first].id
                let secondId = cards[index].id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    guard let self = self else { return }
                    // Skip if a restart replaced the deck while blocked
                    guard self.gameState == .blocked else { return }
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

// MARK: - Symbol Colors

private let memorySymbolColors: [String: Color] = [
    "heart.fill":    Color(red: 1.0, green: 0.2, blue: 0.3),
    "star.fill":     Color(red: 1.0, green: 0.8, blue: 0.0),
    "moon.fill":     Color(red: 0.5, green: 0.4, blue: 1.0),
    "sun.max.fill":  Color(red: 1.0, green: 0.6, blue: 0.0),
    "bolt.fill":     Color(red: 0.0, green: 0.8, blue: 1.0),
    "flame.fill":    Color(red: 1.0, green: 0.4, blue: 0.1),
    "drop.fill":     Color(red: 0.1, green: 0.5, blue: 1.0),
    "leaf.fill":     Color(red: 0.1, green: 0.8, blue: 0.3),
    "cloud.fill":    Color(red: 0.6, green: 0.7, blue: 0.9),
    "snowflake":     Color(red: 0.5, green: 0.9, blue: 1.0),
    "wind":          Color(red: 0.4, green: 0.8, blue: 0.7),
    "tornado":       Color(red: 0.7, green: 0.5, blue: 0.9),
    "ant.fill":      Color(red: 0.8, green: 0.3, blue: 0.2),
    "bird.fill":     Color(red: 0.3, green: 0.6, blue: 0.9),
    "fish.fill":     Color(red: 0.0, green: 0.7, blue: 0.8),
    "pawprint.fill": Color(red: 0.8, green: 0.5, blue: 0.3),
    "crown.fill":    Color(red: 0.9, green: 0.7, blue: 0.1),
    "diamond.fill":  Color(red: 0.4, green: 0.9, blue: 0.9),
    "triangle.fill": Color(red: 1.0, green: 0.4, blue: 0.6),
    "seal.fill":     Color(red: 0.6, green: 0.4, blue: 1.0)
]

// MARK: - Card View

struct MemoryCardView: View {
    let card: MemoryCard

    private var symbolColor: Color {
        memorySymbolColors[card.symbol] ?? .purple
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

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
    }

    private var cardFront: some View {
        let color = symbolColor
        return RoundedRectangle(cornerRadius: 14)
            .fill(.ultraThinMaterial)
            .overlay(
                ZStack {
                    // Glow background for matched cards
                    if card.isMatched {
                        Circle()
                            .fill(color.opacity(0.3))
                            .blur(radius: 12)
                            .scaleEffect(1.2)
                    }
                    Image(systemName: card.symbol)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(card.isMatched ? 1.15 : 1.0)
                        .animation(
                            .spring(response: 0.35, dampingFraction: 0.45),
                            value: card.isMatched
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: card.isMatched
                                ? [color.opacity(0.8), color.opacity(0.4)]
                                : [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: card.isMatched ? 2 : 1
                    )
            )
            .shadow(
                color: card.isMatched ? color.opacity(0.6) : Color.black.opacity(0.1),
                radius: card.isMatched ? 12 : 4,
                x: 0, y: card.isMatched ? 6 : 2
            )
    }
}

// MARK: - Frosted HUD

struct MemoryHUD: View {
    let matches: Int
    let totalPairs: Int
    let moves: Int
    let elapsedSeconds: Int
    let difficulty: MemoryDifficulty

    var body: some View {
        HStack(spacing: 0) {
            hudItem(title: "PAIRS", value: "\(matches)/\(totalPairs)")
            divider
            hudItem(title: "MOVES", value: "\(moves)")
            divider
            hudItem(title: "TIME", value: timeString)
            divider
            difficultyBadge
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1, height: 32)
            .padding(.horizontal, 4)
    }

    private func hudItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 60)
    }

    private var difficultyBadge: some View {
        VStack(spacing: 2) {
            Text("LEVEL")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)
            Text(difficulty.label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(difficulty.color)
        }
        .frame(minWidth: 60)
    }
}

// MARK: - Win Overlay

struct MemoryWinOverlay: View {
    let matches: Int
    let totalPairs: Int
    let moves: Int
    let elapsedSeconds: Int
    let difficulty: MemoryDifficulty
    let roundTimes: [Int]
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .blur(radius: 2)

            VStack(spacing: 28) {
                Text("Brilliant!")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                VStack(spacing: 12) {
                    statRow(icon: "clock.fill", label: "Time", value: timeString, color: .cyan)
                    statRow(icon: "hand.tap.fill", label: "Moves", value: "\(moves)", color: .purple)
                    statRow(icon: "rectangle.grid.2x2.fill", label: "Pairs", value: "\(matches) / \(totalPairs)", color: .green)
                    statRow(icon: "chart.bar.fill", label: "Difficulty", value: difficulty.label, color: difficulty.color)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.4), lineWidth: 1)
                        )
                )

                if !roundTimes.isEmpty {
                    let recentTimes = Array(roundTimes.suffix(5))
                    VStack(spacing: 4) {
                        Text("Recent Round Times")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        HStack(spacing: 8) {
                            ForEach(Array(recentTimes.enumerated()), id: \.offset) { _, t in
                                Text(formatTime(t))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.85))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.white.opacity(0.15)))
                            }
                        }
                    }
                }

                Button(action: onPlayAgain) {
                    Text("Next Round")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.4, green: 0.2, blue: 1.0),
                                                 Color(red: 0.8, green: 0.2, blue: 0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color.purple.opacity(0.5), radius: 12, x: 0, y: 6)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 24)
        }
    }

    private var timeString: String { formatTime(elapsedSeconds) }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func statRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            Text(label)
                .foregroundColor(.secondary)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .font(.system(size: 15, weight: .bold))
        }
    }
}

// MARK: - Main View

struct MemoryView: View {
    @StateObject private var viewModel = MemoryViewModel()

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: viewModel.difficulty.columns)
    }

    var body: some View {
        ZStack {
            // Vibrant background
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.12, green: 0.05, blue: 0.25)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative blobs
            GeometryReader { geo in
                Circle()
                    .fill(Color.purple.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -80, y: 50)
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 250, height: 250)
                    .blur(radius: 50)
                    .offset(x: geo.size.width - 100, y: geo.size.height - 200)
            }
            .ignoresSafeArea()

            VStack(spacing: 16) {
                // Title
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory Match")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("Adaptive Difficulty")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Button(action: { viewModel.restart() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(10)
                            .background(Circle().fill(Color.white.opacity(0.15)))
                    }
                }
                .padding(.horizontal, 20)

                // Frosted HUD
                MemoryHUD(
                    matches: viewModel.matches,
                    totalPairs: viewModel.difficulty.pairCount,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    difficulty: viewModel.difficulty
                )
                .padding(.horizontal, 20)

                // Card grid
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(viewModel.cards) { card in
                        MemoryCardView(card: card)
                            .aspectRatio(0.72, contentMode: .fit)
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
                MemoryWinOverlay(
                    matches: viewModel.matches,
                    totalPairs: viewModel.difficulty.pairCount,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    difficulty: viewModel.difficulty,
                    roundTimes: viewModel.roundTimes,
                    onPlayAgain: { viewModel.restart() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.gameState == .won)
            }
        }
    }
}

#Preview {
    MemoryView()
}

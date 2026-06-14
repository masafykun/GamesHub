import SwiftUI

// MARK: - Model

struct MemoryCard: Identifiable {
    let id: Int
    let symbol: String
    var isFlipped: Bool = false
    var isMatched: Bool = false
}

enum MemoryGameState {
    case idle
    case playing
    case blocked
    case won
}

// MARK: - ViewModel

class MemoryViewModel: ObservableObject {
    private let symbols = ["heart.fill", "star.fill", "moon.fill", "sun.max.fill",
                           "bolt.fill", "flame.fill", "drop.fill", "leaf.fill"]

    @Published var cards: [MemoryCard] = []
    @Published var gameState: MemoryGameState = .idle
    @Published var matches: Int = 0
    @Published var moves: Int = 0
    @Published var elapsedSeconds: Int = 0

    private var firstSelectedIndex: Int? = nil
    private var timer: Timer? = nil

    init() {
        setupCards()
    }

    private func setupCards() {
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
            // Second card tapped
            firstSelectedIndex = nil
            if cards[first].symbol == cards[index].symbol {
                // Match
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
                // No match — block input and flip back after delay
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

// MARK: - Card View

struct MemoryCardView: View {
    let card: MemoryCard
    let onTap: () -> Void

    private let symbolColors: [String: Color] = [
        "heart.fill":    .red,
        "star.fill":     .yellow,
        "moon.fill":     .indigo,
        "sun.max.fill":  .orange,
        "bolt.fill":     .cyan,
        "flame.fill":    .orange,
        "drop.fill":     .blue,
        "leaf.fill":     .green
    ]

    var body: some View {
        ZStack {
            // Card back
            cardBack
                .rotation3DEffect(.degrees(card.isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(card.isFlipped ? 0 : 1)

            // Card front
            cardFront
                .rotation3DEffect(.degrees(card.isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                .opacity(card.isFlipped ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.4), value: card.isFlipped)
        .onTapGesture {
            onTap()
        }
    }

    private var cardBack: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.3, green: 0.4, blue: 0.8),
                             Color(red: 0.5, green: 0.2, blue: 0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
    }

    private var cardFront: some View {
        let color = symbolColors[card.symbol] ?? .purple
        return RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .overlay(
                VStack {
                    Image(systemName: card.symbol)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(color)
                        .scaleEffect(card.isMatched ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: card.isMatched)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(card.isMatched ? color.opacity(0.6) : Color.gray.opacity(0.2), lineWidth: card.isMatched ? 2.5 : 1)
            )
            .shadow(color: card.isMatched ? color.opacity(0.4) : .black.opacity(0.1),
                    radius: card.isMatched ? 8 : 3,
                    x: 0, y: 2)
    }
}

// MARK: - HUD

struct MemoryHUD: View {
    let matches: Int
    let moves: Int
    let elapsedSeconds: Int

    var body: some View {
        HStack(spacing: 24) {
            hudItem(title: "PAIRS", value: "\(matches)/8")
            Divider().frame(height: 36)
            hudItem(title: "MOVES", value: "\(moves)")
            Divider().frame(height: 36)
            hudItem(title: "TIME", value: timeString)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func hudItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Win Overlay

struct MemoryWinOverlay: View {
    let matches: Int
    let moves: Int
    let elapsedSeconds: Int
    let onPlayAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("You Win!")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    winStat(label: "Time", value: timeString)
                    winStat(label: "Moves", value: "\(moves)")
                    winStat(label: "Pairs", value: "\(matches) / 8")
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.15))
                )

                Button(action: onPlayAgain) {
                    Text("Play Again")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color.purple, Color.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .purple.opacity(0.5), radius: 10, x: 0, y: 5)
                }
            }
            .padding(32)
        }
    }

    private var timeString: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private func winStat(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .bold))
        }
    }
}

// MARK: - Main View

struct MemoryView: View {
    @StateObject private var viewModel = MemoryViewModel()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.93, blue: 1.0),
                         Color(red: 0.85, green: 0.90, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("Memory Match")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.6))

                // HUD
                MemoryHUD(
                    matches: viewModel.matches,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds
                )

                // Card Grid
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(viewModel.cards) { card in
                        MemoryCardView(card: card) {
                            viewModel.tap(card: card)
                        }
                        .aspectRatio(0.75, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 16)

                // Restart button
                Button(action: { viewModel.restart() }) {
                    Label("Restart", systemImage: "arrow.clockwise")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.2, blue: 0.6))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .stroke(Color(red: 0.3, green: 0.2, blue: 0.6).opacity(0.5), lineWidth: 1.5)
                        )
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 16)

            // Win overlay
            if viewModel.gameState == .won {
                MemoryWinOverlay(
                    matches: viewModel.matches,
                    moves: viewModel.moves,
                    elapsedSeconds: viewModel.elapsedSeconds,
                    onPlayAgain: { viewModel.restart() }
                )
                .transition(.opacity)
                .animation(.easeIn(duration: 0.3), value: viewModel.gameState == .won)
            }
        }
    }
}

#Preview {
    MemoryView()
}

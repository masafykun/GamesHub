import SwiftUI

// MARK: - Models

enum PrmFGamePhase {
    case start, playing, gameOver
}

struct PrmFCell: Identifiable {
    let id = UUID()
    let number: Int
    var state: PrmFCellState = .neutral
}

enum PrmFCellState {
    case neutral, correct, wrong
}

// MARK: - Helpers

private func isPrime(_ n: Int) -> Bool {
    guard n >= 2 else { return false }
    if n == 2 { return true }
    if n % 2 == 0 { return false }
    var i = 3
    while i * i <= n { if n % i == 0 { return false }; i += 2 }
    return true
}

// MARK: - View

struct PrimeFinderView: View {
    @State private var phase: PrmFGamePhase = .start
    @State private var cells: [PrmFCell] = []
    @State private var timeLeft: Double = 60
    @State private var score: Int = 0
    @State private var timer: Timer? = nil
    @State private var wrongFlashIDs: Set<UUID> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private var primesRemaining: Int {
        cells.filter { isPrime($0.number) && $0.state != .correct }.count
    }

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

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Prime Finder").font(.largeTitle).bold()
            Text("Tap all the prime numbers in the grid!\nWrong tap = -5 seconds.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.blue).cornerRadius(14)
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Label("\(score)", systemImage: "star.fill").foregroundColor(.yellow).font(.headline)
                Spacer()
                Text("Primes left: \(primesRemaining)").foregroundStyle(.secondary).font(.subheadline)
                Spacer()
                Label(String(format: "%.0f", timeLeft), systemImage: "clock").foregroundColor(timeLeft < 10 ? .red : .primary).font(.headline)
            }.padding(.horizontal)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cells) { cell in
                    cellView(cell)
                        .onTapGesture { handleTap(cell) }
                }
            }.padding(.horizontal)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Time's Up!").font(.largeTitle).bold()
            Text("Primes Found").foregroundStyle(.secondary)
            Text("\(score)").font(.system(size: 72, weight: .bold)).foregroundColor(.blue)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.blue).cornerRadius(14)
            }
        }
    }

    // MARK: Cell

    @ViewBuilder
    func cellView(_ cell: PrmFCell) -> some View {
        let bg: Color = cell.state == .correct ? .green : (wrongFlashIDs.contains(cell.id) ? .red : Color(.secondarySystemBackground))
        Text("\(cell.number)")
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .background(bg)
            .cornerRadius(8)
            .foregroundColor(cell.state == .correct ? .white : .primary)
            .opacity(cell.state == .correct ? 0.7 : 1)
    }

    // MARK: Logic

    func startGame() {
        timer?.invalidate()
        var pool = Array(1...50).shuffled()
        let chosen = Array(pool.prefix(36))
        cells = chosen.map { PrmFCell(number: $0) }
        score = 0
        timeLeft = 60
        wrongFlashIDs = []
        phase = .playing
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeLeft -= 0.1
            if timeLeft <= 0 {
                timeLeft = 0
                endGame()
            }
        }
    }

    func handleTap(_ cell: PrmFCell) {
        guard phase == .playing else { return }
        guard let idx = cells.firstIndex(where: { $0.id == cell.id }) else { return }
        guard cells[idx].state == .neutral else { return }

        if isPrime(cell.number) {
            cells[idx].state = .correct
            score += 1
            if primesRemaining == 0 { endGame() }
        } else {
            cells[idx].state = .wrong
            wrongFlashIDs.insert(cell.id)
            timeLeft = max(0, timeLeft - 5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                wrongFlashIDs.remove(cell.id)
            }
        }
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        phase = .gameOver
    }
}

#Preview { PrimeFinderView() }

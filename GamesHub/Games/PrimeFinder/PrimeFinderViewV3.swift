import SwiftUI

// MARK: - LCG

struct PrmFLCG {
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

enum PrmFV3Phase {
    case start, playing, gameOver
}

struct PrmFV3Cell: Identifiable {
    let id = UUID()
    let number: Int
    var state: PrmFV3CellState = .neutral
}

enum PrmFV3CellState {
    case neutral, correct, wrong
}

// MARK: - Helpers

private func isPrimeV3(_ n: Int) -> Bool {
    guard n >= 2 else { return false }
    if n == 2 { return true }
    if n % 2 == 0 { return false }
    var i = 3
    while i * i <= n { if n % i == 0 { return false }; i += 2 }
    return true
}

private func lcgShuffle<T>(_ array: [T], using lcg: inout PrmFLCG) -> [T] {
    var arr = array
    for i in stride(from: arr.count - 1, through: 1, by: -1) {
        let j = lcg.nextInt(i + 1)
        arr.swapAt(i, j)
    }
    return arr
}

// MARK: - View

struct PrimeFinderViewV3: View {
    @State private var phase: PrmFV3Phase = .start
    @State private var cells: [PrmFV3Cell] = []
    @State private var timeLeft: Double = 60
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var wrongFlashIDs: Set<UUID> = []
    @State private var seedInt: Int = 1

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    private var primesRemaining: Int {
        cells.filter { isPrimeV3($0.number) && $0.state != .correct }.count
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
        VStack(spacing: 28) {
            Text("Prime Finder").font(.largeTitle).bold()
            Text("Tap all the prime numbers!\nMistakes cost 5 seconds.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)

            Button(action: startGame) {
                Text("Start Game").font(.headline).foregroundColor(.primary)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            // Stats panel
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2).foregroundStyle(.secondary)
                    Text("\(score)").font(.title2).bold()
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("LEFT").font(.caption2).foregroundStyle(.secondary)
                    Text("\(primesRemaining)").font(.title2).bold()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME").font(.caption2).foregroundStyle(.secondary)
                    Text(String(format: "%.0f", timeLeft))
                        .font(.title2).bold()
                        .foregroundColor(timeLeft < 10 ? .red : .primary)
                }
            }
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            // Seed label
            Text("SEED: #\(seedInt)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)

            // Grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(cells) { cell in
                    neuCell(cell)
                        .onTapGesture { handleTap(cell) }
                }
            }.padding(.horizontal)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("Time's Up!").font(.largeTitle).bold()
            VStack(spacing: 8) {
                Text("Primes Found").foregroundStyle(.secondary)
                Text("\(score)").font(.system(size: 72, weight: .bold)).foregroundColor(.blue)
            }
            .padding(32)
            .neumorphicCard(radius: 24)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.tertiary)

            Button(action: startGame) {
                Text("Play Again").font(.headline).foregroundColor(.primary)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 14)
            }
        }.padding()
    }

    // MARK: Cell

    @ViewBuilder
    func neuCell(_ cell: PrmFV3Cell) -> some View {
        let isWrong = wrongFlashIDs.contains(cell.id)
        ZStack {
            if cell.state == .correct {
                RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.25))
            } else if isWrong {
                RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.25))
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray6))
            }
            Text("\(cell.number)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(cell.state == .correct ? .green : (isWrong ? .red : .primary))
        }
        .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        .neumorphicCard(radius: 8)
        .opacity(cell.state == .correct ? 0.65 : 1)
    }

    // MARK: Logic

    func startGame() {
        gameTimer?.invalidate()
        var lcg = PrmFLCG(seed: seedInt)
        let pool = Array(1...50)
        let shuffled = lcgShuffle(pool, using: &lcg)
        let chosen = Array(shuffled.prefix(36))
        cells = lcgShuffle(chosen, using: &lcg).map { PrmFV3Cell(number: $0) }
        score = 0
        timeLeft = 60
        wrongFlashIDs = []
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeLeft -= 0.1
            if timeLeft <= 0 {
                timeLeft = 0
                endGame()
            }
        }
    }

    func handleTap(_ cell: PrmFV3Cell) {
        guard phase == .playing else { return }
        guard let idx = cells.firstIndex(where: { $0.id == cell.id }) else { return }
        guard cells[idx].state == .neutral else { return }

        if isPrimeV3(cell.number) {
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
        gameTimer?.invalidate()
        gameTimer = nil
        seedInt += 1
        phase = .gameOver
    }
}

#Preview { PrimeFinderViewV3() }

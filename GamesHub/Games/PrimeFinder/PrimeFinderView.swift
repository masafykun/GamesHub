import SwiftUI

// MARK: - Models

enum PrimeFinderPhase {
    case start, playing, gameOver
}

struct PrimeFinderCell: Identifiable {
    let id = UUID()
    let number: Int
    var state: PrimeFinderCellState = .neutral
}

enum PrimeFinderCellState {
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
    @State private var phase: PrimeFinderPhase = .start
    @State private var cells: [PrimeFinderCell] = []
    @State private var timeLeft: Double = 60
    @State private var timerDuration: Double = 60
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var wrongFlashIDs: Set<UUID> = []
    @State private var recentResults: [Bool] = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    private var primesRemaining: Int {
        cells.filter { isPrime($0.number) && $0.state != .correct }.count
    }

    private var timerPct: Double {
        timeLeft / timerDuration
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.18, green: 0.14, blue: 0.46), Color(red: 0.55, green: 0.18, blue: 0.62)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Prime Finder").font(.largeTitle).bold().foregroundColor(.white)
            Text("Tap all prime numbers!\nWrong tap costs 5 seconds.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.75))
            if !recentResults.isEmpty {
                let wins = recentResults.suffix(5).filter { $0 }.count
                let dur = adjustedDuration()
                VStack(spacing: 4) {
                    Text("Difficulty: \(difficultyLabel(dur))")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("Last 5 rounds: \(wins)/5 perfect")
                        .font(.caption2).foregroundColor(.white.opacity(0.4))
                }
            }
            Button(action: startGame) {
                Text("Start Game").font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2).foregroundColor(.white.opacity(0.5))
                    Text("\(score)").font(.title2).bold().foregroundColor(.yellow)
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("PRIMES LEFT").font(.caption2).foregroundColor(.white.opacity(0.5))
                    Text("\(primesRemaining)").font(.title2).bold().foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME").font(.caption2).foregroundColor(.white.opacity(0.5))
                    Text(String(format: "%.0f", timeLeft))
                        .font(.title2).bold()
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                }
            }
            .padding(.horizontal)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Timer bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.15)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(timerPct > 0.4 ? Color.green : (timerPct > 0.2 ? Color.orange : Color.red))
                        .frame(width: geo.size.width * max(0, timerPct), height: 6)
                        .animation(.linear(duration: 0.1), value: timerPct)
                }
            }.frame(height: 6).padding(.horizontal)

            // Grid
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cells) { cell in
                    glassCell(cell)
                        .onTapGesture { handleTap(cell) }
                }
            }.padding(.horizontal)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("Time's Up!").font(.largeTitle).bold().foregroundColor(.white)
            VStack(spacing: 8) {
                Text("Primes Found").foregroundColor(.white.opacity(0.7))
                Text("\(score)").font(.system(size: 72, weight: .bold)).foregroundColor(.yellow)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))

            Button(action: startGame) {
                Text("Play Again").font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }.padding()
    }

    // MARK: Cell

    @ViewBuilder
    func glassCell(_ cell: PrimeFinderCell) -> some View {
        let isWrong = wrongFlashIDs.contains(cell.id)
        let bg: AnyShapeStyle = cell.state == .correct
            ? AnyShapeStyle(Color.green.opacity(0.6))
            : (isWrong ? AnyShapeStyle(Color.red.opacity(0.6)) : AnyShapeStyle(.ultraThinMaterial))
        Text("\(cell.number)")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(cell.state == .correct ? .white : (isWrong ? .white : .white.opacity(0.85)))
            .frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.25), lineWidth: 1))
    }

    // MARK: Difficulty

    func adjustedDuration() -> Double {
        let last5 = recentResults.suffix(5)
        let wins = last5.filter { $0 }.count
        if last5.count == 5 && wins > 4 {
            return max(30, timerDuration * 0.8)
        }
        return timerDuration
    }

    func difficultyLabel(_ dur: Double) -> String {
        switch dur {
        case ..<35: return "Hard"
        case ..<50: return "Medium"
        default: return "Normal"
        }
    }

    // MARK: Logic

    func startGame() {
        gameTimer?.invalidate()
        let newDuration = adjustedDuration()
        timerDuration = newDuration
        let chosen = Array(Array(1...50).shuffled().prefix(36))
        cells = chosen.map { PrimeFinderCell(number: $0) }
        score = 0
        timeLeft = newDuration
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

    func handleTap(_ cell: PrimeFinderCell) {
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
        gameTimer?.invalidate()
        gameTimer = nil
        let totalPrimes = cells.filter { isPrime($0.number) }.count
        let perfect = score == totalPrimes
        recentResults.append(perfect)
        if recentResults.count > 10 { recentResults.removeFirst() }
        phase = .gameOver
    }
}

#Preview { PrimeFinderView() }

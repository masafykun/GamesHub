import SwiftUI

// MARK: - Difficulty

enum SlidingPuzzleDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var gridSize: Int {
        switch self {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var shuffleMoves: Int {
        switch self {
        case .easy:   return 100
        case .medium: return 300
        case .hard:   return 500
        }
    }

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

// MARK: - Game Logic

final class SlidingPuzzleGame: ObservableObject {
    @Published var tiles: [Int] = []
    @Published var moves: Int = 0
    @Published var isWon: Bool = false
    @Published var elapsed: TimeInterval = 0
    @Published var gridSize: Int = 4

    private var timer: Timer?
    private var startTime: Date?
    private var timerStarted = false

    var timeString: String {
        let total = Int(elapsed)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var emptyIndex: Int {
        tiles.firstIndex(of: 0) ?? (tiles.count - 1)
    }

    /// Shuffling by legal moves guarantees the board is always solvable.
    func newGame(difficulty: SlidingPuzzleDifficulty) {
        stopTimer()
        isWon = false
        moves = 0
        elapsed = 0
        timerStarted = false
        gridSize = difficulty.gridSize

        let tileCount = gridSize * gridSize
        tiles = Array(1..<tileCount) + [0]

        var lastEmpty = -1
        var empty = tileCount - 1

        for _ in 0..<difficulty.shuffleMoves {
            let neighbors = validNeighbors(for: empty)
            let candidates = neighbors.filter { $0 != lastEmpty }
            guard let chosen = candidates.randomElement() ?? neighbors.randomElement() else { break }
            tiles.swapAt(empty, chosen)
            lastEmpty = empty
            empty = chosen
        }

        // A shuffle that happens to land solved would be a strange start.
        if tiles == Array(1..<tileCount) + [0], tileCount > 1 {
            tiles.swapAt(0, 1)
        }
    }

    func tap(index: Int) {
        guard !isWon else { return }
        let empty = emptyIndex
        guard isAdjacent(index, empty) else { return }

        if !timerStarted {
            startTimer()
            timerStarted = true
        }

        tiles.swapAt(index, empty)
        moves += 1
        checkWin()
    }

    func isAdjacent(_ a: Int, _ b: Int) -> Bool {
        let ar = a / gridSize, ac = a % gridSize
        let br = b / gridSize, bc = b % gridSize
        return (ar == br && abs(ac - bc) == 1) || (ac == bc && abs(ar - br) == 1)
    }

    private func validNeighbors(for index: Int) -> [Int] {
        let row = index / gridSize
        let col = index % gridSize
        var result: [Int] = []
        if row > 0            { result.append(index - gridSize) }
        if row < gridSize - 1 { result.append(index + gridSize) }
        if col > 0            { result.append(index - 1) }
        if col < gridSize - 1 { result.append(index + 1) }
        return result
    }

    private func checkWin() {
        let tileCount = gridSize * gridSize
        if tiles == Array(1..<tileCount) + [0] {
            isWon = true
            stopTimer()
        }
    }

    private func startTimer() {
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.startTime else { return }
            self.elapsed = Date().timeIntervalSince(start)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit { stopTimer() }
}

// MARK: - Main View

struct SlidingPuzzleView: View {
    @StateObject private var game = SlidingPuzzleGame()

    @State private var roundScores: [Int] = []
    @State private var currentDifficulty: SlidingPuzzleDifficulty = .medium
    @State private var showWin = false
    @State private var pendingScore: Int = 0

    @AppStorage("slidingPuzzleBest3") private var best3: Int = 0
    @AppStorage("slidingPuzzleBest4") private var best4: Int = 0
    @AppStorage("slidingPuzzleBest5") private var best5: Int = 0

    private var bestForCurrentGrid: Int {
        switch currentDifficulty {
        case .easy: return best3
        case .medium: return best4
        case .hard: return best5
        }
    }

    private var bgGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.08, green: 0.08, blue: 0.18), Color(red: 0.14, green: 0.10, blue: 0.28)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()

            Circle()
                .fill(Color.purple.opacity(0.3))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: -100, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 200, height: 200)
                .blur(radius: 50)
                .offset(x: 120, y: 250)

            VStack(spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sliding Puzzle")
                            .font(.title.bold())
                            .foregroundColor(.white)
                        Text(bestForCurrentGrid > 0
                             ? "Best \(game.gridSize)×\(game.gridSize): \(bestForCurrentGrid) moves"
                             : "Slide the tiles back into order")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    SlidingPuzzleDifficultyBadge(difficulty: currentDifficulty)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 14) {
                    SlidingPuzzleStatCard(label: "MOVES", value: "\(game.moves)")
                    SlidingPuzzleStatCard(label: "TIME",  value: game.timeString)
                    SlidingPuzzleStatCard(label: "GRID",  value: "\(game.gridSize)×\(game.gridSize)")
                }

                if !roundScores.isEmpty {
                    SlidingPuzzleAverageBar(scores: roundScores)
                }

                SlidingPuzzleBoardView(game: game)

                Button(action: startNewGame) {
                    Text("New Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            }
            .padding()

            if showWin {
                SlidingPuzzleWinOverlay(
                    moves: pendingScore,
                    time: game.timeString,
                    difficulty: currentDifficulty,
                    scores: roundScores,
                    best: bestForCurrentGrid
                ) {
                    startNewGame()
                }
            }
        }
        .onAppear {
            if game.tiles.isEmpty { startNewGame() }
        }
        .onDisappear { game.stopTimer() }
        .onChange(of: game.isWon) { _, won in
            if won { handleWin() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Helpers

    private func startNewGame() {
        showWin = false
        game.newGame(difficulty: currentDifficulty)
    }

    private func handleWin() {
        pendingScore = game.moves
        recordBest(moves: game.moves)
        roundScores.append(game.moves)
        if roundScores.count > 5 { roundScores.removeFirst() }
        adjustDifficulty()
        showWin = true
    }

    private func recordBest(moves: Int) {
        switch currentDifficulty {
        case .easy:   if best3 == 0 || moves < best3 { best3 = moves }
        case .medium: if best4 == 0 || moves < best4 { best4 = moves }
        case .hard:   if best5 == 0 || moves < best5 { best5 = moves }
        }
    }

    /// Efficient solves grow the grid; long grinds shrink it.
    private func adjustDifficulty() {
        guard roundScores.count >= 2 else { return }
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        let grid = currentDifficulty.gridSize
        let lowThreshold  = Double(grid * grid) * 2.5
        let highThreshold = Double(grid * grid) * 8.0

        if avg < lowThreshold {
            switch currentDifficulty {
            case .easy:   currentDifficulty = .medium
            case .medium: currentDifficulty = .hard
            case .hard:   break
            }
            roundScores.removeAll()
        } else if avg > highThreshold {
            switch currentDifficulty {
            case .hard:   currentDifficulty = .medium
            case .medium: currentDifficulty = .easy
            case .easy:   break
            }
            roundScores.removeAll()
        }
    }
}

// MARK: - Difficulty Badge

struct SlidingPuzzleDifficultyBadge: View {
    let difficulty: SlidingPuzzleDifficulty

    var body: some View {
        Text(difficulty.rawValue)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(difficulty.badgeColor.opacity(0.7))
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
            )
    }
}

// MARK: - Stat Card

struct SlidingPuzzleStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.title3.bold())
                .foregroundColor(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.2), lineWidth: 1))
        )
    }
}

// MARK: - Average Bar

struct SlidingPuzzleAverageBar: View {
    let scores: [Int]

    private var average: Double {
        Double(scores.reduce(0, +)) / Double(scores.count)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("Recent avg:")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(String(format: "%.1f moves", average))
                .font(.caption.bold())
                .foregroundColor(.white)
            Spacer()
            ForEach(0..<5, id: \.self) { i in
                Circle()
                    .fill(i < scores.count ? Color.white.opacity(0.85) : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }
}

// MARK: - Board

struct SlidingPuzzleBoardView: View {
    @ObservedObject var game: SlidingPuzzleGame

    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let n = game.gridSize
            let totalSize = min(geo.size.width, geo.size.height)
            let cellSize = (totalSize - spacing * CGFloat(n + 1)) / CGFloat(n)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
                    .shadow(color: Color.black.opacity(0.4), radius: 20, x: 0, y: 10)

                VStack(spacing: spacing) {
                    ForEach(0..<n, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<n, id: \.self) { col in
                                let index = row * n + col
                                let value = index < game.tiles.count ? game.tiles[index] : 0
                                SlidingPuzzleTileView(
                                    value: value,
                                    cellSize: cellSize,
                                    totalTiles: n * n,
                                    isCorrect: value != 0 && value == index + 1
                                )
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        game.tap(index: index)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(spacing)
            }
            .frame(width: totalSize, height: totalSize)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 4)
    }
}

struct SlidingPuzzleTileView: View {
    let value: Int
    let cellSize: CGFloat
    let totalTiles: Int
    let isCorrect: Bool

    var body: some View {
        ZStack {
            if value == 0 {
                RoundedRectangle(cornerRadius: tileRadius)
                    .fill(Color.black.opacity(0.3))
                    .frame(width: cellSize, height: cellSize)
                    .overlay(RoundedRectangle(cornerRadius: tileRadius).stroke(Color.white.opacity(0.05), lineWidth: 1))
            } else {
                RoundedRectangle(cornerRadius: tileRadius)
                    .fill(tileGradient)
                    .frame(width: cellSize, height: cellSize)
                    .overlay(
                        RoundedRectangle(cornerRadius: tileRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: tileBaseColor.opacity(0.5), radius: 4, x: 0, y: 3)

                Text("\(value)")
                    .font(.system(size: cellSize * 0.38, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: value)
    }

    private var tileRadius: CGFloat { max(6, cellSize * 0.18) }

    private var tileBaseColor: Color {
        if isCorrect { return Color(red: 0.2, green: 0.8, blue: 0.4) }
        let hue = Double(value - 1) / Double(max(totalTiles - 1, 1))
        return Color(hue: 0.55 + hue * 0.35, saturation: 0.75, brightness: 0.80)
    }

    private var tileGradient: LinearGradient {
        LinearGradient(
            colors: [tileBaseColor.opacity(0.95), tileBaseColor.opacity(0.65)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Win Overlay

struct SlidingPuzzleWinOverlay: View {
    let moves: Int
    let time: String
    let difficulty: SlidingPuzzleDifficulty
    let scores: [Int]
    let best: Int
    let onNewGame: () -> Void

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    private var average: Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 22) {
                Text("Solved!")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                SlidingPuzzleDifficultyBadge(difficulty: difficulty)

                VStack(spacing: 12) {
                    SlidingPuzzleWinStatRow(label: "Moves", value: "\(moves)")
                    Divider().background(Color.white.opacity(0.3))
                    SlidingPuzzleWinStatRow(label: "Time",  value: time)
                    if best > 0 {
                        Divider().background(Color.white.opacity(0.3))
                        SlidingPuzzleWinStatRow(label: "Best", value: "\(best)")
                    }
                    if scores.count >= 2 {
                        Divider().background(Color.white.opacity(0.3))
                        SlidingPuzzleWinStatRow(label: "Recent avg", value: String(format: "%.1f", average))
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.regularMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.3), lineWidth: 1))
                )

                Button(action: onNewGame) {
                    Text("Next Game")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 50)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.85), Color.purple.opacity(0.85)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.4), lineWidth: 1))
                        )
                        .shadow(color: Color.blue.opacity(0.5), radius: 10, x: 0, y: 5)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.25), lineWidth: 1.5))
            )
            .padding(.horizontal, 30)
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                    scale = 1.0
                    opacity = 1.0
                }
            }
        }
    }
}

struct SlidingPuzzleWinStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
                .monospacedDigit()
        }
    }
}

#Preview {
    SlidingPuzzleView()
}

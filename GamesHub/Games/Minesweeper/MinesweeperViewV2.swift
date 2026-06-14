import SwiftUI

// MARK: - Models

enum MinesweeperGamePhase {
    case idle
    case playing
    case won
    case lost
}

enum MinesweeperDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var mineCount: Int {
        switch self {
        case .easy:   return 8
        case .medium: return 11
        case .hard:   return 14
        }
    }
}

struct MinesweeperBoard {
    static let gridSize = 8

    var cells: [[MinesweeperCell]] = Array(
        repeating: Array(repeating: MinesweeperCell(), count: MinesweeperBoard.gridSize),
        count: MinesweeperBoard.gridSize
    )
    var mineCount: Int = 10
    var flagCount: Int = 0
    var revealedCount: Int = 0
    var phase: MinesweeperGamePhase = .idle

    var remainingMines: Int { mineCount - flagCount }
    var safeCells: Int { MinesweeperBoard.gridSize * MinesweeperBoard.gridSize - mineCount }

    mutating func reset(mineCount: Int) {
        self.mineCount = mineCount
        flagCount = 0
        revealedCount = 0
        phase = .idle
        cells = Array(
            repeating: Array(repeating: MinesweeperCell(), count: MinesweeperBoard.gridSize),
            count: MinesweeperBoard.gridSize
        )
    }

    mutating func placeMines(avoiding row: Int, col: Int) {
        let size = MinesweeperBoard.gridSize
        var positions: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size {
                // Avoid the tapped cell and its neighbors
                if abs(r - row) > 1 || abs(c - col) > 1 {
                    positions.append((r, c))
                }
            }
        }
        positions.shuffle()
        let toPlace = min(mineCount, positions.count)
        for i in 0..<toPlace {
            cells[positions[i].0][positions[i].1].isMine = true
        }
        // Compute adjacency
        for r in 0..<size {
            for c in 0..<size {
                if !cells[r][c].isMine {
                    cells[r][c].adjacentMines = countAdjacentMines(row: r, col: c)
                }
            }
        }
    }

    func countAdjacentMines(row: Int, col: Int) -> Int {
        let size = MinesweeperBoard.gridSize
        var count = 0
        for dr in -1...1 {
            for dc in -1...1 {
                if dr == 0 && dc == 0 { continue }
                let nr = row + dr
                let nc = col + dc
                if nr >= 0 && nr < size && nc >= 0 && nc < size && cells[nr][nc].isMine {
                    count += 1
                }
            }
        }
        return count
    }

    mutating func reveal(row: Int, col: Int) {
        guard phase == .playing || phase == .idle else { return }
        guard cells[row][col].state == .hidden else { return }

        if phase == .idle {
            phase = .playing
            placeMines(avoiding: row, col: col)
        }

        if cells[row][col].isMine {
            cells[row][col].state = .revealed
            phase = .lost
            revealAllMines()
            return
        }

        floodReveal(row: row, col: col)

        if revealedCount >= safeCells {
            phase = .won
        }
    }

    mutating func floodReveal(row: Int, col: Int) {
        let size = MinesweeperBoard.gridSize
        guard row >= 0 && row < size && col >= 0 && col < size else { return }
        guard cells[row][col].state == .hidden && !cells[row][col].isMine else { return }

        cells[row][col].state = .revealed
        revealedCount += 1

        if cells[row][col].adjacentMines == 0 {
            for dr in -1...1 {
                for dc in -1...1 {
                    if dr == 0 && dc == 0 { continue }
                    floodReveal(row: row + dr, col: col + dc)
                }
            }
        }
    }

    mutating func toggleFlag(row: Int, col: Int) {
        guard phase == .playing || phase == .idle else { return }
        guard cells[row][col].state != .revealed else { return }

        if cells[row][col].state == .flagged {
            cells[row][col].state = .hidden
            flagCount -= 1
        } else {
            cells[row][col].state = .flagged
            flagCount += 1
        }
    }

    mutating func revealAllMines() {
        let size = MinesweeperBoard.gridSize
        for r in 0..<size {
            for c in 0..<size {
                if cells[r][c].isMine && cells[r][c].state != .flagged {
                    cells[r][c].state = .revealed
                }
            }
        }
    }
}

// MARK: - Number Colors

private func minesweeperNumberColor(_ n: Int) -> Color {
    switch n {
    case 1: return Color(red: 0.2, green: 0.5, blue: 1.0)
    case 2: return Color(red: 0.1, green: 0.75, blue: 0.3)
    case 3: return Color(red: 1.0, green: 0.3, blue: 0.3)
    case 4: return Color(red: 0.5, green: 0.1, blue: 0.8)
    case 5: return Color(red: 0.8, green: 0.1, blue: 0.1)
    case 6: return Color(red: 0.1, green: 0.7, blue: 0.8)
    case 7: return Color(red: 0.15, green: 0.15, blue: 0.15)
    case 8: return Color(red: 0.5, green: 0.5, blue: 0.5)
    default: return .clear
    }
}

// MARK: - Main View

struct MinesweeperViewV2: View {
    @State private var board = MinesweeperBoard()
    @State private var roundScores: [Int] = []
    @State private var difficulty: MinesweeperDifficulty = .easy
    @State private var elapsedSeconds: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var isStarted: Bool = false
    @State private var winStreak: Int = 0
    @State private var loseStreak: Int = 0

    private let gridSize = MinesweeperBoard.gridSize

    // Score: time-based, fewer seconds = better, flag bonus
    private func computeScore() -> Int {
        let timeScore = max(0, 300 - elapsedSeconds) * 10
        return max(0, timeScore)
    }

    var body: some View {
        GeometryReader { geo in
            let availableWidth = geo.size.width - 24
            let cellSize = availableWidth / CGFloat(gridSize)
            let boardSize = cellSize * CGFloat(gridSize)

            ZStack {
                // Dark background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.14),
                        Color(red: 0.10, green: 0.08, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    headerView
                    boardView(cellSize: cellSize, boardSize: boardSize)
                    Spacer()
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                if !isStarted {
                    startOverlay
                } else if board.phase == .won || board.phase == .lost {
                    gameOverOverlay
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 10) {
            // Mine counter
            glassStatBadge(
                icon: "💣",
                value: "\(board.remainingMines)",
                label: "MINES"
            )

            Spacer()

            // Difficulty badge
            HStack(spacing: 6) {
                Circle()
                    .fill(difficulty.color)
                    .frame(width: 8, height: 8)
                VStack(spacing: 1) {
                    Text("LEVEL")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                    Text(difficulty.rawValue)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(difficulty.color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))

            Spacer()

            // Timer
            glassStatBadge(
                icon: "⏱",
                value: String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60),
                label: "TIME"
            )
        }
    }

    private func glassStatBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 1) {
            HStack(spacing: 4) {
                Text(icon)
                    .font(.system(size: 13))
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Board

    private func boardView(cellSize: CGFloat, boardSize: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Board background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                )

            // Cells
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    cellView(row: row, col: col, cellSize: cellSize)
                        .frame(width: cellSize, height: cellSize)
                        .offset(
                            x: CGFloat(col) * cellSize,
                            y: CGFloat(row) * cellSize
                        )
                }
            }

            // Grid lines overlay
            Canvas { ctx, size in
                let cw = size.width / CGFloat(gridSize)
                let ch = size.height / CGFloat(gridSize)
                var path = Path()
                for i in 1..<gridSize {
                    path.move(to: CGPoint(x: CGFloat(i) * cw, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(i) * cw, y: size.height))
                    path.move(to: CGPoint(x: 0, y: CGFloat(i) * ch))
                    path.addLine(to: CGPoint(x: size.width, y: CGFloat(i) * ch))
                }
                ctx.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 0.5)
            }
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .frame(width: boardSize, height: boardSize)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.5), radius: 12)
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int, cellSize: CGFloat) -> some View {
        let cell = board.cells[row][col]
        let padding: CGFloat = 2

        ZStack {
            switch cell.state {
            case .hidden:
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.22, green: 0.22, blue: 0.38),
                                Color(red: 0.15, green: 0.15, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                    )
                    .padding(padding)

            case .flagged:
                RoundedRectangle(cornerRadius: 5)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.20, blue: 0.38),
                                Color(red: 0.20, green: 0.14, blue: 0.28)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Color.purple.opacity(0.4), lineWidth: 0.8)
                    )
                    .padding(padding)
                Text("🚩")
                    .font(.system(size: cellSize * 0.45))

            case .revealed:
                if cell.isMine {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.5, green: 0.08, blue: 0.08))
                        .padding(padding)
                    Text("💣")
                        .font(.system(size: cellSize * 0.45))
                } else if cell.adjacentMines > 0 {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.12, green: 0.12, blue: 0.22))
                        .padding(padding)
                    Text("\(cell.adjacentMines)")
                        .font(.system(size: cellSize * 0.48, weight: .bold, design: .monospaced))
                        .foregroundColor(minesweeperNumberColor(cell.adjacentMines))
                } else {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.10, green: 0.10, blue: 0.18))
                        .padding(padding)
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    let dist = sqrt(value.translation.width * value.translation.width +
                                   value.translation.height * value.translation.height)
                    if dist < 10 {
                        handleTap(row: row, col: col)
                    }
                }
        )
        .onLongPressGesture(minimumDuration: 0.4) {
            handleLongPress(row: row, col: col)
        }
    }

    // MARK: - Start Overlay

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                Text("MINESWEEPER")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.9), radius: 14)

                VStack(spacing: 6) {
                    Text("Tap to reveal  |  Long-press to flag")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))

                    difficultyBadgeView
                }

                Button(action: startGame) {
                    Text("Start Game")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 38)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.7, blue: 1.0),
                                    Color(red: 0.1, green: 0.5, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.blue.opacity(0.5), radius: 12)
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 28)
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    // MARK: - Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.60)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                let won = board.phase == .won

                Text(won ? "YOU WIN!" : "GAME OVER")
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(
                        color: (won ? Color.green : Color.red).opacity(0.85),
                        radius: 12
                    )

                VStack(spacing: 6) {
                    if won {
                        Text("Cleared in \(String(format: "%02d:%02d", elapsedSeconds / 60, elapsedSeconds % 60))")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                    }

                    if !roundScores.isEmpty {
                        let avg = movingAverage(roundScores)
                        Text("Avg score (last \(roundScores.count)): \(String(format: "%.0f", avg))")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                    }
                }

                // Difficulty badge for next round
                difficultyBadgeView

                // Recent scores mini-row
                if !roundScores.isEmpty {
                    VStack(spacing: 4) {
                        Text("RECENT SCORES")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))
                        HStack(spacing: 6) {
                            ForEach(Array(roundScores.enumerated()), id: \.offset) { _, s in
                                Text("\(s)")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.75))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                Button(action: restartGame) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 38)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.7, blue: 1.0),
                                    Color(red: 0.1, green: 0.5, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.blue.opacity(0.5), radius: 12)
                }
            }
            .padding(28)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)
            .shadow(color: .black.opacity(0.5), radius: 30)
        }
    }

    private var difficultyBadgeView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
            Text("Difficulty: \(difficulty.rawValue)  (\(difficulty.mineCount) mines)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(difficulty.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(difficulty.color.opacity(0.15), in: Capsule())
        .overlay(Capsule().strokeBorder(difficulty.color.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Game Logic

    private func startGame() {
        isStarted = true
        newRound()
    }

    private func newRound() {
        stopGameTimer()
        elapsedSeconds = 0
        board.reset(mineCount: difficulty.mineCount)
    }

    private func restartGame() {
        stopGameTimer()
        elapsedSeconds = 0
        board.reset(mineCount: difficulty.mineCount)
    }

    private func startGameTimer() {
        stopGameTimer()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }

    private func stopGameTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func handleTap(row: Int, col: Int) {
        guard board.phase == .idle || board.phase == .playing else { return }
        guard board.cells[row][col].state == .hidden else { return }

        if board.phase == .idle {
            startGameTimer()
        }

        board.reveal(row: row, col: col)

        if board.phase == .won || board.phase == .lost {
            stopGameTimer()
            handleRoundEnd()
        }
    }

    private func handleLongPress(row: Int, col: Int) {
        guard board.phase == .idle || board.phase == .playing else { return }

        if board.phase == .idle {
            startGameTimer()
        }

        board.toggleFlag(row: row, col: col)
    }

    private func handleRoundEnd() {
        let score = computeScore()
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        adjustDifficulty()
    }

    private func movingAverage(_ scores: [Int]) -> Double {
        guard !scores.isEmpty else { return 0 }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    private func adjustDifficulty() {
        // Need at least 2 rounds for meaningful adjustment
        guard roundScores.count >= 2 else {
            difficulty = .easy
            return
        }

        let avg = movingAverage(roundScores)
        // Score > 2000: winning fast -> increase difficulty
        // Score < 500: struggling -> decrease difficulty
        if avg >= 2000 {
            difficulty = .hard
        } else if avg >= 1000 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }
    }
}

// MARK: - Preview

#Preview {
    MinesweeperViewV2()
}

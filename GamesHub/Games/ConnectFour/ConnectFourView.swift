import SwiftUI

// MARK: - Models

enum ConnectFourCell {
    case empty, player, ai
}

enum ConnectFourGameState {
    case playerTurn, aiTurn, playerWin, aiWin, draw
}

// MARK: - Models

enum ConnectFourDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

// MARK: - Main View

struct ConnectFourView: View {
    // Grid dimensions
    private let columns = 7
    private let rows = 6

    // Board state
    @State private var board: [[ConnectFourCell]] = Array(
        repeating: Array(repeating: .empty, count: 7),
        count: 6
    )
    @State private var gameState: ConnectFourGameState = .playerTurn
    @State private var isPlayerTurn: Bool = true
    @State private var winningCells: Set<[Int]> = []

    // Difficulty & scoring
    @State private var difficulty: ConnectFourDifficulty = .easy
    @State private var roundScores: [Int] = []
    @AppStorage("connectFourPlayerWins") private var playerWins: Int = 0
    @AppStorage("connectFourAIWins") private var aiWins: Int = 0

    // Animation
    @State private var droppingColumn: Int? = nil
    @State private var droppingRow: Int? = nil
    @State private var isAIThinking: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.18), Color(red: 0.1, green: 0.05, blue: 0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                headerView
                difficultyBadge
                boardView
                scoreView
                restartButton
            }
            .padding()

            // Win/Draw overlay
            if gameState == .playerWin || gameState == .aiWin || gameState == .draw {
                overlayView
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Connect Four")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            HStack(spacing: 8) {
                Circle()
                    .fill(isPlayerTurn ? Color.red : Color.yellow)
                    .frame(width: 12, height: 12)
                    .shadow(color: isPlayerTurn ? .red : .yellow, radius: 4)
                Text(isPlayerTurn ? "Your Turn" : (isAIThinking ? "AI Thinking..." : "AI Turn"))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }

    private var difficultyBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: difficultyIcon)
                .font(.system(size: 12, weight: .semibold))
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(difficultyColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(difficultyColor.opacity(0.5), lineWidth: 1)
            }
        )
    }

    private var boardView: some View {
        GeometryReader { geo in
            let cellSize = min((geo.size.width - 16) / CGFloat(columns), (geo.size.height - 16) / CGFloat(rows))
            let boardWidth = cellSize * CGFloat(columns)
            let boardHeight = cellSize * CGFloat(rows)

            ZStack {
                // Board background with glassmorphism
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)

                VStack(spacing: 0) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<columns, id: \.self) { col in
                                cellView(row: row, col: col, size: cellSize)
                            }
                        }
                    }
                }
                .padding(8)
            }
            .frame(width: boardWidth + 16, height: boardHeight + 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard isPlayerTurn, gameState == .playerTurn || gameState == .aiTurn, !isAIThinking else { return }
                        let boardOriginX = (geo.size.width - boardWidth - 16) / 2 + 8
                        let tapX = value.location.x - boardOriginX
                        let col = Int(tapX / cellSize)
                        if col >= 0 && col < columns {
                            playerTap(column: col)
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
    }

    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let cell = board[row][col]
        let isWinning = winningCells.contains([row, col])
        let isDropping = droppingColumn == col && droppingRow == row

        return ZStack {
            // Cell hole background
            Circle()
                .fill(Color.black.opacity(0.35))
                .padding(4)

            // Disc
            if cell != .empty {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: cell == .player
                                ? [Color(red: 1, green: 0.4, blue: 0.4), Color.red]
                                : [Color(red: 1, green: 0.95, blue: 0.4), Color.yellow],
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: size * 0.45
                        )
                    )
                    .padding(5)
                    .shadow(color: (cell == .player ? Color.red : Color.yellow).opacity(0.6), radius: isWinning ? 8 : 2)
                    .scaleEffect(isWinning ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isWinning)
                    .offset(y: isDropping ? -size * CGFloat(row + 1) : 0)
                    .animation(isDropping ? .spring(response: 0.4, dampingFraction: 0.65) : .none, value: isDropping)
            }
        }
        .frame(width: size, height: size)
    }

    private var scoreView: some View {
        HStack(spacing: 20) {
            scoreCard(label: "You", value: playerWins, color: .red)
            VStack(spacing: 2) {
                Text("vs")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                if !roundScores.isEmpty {
                    Text("avg \(movingAverage, specifier: "%.1f")")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            scoreCard(label: "AI", value: aiWins, color: .yellow)
        }
        .padding(.horizontal, 8)
    }

    private func scoreCard(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(width: 70, height: 56)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(color.opacity(0.3), lineWidth: 1)
                )
        )
    }

    private var restartButton: some View {
        Button(action: resetGame) {
            Label("New Game", systemImage: "arrow.counterclockwise")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.blue.opacity(0.5))
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    }
                )
        }
    }

    private var overlayView: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 20) {
                Text(overlayEmoji)
                    .font(.system(size: 56))

                Text(overlayTitle)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(overlaySubtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Button(action: resetGame) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 40)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: gameState)
    }

    // MARK: - Computed Properties

    private var overlayTitle: String {
        switch gameState {
        case .playerWin: return "You Win!"
        case .aiWin: return "AI Wins!"
        case .draw: return "Draw!"
        default: return ""
        }
    }

    private var overlayEmoji: String {
        switch gameState {
        case .playerWin: return "🎉"
        case .aiWin: return "🤖"
        case .draw: return "🤝"
        default: return ""
        }
    }

    private var overlaySubtitle: String {
        switch gameState {
        case .playerWin: return "Nice move! The AI is learning..."
        case .aiWin: return "Better luck next time!"
        case .draw: return "A perfectly balanced match."
        default: return ""
        }
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    private var difficultyIcon: String {
        switch difficulty {
        case .easy: return "tortoise.fill"
        case .medium: return "hare.fill"
        case .hard: return "flame.fill"
        }
    }

    private var movingAverage: Double {
        guard !roundScores.isEmpty else { return 0 }
        return Double(roundScores.reduce(0, +)) / Double(roundScores.count)
    }

    // MARK: - Game Logic

    private func playerTap(column: Int) {
        guard let row = lowestEmptyRow(col: column) else { return }
        dropDisc(row: row, col: column, cell: .player)

        if checkWin(row: row, col: column, cell: .player) {
            handleGameOver(state: .playerWin)
        } else if isBoardFull() {
            handleGameOver(state: .draw)
        } else {
            isPlayerTurn = false
            scheduleAIMove()
        }
    }

    private func scheduleAIMove() {
        isAIThinking = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            performAIMove()
            isAIThinking = false
        }
    }

    private func performAIMove() {
        guard gameState == .playerTurn || gameState == .aiTurn else { return }

        let col: Int
        switch difficulty {
        case .easy:
            col = aiRandomMove() ?? 0
        case .medium:
            col = aiLookAhead1() ?? aiRandomMove() ?? 0
        case .hard:
            col = aiLookAhead2() ?? aiLookAhead1() ?? aiRandomMove() ?? 0
        }

        guard let row = lowestEmptyRow(col: col) else { return }
        dropDisc(row: row, col: col, cell: .ai)

        if checkWin(row: row, col: col, cell: .ai) {
            handleGameOver(state: .aiWin)
        } else if isBoardFull() {
            handleGameOver(state: .draw)
        } else {
            isPlayerTurn = true
        }
    }

    private func dropDisc(row: Int, col: Int, cell: ConnectFourCell) {
        droppingColumn = col
        droppingRow = row
        board[row][col] = cell
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            droppingColumn = nil
            droppingRow = nil
        }
    }

    private func handleGameOver(state: ConnectFourGameState) {
        gameState = state

        // Compute round score (1 = player win, 0 = loss/draw)
        let score: Int
        switch state {
        case .playerWin:
            score = 1
            playerWins += 1
        case .aiWin:
            score = 0
            aiWins += 1
        case .draw:
            score = 0
        default:
            score = 0
        }

        // Append to roundScores, keep last 5
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores.removeFirst(roundScores.count - 5)
        }

        // Adjust difficulty based on moving average
        let avg = movingAverage
        if avg >= 0.6 {
            difficulty = .hard
        } else if avg >= 0.35 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }

        // Highlight winning cells
        if state == .playerWin || state == .aiWin {
            let winCell: ConnectFourCell = state == .playerWin ? .player : .ai
            winningCells = findWinningCells(cell: winCell)
        }
    }

    private func resetGame() {
        board = Array(repeating: Array(repeating: .empty, count: columns), count: rows)
        gameState = .playerTurn
        isPlayerTurn = true
        winningCells = []
        droppingColumn = nil
        droppingRow = nil
        isAIThinking = false
    }

    // MARK: - Board Helpers

    private func lowestEmptyRow(col: Int) -> Int? {
        for row in stride(from: rows - 1, through: 0, by: -1) {
            if board[row][col] == .empty { return row }
        }
        return nil
    }

    private func isBoardFull() -> Bool {
        board[0].allSatisfy { $0 != .empty }
    }

    private func validColumns() -> [Int] {
        (0..<columns).filter { lowestEmptyRow(col: $0) != nil }
    }

    // MARK: - Win Detection

    private func checkWin(row: Int, col: Int, cell: ConnectFourCell) -> Bool {
        !findWinningCells(cell: cell).isEmpty
    }

    private func findWinningCells(cell: ConnectFourCell) -> Set<[Int]> {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for r in 0..<rows {
            for c in 0..<columns {
                guard board[r][c] == cell else { continue }
                for (dr, dc) in directions {
                    var cells: [[Int]] = [[r, c]]
                    for i in 1..<4 {
                        let nr = r + dr * i
                        let nc = c + dc * i
                        guard nr >= 0, nr < rows, nc >= 0, nc < columns else { break }
                        if board[nr][nc] == cell { cells.append([nr, nc]) }
                        else { break }
                    }
                    if cells.count == 4 { return Set(cells.map { $0 }) }
                }
            }
        }
        return []
    }

    private func wouldWin(col: Int, cell: ConnectFourCell) -> Bool {
        guard let row = lowestEmptyRow(col: col) else { return false }
        var testBoard = board
        testBoard[row][col] = cell
        return checkWinOnBoard(testBoard, row: row, col: col, cell: cell)
    }

    private func checkWinOnBoard(_ b: [[ConnectFourCell]], row: Int, col: Int, cell: ConnectFourCell) -> Bool {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for (dr, dc) in directions {
            var count = 1
            for sign in [-1, 1] {
                var i = 1
                while true {
                    let nr = row + dr * i * sign
                    let nc = col + dc * i * sign
                    guard nr >= 0, nr < rows, nc >= 0, nc < columns, b[nr][nc] == cell else { break }
                    count += 1
                    i += 1
                }
            }
            if count >= 4 { return true }
        }
        return false
    }

    // MARK: - AI Move Strategies

    private func aiRandomMove() -> Int? {
        validColumns().shuffled().first
    }

    /// Look ahead 1: win if possible, block player win, else nil
    private func aiLookAhead1() -> Int? {
        let valid = validColumns()

        // Can AI win immediately?
        for col in valid {
            if wouldWin(col: col, cell: .ai) { return col }
        }

        // Block player immediate win
        for col in valid {
            if wouldWin(col: col, cell: .player) { return col }
        }

        return nil
    }

    /// Look ahead 2: win, block, or pick column that doesn't let opponent win next turn
    private func aiLookAhead2() -> Int? {
        let valid = validColumns()

        // Can AI win immediately?
        for col in valid {
            if wouldWin(col: col, cell: .ai) { return col }
        }

        // Block player immediate win
        for col in valid {
            if wouldWin(col: col, cell: .player) { return col }
        }

        // Look 2 ahead: find moves where AI can win on next turn
        for col in valid {
            guard let row = lowestEmptyRow(col: col) else { continue }
            var testBoard = board
            testBoard[row][col] = .ai
            let testView = ConnectFourBoardHelper(board: testBoard, rows: rows, columns: columns)
            // After AI places, check if AI has a forced win next turn
            let aiNextWin = testView.validColumns().contains { c in
                testView.wouldWin(col: c, cell: .ai)
            }
            if aiNextWin { return col }
        }

        // Prefer center columns
        let preferredOrder = [3, 2, 4, 1, 5, 0, 6]
        for col in preferredOrder where valid.contains(col) {
            // Avoid giving player immediate win
            guard let row = lowestEmptyRow(col: col) else { continue }
            var testBoard = board
            testBoard[row][col] = .ai
            let helper = ConnectFourBoardHelper(board: testBoard, rows: rows, columns: columns)
            let playerCanWin = helper.validColumns().contains { c in
                helper.wouldWin(col: c, cell: .player)
            }
            if !playerCanWin { return col }
        }

        return nil
    }
}

// MARK: - Board Helper (for look-ahead)

private struct ConnectFourBoardHelper {
    let board: [[ConnectFourCell]]
    let rows: Int
    let columns: Int

    func validColumns() -> [Int] {
        (0..<columns).filter { lowestEmptyRow(col: $0) != nil }
    }

    func lowestEmptyRow(col: Int) -> Int? {
        for row in stride(from: rows - 1, through: 0, by: -1) {
            if board[row][col] == .empty { return row }
        }
        return nil
    }

    func wouldWin(col: Int, cell: ConnectFourCell) -> Bool {
        guard let row = lowestEmptyRow(col: col) else { return false }
        var testBoard = board
        testBoard[row][col] = cell
        return checkWin(testBoard, row: row, col: col, cell: cell)
    }

    func checkWin(_ b: [[ConnectFourCell]], row: Int, col: Int, cell: ConnectFourCell) -> Bool {
        let directions = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for (dr, dc) in directions {
            var count = 1
            for sign in [-1, 1] {
                var i = 1
                while true {
                    let nr = row + dr * i * sign
                    let nc = col + dc * i * sign
                    guard nr >= 0, nr < rows, nc >= 0, nc < columns, b[nr][nc] == cell else { break }
                    count += 1
                    i += 1
                }
            }
            if count >= 4 { return true }
        }
        return false
    }
}

#Preview {
    ConnectFourView()
}

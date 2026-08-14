import SwiftUI

// MARK: - Models

enum TicTacToeCell {
    case empty
    case x
    case o
}

enum TicTacToeGameState {
    case playing
    case xWins
    case oWins
    case draw
}

// MARK: - Game Logic

struct TicTacToeBoard {
    var cells: [TicTacToeCell] = Array(repeating: .empty, count: 9)

    func winner() -> TicTacToeCell? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        for line in lines {
            let a = cells[line[0]], b = cells[line[1]], c = cells[line[2]]
            if a != .empty && a == b && b == c {
                return a
            }
        }
        return nil
    }

    func isDraw() -> Bool {
        return cells.allSatisfy { $0 != .empty } && winner() == nil
    }

    func winningLine() -> [Int]? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        for line in lines {
            let a = cells[line[0]], b = cells[line[1]], c = cells[line[2]]
            if a != .empty && a == b && b == c {
                return line
            }
        }
        return nil
    }

    func availableMoves() -> [Int] {
        cells.indices.filter { cells[$0] == .empty }
    }

    mutating func place(_ cell: TicTacToeCell, at index: Int) {
        cells[index] = cell
    }
}

// MARK: - Minimax AI

struct TicTacToeAI {
    func bestMove(for board: TicTacToeBoard) -> Int? {
        let moves = board.availableMoves()
        guard !moves.isEmpty else { return nil }

        var bestScore = Int.min
        var bestMove = moves[0]

        for move in moves {
            var newBoard = board
            newBoard.place(.o, at: move)
            let score = minimax(board: newBoard, depth: 0, isMaximizing: false)
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    private func minimax(board: TicTacToeBoard, depth: Int, isMaximizing: Bool) -> Int {
        if let winner = board.winner() {
            return winner == .o ? 10 - depth : depth - 10
        }
        if board.isDraw() { return 0 }

        let moves = board.availableMoves()

        if isMaximizing {
            var best = Int.min
            for move in moves {
                var newBoard = board
                newBoard.place(.o, at: move)
                best = max(best, minimax(board: newBoard, depth: depth + 1, isMaximizing: false))
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                var newBoard = board
                newBoard.place(.x, at: move)
                best = min(best, minimax(board: newBoard, depth: depth + 1, isMaximizing: true))
            }
            return best
        }
    }
}

// MARK: - Models

enum TicTacToeDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

// MARK: - Board Extensions

extension TicTacToeBoard {
    subscript(row: Int, col: Int) -> TicTacToeCell {
        get { cells[row * 3 + col] }
        set { cells[row * 3 + col] = newValue }
    }
    var isFull: Bool { availableMoves().isEmpty }
}

// MARK: - Main View

struct TicTacToeView: View {
    // Scores
    @AppStorage("ticTacToePlayerWins") var xWins: Int = 0
    @AppStorage("ticTacToeAIWins") var oWins: Int = 0
    @AppStorage("ticTacToeDraws") var draws: Int = 0

    // Round tracking for adaptive difficulty
    @State var roundScores: [Int] = []
    @State var difficulty: TicTacToeDifficulty = .medium

    // Board state
    let boardSize: Int = 3
    @State var board: TicTacToeBoard = TicTacToeBoard()
    @State var gameState: TicTacToeGameState = .playing
    @State var isPlayerTurn: Bool = true
    @State var isAIThinking: Bool = false

    // Animation
    @State var cellAnimations: [Bool] = Array(repeating: false, count: 16)
    @State var winningCells: Set<Int> = []
    @State var showOverlay: Bool = false
    @State var resultMessage: String = ""
    @State var boardShake: CGFloat = 0

    var body: some View {
        ZStack {
            backgroundGradient
            VStack(spacing: 24) {
                headerSection
                difficultyBadge
                scoreRow
                boardView
                statusText
                restartButton
            }
            .padding(.horizontal, 20)

            if showOverlay {
                resultOverlay
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { startNewGame() }
    }

    // MARK: - Background

    var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.18),
                Color(red: 0.10, green: 0.05, blue: 0.25),
                Color(red: 0.05, green: 0.10, blue: 0.20)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    var headerSection: some View {
        VStack(spacing: 4) {
            Text("Tic-Tac-Toe")
                .font(.largeTitle.bold())
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("Beat the AI three in a row")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.top, 8)
    }

    // MARK: - Difficulty Badge

    var difficultyBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(difficultyColor)
                .frame(width: 8, height: 8)
                .shadow(color: difficultyColor, radius: 4)
            Text(difficulty.rawValue)
                .font(.caption.bold())
                .foregroundColor(difficultyColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(difficultyColor.opacity(0.4), lineWidth: 1)
                )
        )
    }

    var difficultyColor: Color {
        switch difficulty {
        case .easy: return .green
        case .medium: return .yellow
        case .hard: return .red
        }
    }

    // MARK: - Score Row

    var scoreRow: some View {
        HStack(spacing: 12) {
            scoreCard(label: "You (X)", value: xWins, color: .cyan)
            scoreCard(label: "Draws", value: draws, color: .white.opacity(0.6))
            scoreCard(label: "AI (O)", value: oWins, color: .purple)
        }
    }

    func scoreCard(label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Board

    var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = (size - CGFloat(boardSize - 1) * 6) / CGFloat(boardSize)
            VStack(spacing: 6) {
                ForEach(0..<boardSize, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(0..<boardSize, id: \.self) { col in
                            let index = row * boardSize + col
                            cellView(index: index, cellSize: cellSize)
                        }
                    }
                }
            }
            .frame(width: size, height: size)
            .offset(x: boardShake)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 4)
    }

    func cellView(index: Int, cellSize: CGFloat) -> some View {
        let cell = board.cells[index]
        let isWinning = winningCells.contains(index)
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isWinning
                            ? LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: isWinning ? 2 : 1
                        )
                )
                .shadow(color: isWinning ? Color.yellow.opacity(0.3) : Color.clear, radius: 8)

            if cell == .x {
                TicTacToeXShape()
                    .stroke(
                        LinearGradient(colors: [Color.cyan, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: cellSize * 0.08, lineCap: .round)
                    )
                    .padding(cellSize * 0.2)
                    .scaleEffect(cellAnimations[index] ? 1 : 0.1)
                    .opacity(cellAnimations[index] ? 1 : 0)
            } else if cell == .o {
                Circle()
                    .stroke(
                        LinearGradient(colors: [Color.purple, Color.pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: cellSize * 0.08)
                    )
                    .padding(cellSize * 0.2)
                    .scaleEffect(cellAnimations[index] ? 1 : 0.1)
                    .opacity(cellAnimations[index] ? 1 : 0)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture {
            handleTap(index: index)
        }
    }

    // MARK: - Status

    var statusText: some View {
        Group {
            if isAIThinking {
                HStack(spacing: 8) {
                    TicTacToeThinkingDots()
                    Text("AI is thinking...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            } else if gameState == .playing {
                Text(isPlayerTurn ? "Your turn (X)" : "AI's turn (O)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(resultMessage)
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(height: 28)
    }

    // MARK: - Restart

    var restartButton: some View {
        Button(action: startNewGame) {
            Label("New Game", systemImage: "arrow.counterclockwise")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.6), Color.purple.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                        )
                )
        }
        .padding(.bottom, 8)
    }

    // MARK: - Result Overlay

    var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .blur(radius: 2)

            VStack(spacing: 20) {
                Text(gameState == .xWins ? "🎉" : gameState == .oWins ? "🤖" : "🤝")
                    .font(.system(size: 60))

                Text(resultMessage)
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Next difficulty: \(difficulty.rawValue)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                Button(action: startNewGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan, Color.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )
            )
            .padding(32)
            .scaleEffect(showOverlay ? 1 : 0.7)
            .opacity(showOverlay ? 1 : 0)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showOverlay)
    }

    // MARK: - Game Logic

    func startNewGame() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showOverlay = false
        }
        board = TicTacToeBoard()
        cellAnimations = Array(repeating: false, count: boardSize * boardSize)
        winningCells = []
        gameState = .playing
        isPlayerTurn = true
        isAIThinking = false
        resultMessage = ""
    }

    func handleTap(index: Int) {
        guard gameState == .playing,
              isPlayerTurn,
              !isAIThinking,
              board.cells[index] == .empty else { return }

        placeMarker(index: index, cell: .x)
        guard gameState == .playing else { return }

        isPlayerTurn = false
        isAIThinking = true

        let delay: Double = Double.random(in: 0.4...0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            aiMove()
        }
    }

    func aiMove() {
        guard gameState == .playing else {
            isAIThinking = false
            return
        }
        if let idx = chooseAIMove() {
            placeMarker(index: idx, cell: .o)
        }
        isAIThinking = false
        isPlayerTurn = true
    }

    /// Difficulty decides how often the AI actually plays its best move.
    /// Hard is the full minimax, so it can never be beaten — only drawn.
    private func chooseAIMove() -> Int? {
        let moves = board.availableMoves()
        guard !moves.isEmpty else { return nil }

        switch difficulty {
        case .easy:
            // Blocks nothing on purpose; takes a win if one is sitting there.
            return winningMove(for: .o) ?? moves.randomElement()
        case .medium:
            if let win = winningMove(for: .o) { return win }
            if let block = winningMove(for: .x) { return block }
            return Bool.random() ? TicTacToeAI().bestMove(for: board) : moves.randomElement()
        case .hard:
            return TicTacToeAI().bestMove(for: board)
        }
    }

    private func winningMove(for cell: TicTacToeCell) -> Int? {
        for move in board.availableMoves() {
            var test = board
            test.place(cell, at: move)
            if test.winner() == cell { return move }
        }
        return nil
    }

    func placeMarker(index: Int, cell: TicTacToeCell) {
        board.cells[index] = cell
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if index < cellAnimations.count {
                cellAnimations[index] = true
            }
        }
        checkGameEnd()
    }

    func checkGameEnd() {
        if let winner = board.winner() {
            // Find winning cells
            winningCells = findWinningCells()
            if winner == .x {
                xWins += 1
                gameState = .xWins
                resultMessage = "You Win!"
                recordRoundScore(1)
            } else {
                oWins += 1
                gameState = .oWins
                resultMessage = "AI Wins!"
                recordRoundScore(0)
            }
            withAnimation(.easeIn(duration: 0.5).delay(0.3)) {
                showOverlay = true
            }
        } else if board.isFull {
            draws += 1
            gameState = .draw
            resultMessage = "Draw!"
            recordRoundScore(0)
            triggerShake()
            withAnimation(.easeIn(duration: 0.5).delay(0.4)) {
                showOverlay = true
            }
        }
    }

    func findWinningCells() -> Set<Int> {
        var result: Set<Int> = []
        // Rows
        for r in 0..<boardSize {
            let first = board[r, 0]
            if first != .empty && (0..<boardSize).allSatisfy({ board[r, $0] == first }) {
                (0..<boardSize).forEach { result.insert(r * boardSize + $0) }
                return result
            }
        }
        // Cols
        for c in 0..<boardSize {
            let first = board[0, c]
            if first != .empty && (0..<boardSize).allSatisfy({ board[$0, c] == first }) {
                (0..<boardSize).forEach { result.insert($0 * boardSize + c) }
                return result
            }
        }
        // Main diagonal
        let firstDiag = board[0, 0]
        if firstDiag != .empty && (0..<boardSize).allSatisfy({ board[$0, $0] == firstDiag }) {
            (0..<boardSize).forEach { result.insert($0 * boardSize + $0) }
            return result
        }
        // Anti diagonal
        let firstAnti = board[0, boardSize - 1]
        if firstAnti != .empty && (0..<boardSize).allSatisfy({ board[$0, boardSize - 1 - $0] == firstAnti }) {
            (0..<boardSize).forEach { result.insert($0 * boardSize + (boardSize - 1 - $0)) }
            return result
        }
        return result
    }

    func triggerShake() {
        let duration = 0.06
        let offsets: [CGFloat] = [10, -10, 8, -8, 5, -5, 2, 0]
        for (i, offset) in offsets.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration * Double(i)) {
                withAnimation(.easeInOut(duration: duration)) {
                    boardShake = offset
                }
            }
        }
    }

    // MARK: - Adaptive Difficulty

    func recordRoundScore(_ score: Int) {
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        adjustDifficulty()
    }

    func adjustDifficulty() {
        guard roundScores.count >= 3 else { return }
        let recent = roundScores.suffix(5)
        let avg = Double(recent.reduce(0, +)) / Double(recent.count)

        // avg near 1 = the player keeps winning → sharpen the AI.
        if avg >= 0.6 {
            difficulty = .hard
        } else if avg >= 0.3 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }
    }
}

// MARK: - Shapes

// MARK: - Thinking Dots

struct TicTacToeThinkingDots: View {
    @State private var phase: Int = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(Color.purple)
                    .frame(width: 5, height: 5)
                    .opacity(phase == i ? 1 : 0.3)
                    .scaleEffect(phase == i ? 1.3 : 1)
                    .animation(.easeInOut(duration: 0.2), value: phase)
            }
        }
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}

// MARK: - Preview

#Preview {
    TicTacToeView()
}

#Preview {
    TicTacToeView()
}

// MARK: - X Shape

struct TicTacToeXShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

import SwiftUI

// MARK: - Constants
private let tetrisBoardCols = 10
private let tetrisBoardRows = 20
private let tetrisCellSize: CGFloat = 32

// MARK: - Tetromino Definitions
enum TetrisTetrominoType: Int, CaseIterable {
    case I, O, T, S, Z, J, L
}

struct TetrisTetrominoDef {
    let cells: [(Int, Int)] // (row, col) offsets
    let color: Color

    static let all: [TetrisTetrominoType: TetrisTetrominoDef] = [
        .I: TetrisTetrominoDef(cells: [(0,0),(0,1),(0,2),(0,3)], color: .cyan),
        .O: TetrisTetrominoDef(cells: [(0,0),(0,1),(1,0),(1,1)], color: .yellow),
        .T: TetrisTetrominoDef(cells: [(0,1),(1,0),(1,1),(1,2)], color: .purple),
        .S: TetrisTetrominoDef(cells: [(0,1),(0,2),(1,0),(1,1)], color: .green),
        .Z: TetrisTetrominoDef(cells: [(0,0),(0,1),(1,1),(1,2)], color: .red),
        .J: TetrisTetrominoDef(cells: [(0,0),(1,0),(1,1),(1,2)], color: .blue),
        .L: TetrisTetrominoDef(cells: [(0,2),(1,0),(1,1),(1,2)], color: .orange),
    ]
}

// MARK: - Piece Model

struct TetrisV2Piece {
    var row: Int
    var col: Int
    var cells: [(Int, Int)] // (row, col) offsets
    var color: Color

    func absoluteCells() -> [(Int, Int)] {
        cells.map { ($0.0 + row, $0.1 + col) }
    }

    static func spawn(type: TetrisTetrominoType) -> TetrisV2Piece {
        guard let def = TetrisTetrominoDef.all[type] else {
            return TetrisV2Piece(row: 0, col: 4, cells: [(0,0)], color: .gray)
        }
        return TetrisV2Piece(row: 0, col: 4, cells: def.cells, color: def.color)
    }

    func rotated() -> TetrisV2Piece {
        let maxRow = cells.map { $0.0 }.max() ?? 0
        let rotatedCells = cells.map { (r, c) -> (Int, Int) in
            return (c, maxRow - r)
        }
        return TetrisV2Piece(row: row, col: col, cells: rotatedCells, color: color)
    }
}

// MARK: - Difficulty
enum TetrisDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var badgeColor: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var fallInterval: Double {
        switch self {
        case .easy: return 0.7
        case .medium: return 0.5
        case .hard: return 0.3
        }
    }

    static func from(movingAverage: Double) -> TetrisDifficulty {
        if movingAverage < 300 { return .easy }
        if movingAverage < 800 { return .medium }
        return .hard
    }
}

// MARK: - Game State
enum TetrisGameState {
    case idle, playing, gameOver
}

// MARK: - Board Type
typealias TetrisBoard = [[Color?]]

// MARK: - Main View
struct TetrisViewV2: View {
    // Board state: nil = empty, Color = locked cell
    @State private var board: TetrisBoard = Array(
        repeating: Array(repeating: nil, count: tetrisBoardCols),
        count: tetrisBoardRows
    )
    @State private var currentPiece: TetrisV2Piece? = nil
    @State private var nextType: TetrisTetrominoType = TetrisTetrominoType.allCases.randomElement()!
    @State private var score: Int = 0
    @State private var level: Int = 1
    @State private var gameState: TetrisGameState = .idle
    @State private var roundScores: [Int] = []
    @State private var difficulty: TetrisDifficulty = .medium
    @State private var timer: Timer? = nil
    @State private var tickAccumulator: Double = 0
    @State private var lastTick: Date = Date()
    @State private var showGameOver: Bool = false

    // Gesture tracking
    @State private var dragStart: CGPoint? = nil
    @State private var dragHandled: Bool = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(white: 0.05), Color(white: 0.12), Color(white: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                // Header bar
                headerBar
                    .padding(.horizontal)

                // Board + side panel
                HStack(alignment: .top, spacing: 12) {
                    boardView
                        .gesture(swipeGesture)
                    sidePanel
                }
                .padding(.horizontal)

                // Start / instructions
                if gameState == .idle {
                    startPrompt
                }
            }
            .padding(.vertical, 16)

            // Game Over overlay
            if showGameOver {
                gameOverOverlay
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TETRIS LITE")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("V2 ADAPTIVE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(3)
                }

                Spacer()

                // Difficulty badge
                difficultyBadge

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                    Text("\(score)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(height: 60)
    }

    private var difficultyBadge: some View {
        Text(difficulty.rawValue.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(2)
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(difficulty.badgeColor.opacity(0.8))
                    .overlay(
                        Capsule()
                            .strokeBorder(difficulty.badgeColor, lineWidth: 1)
                    )
            )
    }

    // MARK: - Board View
    private var boardView: some View {
        let boardWidth = CGFloat(tetrisBoardCols) * tetrisCellSize
        let boardHeight = CGFloat(tetrisBoardRows) * tetrisCellSize

        return ZStack(alignment: .topLeading) {
            // Glass background
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            // Grid lines
            Canvas { context, size in
                let cw = size.width / CGFloat(tetrisBoardCols)
                let ch = size.height / CGFloat(tetrisBoardRows)
                for r in 0...tetrisBoardRows {
                    let y = CGFloat(r) * ch
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
                }
                for c in 0...tetrisBoardCols {
                    let x = CGFloat(c) * cw
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(Color.white.opacity(0.04)), lineWidth: 0.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Locked cells
            ForEach(0..<tetrisBoardRows, id: \.self) { r in
                ForEach(0..<tetrisBoardCols, id: \.self) { c in
                    if let color = board[r][c] {
                        TetrisCellView(color: color)
                            .frame(width: tetrisCellSize - 1, height: tetrisCellSize - 1)
                            .offset(
                                x: CGFloat(c) * tetrisCellSize + 0.5,
                                y: CGFloat(r) * tetrisCellSize + 0.5
                            )
                    }
                }
            }

            // Ghost piece
            if let ghost = ghostPiece() {
                ForEach(0..<ghost.count, id: \.self) { i in
                    let cell = ghost[i]
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: tetrisCellSize - 1, height: tetrisCellSize - 1)
                        .offset(
                            x: CGFloat(cell.1) * tetrisCellSize + 0.5,
                            y: CGFloat(cell.0) * tetrisCellSize + 0.5
                        )
                }
            }

            // Current piece
            if let piece = currentPiece {
                ForEach(0..<piece.absoluteCells().count, id: \.self) { i in
                    let cell = piece.absoluteCells()[i]
                    if cell.0 >= 0 {
                        TetrisCellView(color: piece.color)
                            .frame(width: tetrisCellSize - 1, height: tetrisCellSize - 1)
                            .offset(
                                x: CGFloat(cell.1) * tetrisCellSize + 0.5,
                                y: CGFloat(cell.0) * tetrisCellSize + 0.5
                            )
                    }
                }
            }
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Side Panel
    private var sidePanel: some View {
        VStack(spacing: 12) {
            // Next piece preview
            nextPiecePanel

            // Level
            infoCard(label: "LEVEL", value: "\(level)")

            // Moving avg score
            if roundScores.count > 0 {
                infoCard(label: "AVG", value: "\(Int(movingAverage))")
            }

            // History
            if roundScores.count > 0 {
                historyPanel
            }

            Spacer()
        }
        .frame(width: 80)
    }

    private var nextPiecePanel: some View {
        VStack(spacing: 6) {
            Text("NEXT")
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.5))

            TetrisNextPieceView(shape: TetrisTetrominoShape(offsets: TetrisTetrominoDef.all[nextType]?.cells ?? [(0,0)], color: TetrisTetrominoDef.all[nextType]?.color ?? .gray))
                .frame(width: 60, height: 50)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .frame(width: 80)
    }

    private func infoCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    private var historyPanel: some View {
        VStack(spacing: 4) {
            Text("HIST")
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.5))
            ForEach(roundScores.reversed().prefix(5).indices, id: \.self) { i in
                let s = roundScores.reversed().prefix(5)[i]
                Text("\(s)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Start Prompt
    private var startPrompt: some View {
        VStack(spacing: 8) {
            Button(action: startGame) {
                Text("TAP TO START")
                    .font(.system(size: 14, weight: .bold))
                    .tracking(3)
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.4), radius: 12)
                    )
            }
            Text("Swipe: ← → move  ↑ rotate  ↓ drop")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Game Over Overlay
    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .blur(radius: 0)

            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .frame(width: 260, height: 280)
                .overlay(
                    VStack(spacing: 16) {
                        Text("GAME OVER")
                            .font(.system(size: 22, weight: .black))
                            .tracking(3)
                            .foregroundColor(.white)

                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)

                        // Difficulty indicator for next round
                        HStack(spacing: 6) {
                            Text("NEXT:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                            difficultyBadge
                        }

                        if roundScores.count > 1 {
                            Text("Avg: \(Int(movingAverage))")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Button(action: startGame) {
                            Text("PLAY AGAIN")
                                .font(.system(size: 14, weight: .bold))
                                .tracking(2)
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.white)
                                )
                        }
                    }
                    .padding()
                )
        }
    }

    // MARK: - Gesture
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = value.startLocation
                    dragHandled = false
                }
                guard !dragHandled else { return }
                guard gameState == .playing else {
                    dragStart = nil
                    return
                }

                let dx = value.translation.width
                let dy = value.translation.height

                if abs(dx) > 25 || abs(dy) > 25 {
                    dragHandled = true
                    if abs(dx) > abs(dy) {
                        // Horizontal
                        if dx > 0 {
                            moveCurrentPiece(dCol: 1)
                        } else {
                            moveCurrentPiece(dCol: -1)
                        }
                    } else {
                        if dy < 0 {
                            // Swipe up = rotate
                            rotateCurrentPiece()
                        } else {
                            // Swipe down = fast drop
                            fastDrop()
                        }
                    }
                }
            }
            .onEnded { _ in
                dragStart = nil
                dragHandled = false
            }
    }

    // MARK: - Game Logic

    private var movingAverage: Double {
        guard !roundScores.isEmpty else { return 0 }
        let last = Array(roundScores.suffix(5))
        return Double(last.reduce(0, +)) / Double(last.count)
    }

    private func startGame() {
        board = Array(
            repeating: Array(repeating: nil, count: tetrisBoardCols),
            count: tetrisBoardRows
        )
        score = 0
        level = 1
        showGameOver = false
        gameState = .playing
        nextType = TetrisTetrominoType.allCases.randomElement()!
        spawnPiece()
        startTimer()
    }

    private func spawnPiece() {
        let type = nextType
        nextType = TetrisTetrominoType.allCases.randomElement()!
        let piece = TetrisV2Piece.spawn(type: type)
        if !isValid(piece: piece, on: board) {
            // Game over
            endGame()
            return
        }
        currentPiece = piece
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        gameState = .gameOver
        // Append score, keep last 5
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        // Adjust difficulty based on moving average
        difficulty = TetrisDifficulty.from(movingAverage: movingAverage)
        showGameOver = true
    }

    private func startTimer() {
        timer?.invalidate()
        lastTick = Date()
        tickAccumulator = 0

        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            guard gameState == .playing else { return }
            let now = Date()
            let dt = now.timeIntervalSince(lastTick)
            lastTick = now
            tickAccumulator += dt

            let interval = fallInterval
            if tickAccumulator >= interval {
                tickAccumulator -= interval
                stepDown()
            }
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private var fallInterval: Double {
        // Base interval from difficulty, reduced by level
        let base = difficulty.fallInterval
        let speedup = Double(level - 1) * 0.04
        return max(0.1, base - speedup)
    }

    private func stepDown() {
        guard var piece = currentPiece else { return }
        piece.row += 1
        if isValid(piece: piece, on: board) {
            currentPiece = piece
        } else {
            // Lock
            lockPiece()
        }
    }

    private func lockPiece() {
        guard let piece = currentPiece else { return }
        var newBoard = board
        for cell in piece.absoluteCells() {
            let r = cell.0, c = cell.1
            if r >= 0 && r < tetrisBoardRows && c >= 0 && c < tetrisBoardCols {
                newBoard[r][c] = piece.color
            }
        }
        // Clear full rows
        let (clearedBoard, linesCleared) = clearLines(newBoard)
        board = clearedBoard
        if linesCleared > 0 {
            score += linesCleared * 100
            level = max(1, score / 500 + 1)
        }
        currentPiece = nil
        spawnPiece()
    }

    private func clearLines(_ board: TetrisBoard) -> (TetrisBoard, Int) {
        var newBoard = board.filter { row in row.contains(where: { $0 == nil }) }
        let cleared = tetrisBoardRows - newBoard.count
        let emptyRows = Array(
            repeating: Array(repeating: nil as Color?, count: tetrisBoardCols),
            count: cleared
        )
        newBoard = emptyRows + newBoard
        return (newBoard, cleared)
    }

    private func moveCurrentPiece(dCol: Int) {
        guard var piece = currentPiece else { return }
        piece.col += dCol
        if isValid(piece: piece, on: board) {
            currentPiece = piece
        }
    }

    private func rotateCurrentPiece() {
        guard let piece = currentPiece else { return }
        let rotated = piece.rotated()
        // Wall kicks: try offsets 0, -1, +1, -2, +2
        for offset in [0, -1, 1, -2, 2] {
            var kicked = rotated
            kicked.col += offset
            if isValid(piece: kicked, on: board) {
                currentPiece = kicked
                return
            }
        }
    }

    private func fastDrop() {
        guard var piece = currentPiece else { return }
        while true {
            var next = piece
            next.row += 1
            if isValid(piece: next, on: board) {
                piece = next
            } else {
                break
            }
        }
        currentPiece = piece
        lockPiece()
    }

    private func ghostPiece() -> [(Int, Int)]? {
        guard var piece = currentPiece, gameState == .playing else { return nil }
        while true {
            var next = piece
            next.row += 1
            if isValid(piece: next, on: board) {
                piece = next
            } else {
                break
            }
        }
        return piece.absoluteCells()
    }

    private func isValid(piece: TetrisV2Piece, on board: TetrisBoard) -> Bool {
        for cell in piece.absoluteCells() {
            let r = cell.0, c = cell.1
            if c < 0 || c >= tetrisBoardCols { return false }
            if r >= tetrisBoardRows { return false }
            if r >= 0 && board[r][c] != nil { return false }
        }
        return true
    }
}

// MARK: - Cell View
struct TetrisCellView: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
            // Gloss highlight
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.18))
                .padding(3)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipped()
        }
    }
}

// MARK: - Next Piece Preview

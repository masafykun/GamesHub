import SwiftUI

// MARK: - Constants

private let tetrisBoardCols = 10
private let tetrisBoardRows = 20

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

struct TetrisPiece {
    var row: Int
    var col: Int
    var cells: [(Int, Int)]
    var color: Color

    func absoluteCells() -> [(Int, Int)] {
        cells.map { ($0.0 + row, $0.1 + col) }
    }

    static func spawn(type: TetrisTetrominoType) -> TetrisPiece {
        guard let def = TetrisTetrominoDef.all[type] else {
            return TetrisPiece(row: 0, col: 4, cells: [(0,0)], color: .gray)
        }
        return TetrisPiece(row: 0, col: 3, cells: def.cells, color: def.color)
    }

    func rotated() -> TetrisPiece {
        let maxRow = cells.map { $0.0 }.max() ?? 0
        let rotatedCells = cells.map { (r, c) -> (Int, Int) in (c, maxRow - r) }
        return TetrisPiece(row: row, col: col, cells: rotatedCells, color: color)
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
        case .hard: return 0.32
        }
    }

    static func from(movingAverage: Double) -> TetrisDifficulty {
        if movingAverage < 300 { return .easy }
        if movingAverage < 800 { return .medium }
        return .hard
    }
}

enum TetrisGameState {
    case idle, playing, gameOver
}

typealias TetrisBoard = [[Color?]]

// MARK: - Main View

struct TetrisView: View {
    @State private var board: TetrisBoard = Array(
        repeating: Array(repeating: nil, count: tetrisBoardCols),
        count: tetrisBoardRows
    )
    @State private var currentPiece: TetrisPiece? = nil
    @State private var nextType: TetrisTetrominoType = TetrisTetrominoType.allCases.randomElement()!
    @State private var score: Int = 0
    @State private var lines: Int = 0
    @State private var level: Int = 1
    @State private var gameState: TetrisGameState = .idle
    @State private var roundScores: [Int] = []
    @State private var difficulty: TetrisDifficulty = .easy
    @State private var timer: Timer? = nil
    @State private var tickAccumulator: Double = 0
    @State private var lastTick: Date = Date()

    @AppStorage("tetrisBestScore") private var bestScore: Int = 0

    @State private var dragHandled: Bool = false

    var body: some View {
        GeometryReader { geo in
            // Board is sized to fit next to the side panel, so it never clips.
            let panelWidth: CGFloat = 78
            let available = geo.size.width - panelWidth - 40
            let cellSize = min(available / CGFloat(tetrisBoardCols),
                               (geo.size.height - 130) / CGFloat(tetrisBoardRows))

            ZStack {
                LinearGradient(
                    colors: [Color(white: 0.05), Color(white: 0.12), Color(white: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 12) {
                    headerBar
                        .padding(.horizontal, 16)

                    HStack(alignment: .top, spacing: 12) {
                        boardView(cellSize: cellSize)
                            .gesture(swipeGesture)
                        sidePanel
                            .frame(width: panelWidth)
                    }
                    .padding(.horizontal, 14)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 14)

                if gameState == .idle {
                    startOverlay
                } else if gameState == .gameOver {
                    gameOverOverlay
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

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
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("LINES \(lines)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(2)
                }

                Spacer()
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
                    .overlay(Capsule().strokeBorder(difficulty.badgeColor, lineWidth: 1))
            )
    }

    // MARK: - Board

    private func boardView(cellSize: CGFloat) -> some View {
        let boardWidth = CGFloat(tetrisBoardCols) * cellSize
        let boardHeight = CGFloat(tetrisBoardRows) * cellSize

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            Canvas { context, size in
                let cw = size.width / CGFloat(tetrisBoardCols)
                let ch = size.height / CGFloat(tetrisBoardRows)
                var path = Path()
                for r in 0...tetrisBoardRows {
                    path.move(to: CGPoint(x: 0, y: CGFloat(r) * ch))
                    path.addLine(to: CGPoint(x: size.width, y: CGFloat(r) * ch))
                }
                for c in 0...tetrisBoardCols {
                    path.move(to: CGPoint(x: CGFloat(c) * cw, y: 0))
                    path.addLine(to: CGPoint(x: CGFloat(c) * cw, y: size.height))
                }
                context.stroke(path, with: .color(Color.white.opacity(0.05)), lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach(0..<tetrisBoardRows, id: \.self) { r in
                ForEach(0..<tetrisBoardCols, id: \.self) { c in
                    if let color = board[r][c] {
                        TetrisCellView(color: color)
                            .frame(width: cellSize - 1, height: cellSize - 1)
                            .offset(x: CGFloat(c) * cellSize + 0.5, y: CGFloat(r) * cellSize + 0.5)
                    }
                }
            }

            if let ghost = ghostPiece() {
                ForEach(0..<ghost.count, id: \.self) { i in
                    let cell = ghost[i]
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        .frame(width: cellSize - 1, height: cellSize - 1)
                        .offset(x: CGFloat(cell.1) * cellSize + 0.5, y: CGFloat(cell.0) * cellSize + 0.5)
                }
            }

            if let piece = currentPiece {
                let cells = piece.absoluteCells()
                ForEach(0..<cells.count, id: \.self) { i in
                    let cell = cells[i]
                    if cell.0 >= 0 {
                        TetrisCellView(color: piece.color)
                            .frame(width: cellSize - 1, height: cellSize - 1)
                            .offset(x: CGFloat(cell.1) * cellSize + 0.5, y: CGFloat(cell.0) * cellSize + 0.5)
                    }
                }
            }
        }
        .frame(width: boardWidth, height: boardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Side panel

    private var sidePanel: some View {
        VStack(spacing: 10) {
            VStack(spacing: 6) {
                Text("NEXT")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(2)
                    .foregroundColor(.white.opacity(0.5))
                TetrisNextPieceView(
                    offsets: TetrisTetrominoDef.all[nextType]?.cells ?? [(0, 0)],
                    color: TetrisTetrominoDef.all[nextType]?.color ?? .gray
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(panelBackground)

            infoCard(label: "LEVEL", value: "\(level)")
            infoCard(label: "BEST", value: "\(bestScore)")

            if !roundScores.isEmpty {
                infoCard(label: "AVG", value: "\(Int(movingAverage))")
            }

            Spacer(minLength: 0)
        }
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
    }

    private func infoCard(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(panelBackground)
    }

    // MARK: - Overlays

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("TETRIS LITE")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Swipe ← → to move\nSwipe ↑ to rotate · ↓ to drop")
                    .font(.system(size: 13, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.6))
                Button(action: startGame) {
                    Text("TAP TO START")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(3)
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white).shadow(color: .white.opacity(0.4), radius: 12))
                }
            }
            .padding(30)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("GAME OVER")
                    .font(.system(size: 22, weight: .black))
                    .tracking(3)
                    .foregroundColor(.white)

                Text("\(score)")
                    .font(.system(size: 46, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Text("\(lines) lines · best \(bestScore)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))

                HStack(spacing: 6) {
                    Text("NEXT:")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                    difficultyBadge
                }

                Button(action: startGame) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 14, weight: .bold))
                        .tracking(2)
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.white))
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }

    // MARK: - Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard gameState == .playing, !dragHandled else { return }
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > 24 || abs(dy) > 24 {
                    dragHandled = true
                    if abs(dx) > abs(dy) {
                        moveCurrentPiece(dCol: dx > 0 ? 1 : -1)
                    } else if dy < 0 {
                        rotateCurrentPiece()
                    } else {
                        hardDrop()
                    }
                }
            }
            .onEnded { _ in dragHandled = false }
    }

    // MARK: - Logic

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
        lines = 0
        level = 1
        gameState = .playing
        nextType = TetrisTetrominoType.allCases.randomElement()!
        spawnPiece()
        startTimer()
    }

    private func spawnPiece() {
        let type = nextType
        nextType = TetrisTetrominoType.allCases.randomElement()!
        let piece = TetrisPiece.spawn(type: type)
        guard isValid(piece: piece, on: board) else {
            endGame()
            return
        }
        currentPiece = piece
    }

    private func endGame() {
        timer?.invalidate()
        timer = nil
        currentPiece = nil
        gameState = .gameOver
        bestScore = max(bestScore, score)
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }
        difficulty = TetrisDifficulty.from(movingAverage: movingAverage)
    }

    private func startTimer() {
        timer?.invalidate()
        lastTick = Date()
        tickAccumulator = 0

        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            guard gameState == .playing else { return }
            let now = Date()
            let dt = min(now.timeIntervalSince(lastTick), 0.25)
            lastTick = now
            tickAccumulator += dt
            if tickAccumulator >= fallInterval {
                tickAccumulator = 0
                stepDown()
            }
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    private var fallInterval: Double {
        max(0.1, difficulty.fallInterval - Double(level - 1) * 0.05)
    }

    private func stepDown() {
        guard var piece = currentPiece else { return }
        piece.row += 1
        if isValid(piece: piece, on: board) {
            currentPiece = piece
        } else {
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
        let (clearedBoard, linesCleared) = clearLines(newBoard)
        withAnimation(.easeOut(duration: 0.12)) {
            board = clearedBoard
        }
        if linesCleared > 0 {
            // More lines at once pays much better: 100 / 300 / 600 / 1000.
            let table = [0, 100, 300, 600, 1000]
            score += table[min(linesCleared, 4)] * level
            lines += linesCleared
            level = max(1, lines / 8 + 1)
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
        for offset in [0, -1, 1, -2, 2] {
            var kicked = rotated
            kicked.col += offset
            if isValid(piece: kicked, on: board) {
                currentPiece = kicked
                return
            }
        }
    }

    private func hardDrop() {
        guard var piece = currentPiece else { return }
        var dropped = 0
        while true {
            var next = piece
            next.row += 1
            if isValid(piece: next, on: board) {
                piece = next
                dropped += 1
            } else {
                break
            }
        }
        currentPiece = piece
        score += dropped * 2
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

    private func isValid(piece: TetrisPiece, on board: TetrisBoard) -> Bool {
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
                        colors: [color.opacity(0.95), color.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
        }
    }
}

// MARK: - Next Piece Preview

struct TetrisNextPieceView: View {
    let offsets: [(Int, Int)]
    let color: Color

    private let cellSize: CGFloat = 12

    var body: some View {
        Canvas { context, _ in
            let minCol = offsets.map { $0.1 }.min() ?? 0
            let minRow = offsets.map { $0.0 }.min() ?? 0
            for (r, c) in offsets {
                let rect = CGRect(
                    x: CGFloat(c - minCol) * cellSize,
                    y: CGFloat(r - minRow) * cellSize,
                    width: cellSize - 1.5,
                    height: cellSize - 1.5
                )
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
            }
        }
        .frame(width: cellSize * 4, height: cellSize * 2)
    }
}

#Preview {
    TetrisView()
}

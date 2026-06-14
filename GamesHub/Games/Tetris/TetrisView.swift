import SwiftUI

// MARK: - Tetromino Definitions

struct TetrisTetrominoShape {
    let offsets: [(Int, Int)] // (row, col)
    let color: Color

    static let all: [TetrisTetrominoShape] = [
        // I
        TetrisTetrominoShape(offsets: [(0,0),(0,1),(0,2),(0,3)], color: .cyan),
        // O
        TetrisTetrominoShape(offsets: [(0,0),(0,1),(1,0),(1,1)], color: .yellow),
        // T
        TetrisTetrominoShape(offsets: [(0,1),(1,0),(1,1),(1,2)], color: .purple),
        // S
        TetrisTetrominoShape(offsets: [(0,1),(0,2),(1,0),(1,1)], color: .green),
        // Z
        TetrisTetrominoShape(offsets: [(0,0),(0,1),(1,1),(1,2)], color: .red),
        // J
        TetrisTetrominoShape(offsets: [(0,0),(1,0),(1,1),(1,2)], color: .blue),
        // L
        TetrisTetrominoShape(offsets: [(0,2),(1,0),(1,1),(1,2)], color: .orange),
    ]
}

// MARK: - Tetromino (active piece)

struct TetrisPiece {
    var cells: [(Int, Int)] // (row, col) absolute positions on grid
    var color: Color

    /// Rotate cells 90 degrees clockwise around their bounding center
    func rotated() -> TetrisPiece {
        let minRow = cells.map { $0.0 }.min()!
        let minCol = cells.map { $0.1 }.min()!
        let maxRow = cells.map { $0.0 }.max()!
        let maxCol = cells.map { $0.1 }.max()!
        let pivotRow = (minRow + maxRow)
        let pivotCol = (minCol + maxCol)
        // Rotation formula: (r,c) -> (c - pivotCol/2 + pivotRow/2, pivotRow - r + pivotCol/2 - pivotRow/2)
        // Simplified: relative to center pivot
        let rotatedCells = cells.map { (r, c) -> (Int, Int) in
            let relR = 2 * r - pivotRow
            let relC = 2 * c - pivotCol
            let newRelR = relC
            let newRelC = -relR
            let newR = (newRelR + pivotRow) / 2
            let newC = (newRelC + pivotCol) / 2
            return (newR, newC)
        }
        return TetrisPiece(cells: rotatedCells, color: color)
    }

    func moved(rowDelta: Int, colDelta: Int) -> TetrisPiece {
        TetrisPiece(cells: cells.map { ($0.0 + rowDelta, $0.1 + colDelta) }, color: color)
    }
}

// MARK: - Game State

enum TetrisGamePhase {
    case idle, playing, gameOver
}

struct TetrisCell {
    var filled: Bool
    var color: Color
}

class TetrisGameEngine: ObservableObject {
    static let rows = 20
    static let cols = 10

    @Published var grid: [[TetrisCell]] = TetrisGameEngine.makeEmptyGrid()
    @Published var currentPiece: TetrisPiece? = nil
    @Published var nextShape: TetrisTetrominoShape = TetrisTetrominoShape.all.randomElement()!
    @Published var score: Int = 0
    @Published var level: Int = 1
    @Published var phase: TetrisGamePhase = .idle

    private var timer: Timer?
    private var tickCount: Int = 0
    private var dropInterval: Int = 30 // ticks at 60fps => ~0.5s

    static func makeEmptyGrid() -> [[TetrisCell]] {
        Array(repeating: Array(repeating: TetrisCell(filled: false, color: .clear), count: cols), count: rows)
    }

    func startGame() {
        grid = TetrisGameEngine.makeEmptyGrid()
        score = 0
        level = 1
        dropInterval = 30
        tickCount = 0
        phase = .playing
        nextShape = TetrisTetrominoShape.all.randomElement()!
        spawnPiece()
        startTimer()
    }

    func endGame() {
        phase = .gameOver
        timer?.invalidate()
        timer = nil
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        guard phase == .playing else { return }
        tickCount += 1
        if tickCount >= dropInterval {
            tickCount = 0
            dropPieceByOne()
        }
    }

    private func spawnPiece() {
        let shape = nextShape
        nextShape = TetrisTetrominoShape.all.randomElement()!
        let spawnCol = TetrisGameEngine.cols / 2 - 2
        let piece = TetrisPiece(
            cells: shape.offsets.map { ($0.0, $0.1 + spawnCol) },
            color: shape.color
        )
        if isColliding(piece) {
            endGame()
        } else {
            currentPiece = piece
        }
    }

    private func dropPieceByOne() {
        guard let piece = currentPiece else { return }
        let moved = piece.moved(rowDelta: 1, colDelta: 0)
        if isColliding(moved) {
            lockPiece(piece)
        } else {
            currentPiece = moved
        }
    }

    private func isColliding(_ piece: TetrisPiece) -> Bool {
        for (r, c) in piece.cells {
            if r < 0 || r >= TetrisGameEngine.rows { return true }
            if c < 0 || c >= TetrisGameEngine.cols { return true }
            if grid[r][c].filled { return true }
        }
        return false
    }

    private func lockPiece(_ piece: TetrisPiece) {
        for (r, c) in piece.cells {
            if r >= 0 && r < TetrisGameEngine.rows && c >= 0 && c < TetrisGameEngine.cols {
                grid[r][c] = TetrisCell(filled: true, color: piece.color)
            }
        }
        currentPiece = nil
        clearLines()
        spawnPiece()
    }

    private func clearLines() {
        var linesCleared = 0
        var newGrid = TetrisGameEngine.makeEmptyGrid()
        var writeRow = TetrisGameEngine.rows - 1
        for r in stride(from: TetrisGameEngine.rows - 1, through: 0, by: -1) {
            if grid[r].allSatisfy({ $0.filled }) {
                linesCleared += 1
            } else {
                newGrid[writeRow] = grid[r]
                writeRow -= 1
            }
        }
        if linesCleared > 0 {
            grid = newGrid
            score += linesCleared * 100
            level = max(1, score / 500 + 1)
            dropInterval = max(6, 30 - (level - 1) * 3)
        }
    }

    // MARK: - Input

    func moveLeft() {
        guard let piece = currentPiece else { return }
        let moved = piece.moved(rowDelta: 0, colDelta: -1)
        if !isColliding(moved) { currentPiece = moved }
    }

    func moveRight() {
        guard let piece = currentPiece else { return }
        let moved = piece.moved(rowDelta: 0, colDelta: 1)
        if !isColliding(moved) { currentPiece = moved }
    }

    func rotate() {
        guard let piece = currentPiece else { return }
        let rotated = piece.rotated()
        // Wall kick: try as-is, then shift right, then shift left
        if !isColliding(rotated) {
            currentPiece = rotated
        } else if !isColliding(rotated.moved(rowDelta: 0, colDelta: 1)) {
            currentPiece = rotated.moved(rowDelta: 0, colDelta: 1)
        } else if !isColliding(rotated.moved(rowDelta: 0, colDelta: -1)) {
            currentPiece = rotated.moved(rowDelta: 0, colDelta: -1)
        } else if !isColliding(rotated.moved(rowDelta: 0, colDelta: 2)) {
            currentPiece = rotated.moved(rowDelta: 0, colDelta: 2)
        } else if !isColliding(rotated.moved(rowDelta: 0, colDelta: -2)) {
            currentPiece = rotated.moved(rowDelta: 0, colDelta: -2)
        }
    }

    func fastDrop() {
        guard phase == .playing else { return }
        while let piece = currentPiece {
            let moved = piece.moved(rowDelta: 1, colDelta: 0)
            if isColliding(moved) {
                lockPiece(piece)
                break
            } else {
                currentPiece = moved
            }
        }
    }

    func ghostCells() -> [(row: Int, col: Int)] {
        guard var piece = currentPiece, phase == .playing else { return [] }
        while true {
            let moved = piece.moved(rowDelta: 1, colDelta: 0)
            if isColliding(moved) { break }
            piece = moved
        }
        return piece.cells.map { (row: $0.0, col: $0.1) }
    }
}

// MARK: - Views

struct TetrisGridView: View {
    let grid: [[TetrisCell]]
    let currentPiece: TetrisPiece?

    private static let cols = TetrisGameEngine.cols
    private static let rows = TetrisGameEngine.rows

    var activeCells: Set<String> {
        var s = Set<String>()
        if let piece = currentPiece {
            for (r, c) in piece.cells {
                s.insert("\(r),\(c)")
            }
        }
        return s
    }

    var activeColorMap: [String: Color] {
        var m = [String: Color]()
        if let piece = currentPiece {
            for (r, c) in piece.cells {
                m["\(r),\(c)"] = piece.color
            }
        }
        return m
    }

    var body: some View {
        GeometryReader { geo in
            let cellSize = min(geo.size.width / CGFloat(TetrisGridView.cols),
                               geo.size.height / CGFloat(TetrisGridView.rows))
            Canvas { context, size in
                for r in 0..<TetrisGridView.rows {
                    for c in 0..<TetrisGridView.cols {
                        let key = "\(r),\(c)"
                        let x = CGFloat(c) * cellSize
                        let y = CGFloat(r) * cellSize
                        let rect = CGRect(x: x, y: y, width: cellSize - 1, height: cellSize - 1)

                        if let color = activeColorMap[key] {
                            context.fill(Path(rect), with: .color(color))
                        } else if grid[r][c].filled {
                            context.fill(Path(rect), with: .color(grid[r][c].color))
                        } else {
                            context.fill(Path(rect), with: .color(Color.white.opacity(0.05)))
                        }
                    }
                }
            }
            .frame(width: CGFloat(TetrisGridView.cols) * cellSize,
                   height: CGFloat(TetrisGridView.rows) * cellSize)
        }
    }
}

struct TetrisNextPieceView: View {
    let shape: TetrisTetrominoShape
    private let cellSize: CGFloat = 14
    private let previewRows = 2
    private let previewCols = 4

    var body: some View {
        Canvas { context, size in
            for (r, c) in shape.offsets {
                let rect = CGRect(
                    x: CGFloat(c) * cellSize,
                    y: CGFloat(r) * cellSize,
                    width: cellSize - 1,
                    height: cellSize - 1
                )
                context.fill(Path(rect), with: .color(shape.color))
            }
        }
        .frame(width: CGFloat(previewCols) * cellSize, height: CGFloat(previewRows) * cellSize)
    }
}

// MARK: - Main View

struct TetrisView: View {
    @StateObject private var engine = TetrisGameEngine()

    @State private var dragStart: CGPoint = .zero
    private let swipeThreshold: CGFloat = 20

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TETRIS LITE")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("SCORE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.gray)
                        Text("\(engine.score)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                        Text("LVL \(engine.level)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.yellow)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(alignment: .top, spacing: 12) {
                    // Game grid
                    GeometryReader { geo in
                        let cols = TetrisGameEngine.cols
                        let rows = TetrisGameEngine.rows
                        let cellW = geo.size.width / CGFloat(cols)
                        let cellH = geo.size.height / CGFloat(rows)
                        let cellSize = min(cellW, cellH)
                        let gridW = cellSize * CGFloat(cols)
                        let gridH = cellSize * CGFloat(rows)

                        ZStack {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                .frame(width: gridW, height: gridH)

                            TetrisGridView(grid: engine.grid, currentPiece: engine.currentPiece)
                                .frame(width: gridW, height: gridH)
                        }
                        .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    }
                    .gesture(
                        DragGesture(minimumDistance: swipeThreshold)
                            .onChanged { value in
                                if dragStart == .zero {
                                    dragStart = value.startLocation
                                }
                            }
                            .onEnded { value in
                                dragStart = .zero
                                guard engine.phase == .playing else { return }
                                let dx = value.translation.width
                                let dy = value.translation.height
                                if abs(dx) > abs(dy) {
                                    // Horizontal swipe
                                    if dx < -swipeThreshold {
                                        engine.moveLeft()
                                    } else if dx > swipeThreshold {
                                        engine.moveRight()
                                    }
                                } else {
                                    // Vertical swipe
                                    if dy < -swipeThreshold {
                                        engine.rotate()
                                    } else if dy > swipeThreshold {
                                        engine.fastDrop()
                                    }
                                }
                            }
                    )

                    // Side panel
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NEXT")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            TetrisNextPieceView(shape: engine.nextShape)
                                .padding(4)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(4)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONTROLS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.gray)
                            Group {
                                Text("← → Move")
                                Text("↑ Rotate")
                                Text("↓ Drop")
                            }
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()
                    }
                    .frame(width: 72)
                }
                .padding(.horizontal, 16)

                // Bottom controls
                VStack(spacing: 10) {
                    if engine.phase == .idle {
                        Button(action: { engine.startGame() }) {
                            Text("START GAME")
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(8)
                        }
                    } else if engine.phase == .gameOver {
                        VStack(spacing: 8) {
                            Text("GAME OVER")
                                .font(.system(size: 18, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                            Text("Score: \(engine.score)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Button(action: { engine.startGame() }) {
                                Text("PLAY AGAIN")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 28)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .cornerRadius(8)
                            }
                        }
                    } else {
                        // Arrow buttons for playing
                        HStack(spacing: 20) {
                            Button(action: { engine.moveLeft() }) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                            }
                            Button(action: { engine.rotate() }) {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                            }
                            Button(action: { engine.fastDrop() }) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                            }
                            Button(action: { engine.moveRight() }) {
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(10)
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
            }
        }
    }
}

// MARK: - Preview

struct TetrisView_Previews: PreviewProvider {
    static var previews: some View {
        TetrisView()
    }
}

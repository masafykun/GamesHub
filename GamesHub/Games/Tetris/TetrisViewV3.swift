import SwiftUI

// MARK: - Models

// MARK: - LCG Generator

struct TetrisLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        if s == 0 { s = 1 }
        // Run one step to mix seed
        s = s &* 6364136223846793005 &+ 1442695040888963407
        state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Int) -> Int {
        Int(next() % UInt64(range))
    }
}

// MARK: - Game Engine

// MARK: - Board Canvas View

struct TetrisBoardView: View {
    let grid: [[TetrisCell]]
    let currentPiece: TetrisPiece?
    let ghostCells: [(row: Int, col: Int)]
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, _ in
            let rows = TetrisGameEngine.rows
            let cols = TetrisGameEngine.cols

            for r in 0..<rows {
                for c in 0..<cols {
                    let rect = CGRect(
                        x: CGFloat(c) * cellSize + 1,
                        y: CGFloat(r) * cellSize + 1,
                        width: cellSize - 2,
                        height: cellSize - 2
                    )
                    let cell = grid[r][c]
                    if cell.filled {
                        context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(cell.color))
                        // Shine highlight
                        let shine = CGRect(x: rect.minX + 2, y: rect.minY + 2,
                                          width: rect.width * 0.45, height: rect.height * 0.45)
                        context.fill(Path(roundedRect: shine, cornerRadius: 2), with: .color(.white.opacity(0.38)))
                        context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                                       with: .color(.white.opacity(0.35)), lineWidth: 1)
                    } else {
                        context.fill(Path(roundedRect: rect, cornerRadius: 2),
                                     with: .color(Color(.systemGray5).opacity(0.55)))
                    }
                }
            }

            // Ghost piece
            for cell in ghostCells {
                guard cell.row >= 0 else { continue }
                let rect = CGRect(
                    x: CGFloat(cell.col) * cellSize + 1,
                    y: CGFloat(cell.row) * cellSize + 1,
                    width: cellSize - 2,
                    height: cellSize - 2
                )
                context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                               with: .color(.white.opacity(0.28)), lineWidth: 1.5)
            }

            // Current piece
            if let piece = currentPiece {
                for cell in piece.cells.map { (row: $0.0, col: $0.1) } {
                    guard cell.row >= 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(cell.col) * cellSize + 1,
                        y: CGFloat(cell.row) * cellSize + 1,
                        width: cellSize - 2,
                        height: cellSize - 2
                    )
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(piece.color))
                    let shine = CGRect(x: rect.minX + 2, y: rect.minY + 2,
                                      width: rect.width * 0.45, height: rect.height * 0.45)
                    context.fill(Path(roundedRect: shine, cornerRadius: 2), with: .color(.white.opacity(0.45)))
                    context.stroke(Path(roundedRect: rect, cornerRadius: 3),
                                   with: .color(.white.opacity(0.5)), lineWidth: 1)
                }
            }
        }
        .frame(
            width: cellSize * CGFloat(TetrisGameEngine.cols),
            height: cellSize * CGFloat(TetrisGameEngine.rows)
        )
    }
}

// MARK: - Next Piece Preview

// MARK: - Stat Box

struct TetrisStatBox: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 20, weight: .black, design: .monospaced))
                .foregroundColor(valueColor)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .neumorphicCard(radius: 12)
    }
}

// MARK: - Hint Label

struct TetrisHintLabel: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .neumorphicCard(radius: 10)
    }
}

// MARK: - Game Over Overlay

struct TetrisGameOverOverlay: View {
    let score: Int
    let seedInt: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("GAME OVER")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.primary)

                VStack(spacing: 4) {
                    Text("SCORE")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 38, weight: .black, design: .monospaced))
                        .foregroundColor(.primary)
                }

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.95))

                Button(action: onRestart) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 14)
                }
            }
            .padding(28)
            .neumorphicCard(radius: 20)
            .padding(40)
        }
    }
}

// MARK: - Main View

struct TetrisViewV3: View {
    @State var seedInt: Int = 1
    @StateObject private var engine = TetrisGameEngine()
    @State private var hasMoved: Bool = false

    private let dragThreshold: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.height < 600
            let sidebarWidth: CGFloat = 82
            let hPad: CGFloat = 16
            let availableWidth = geo.size.width - sidebarWidth - hPad * 2 - 10
            let maxBoardH = geo.size.height * (isCompact ? 0.62 : 0.67)
            let cellByW = availableWidth / CGFloat(TetrisGameEngine.cols)
            let cellByH = maxBoardH / CGFloat(TetrisGameEngine.rows)
            let cellSize = min(cellByW, cellByH)

            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top stats bar
                    HStack(spacing: 8) {
                        TetrisStatBox(label: "SCORE", value: "\(engine.score)")
                        TetrisStatBox(
                            label: "SEED",
                            value: "#\(seedInt)",
                            valueColor: Color(red: 0.3, green: 0.6, blue: 0.95)
                        )
                        TetrisStatBox(label: "LEVEL", value: "\(engine.level)")
                    }
                    .padding(.horizontal, hPad)
                    .padding(.top, isCompact ? 8 : 14)

                    Spacer(minLength: 6)

                    // Board + sidebar
                    HStack(alignment: .top, spacing: 10) {
                        // Board
                        TetrisBoardView(
                            grid: engine.grid,
                            currentPiece: engine.currentPiece,
                            ghostCells: engine.ghostCells(),
                            cellSize: cellSize
                        )
                        .padding(7)
                        .neumorphicCard(radius: 12)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 4)
                                .onChanged { value in
                                    guard !hasMoved else { return }
                                    let dx = value.translation.width
                                    let dy = value.translation.height
                                    if abs(dx) > dragThreshold && abs(dx) > abs(dy) {
                                        hasMoved = true
                                        if dx > 0 { engine.moveRight() } else { engine.moveLeft() }
                                    } else if dy < -dragThreshold && abs(dy) > abs(dx) {
                                        hasMoved = true
                                        engine.rotate()
                                    } else if dy > dragThreshold && abs(dy) > abs(dx) {
                                        hasMoved = true
                                        engine.fastDrop()
                                    }
                                }
                                .onEnded { _ in hasMoved = false }
                        )

                        // Sidebar
                        VStack(spacing: 10) {
                            VStack(spacing: 4) {
                                Text("NEXT")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                TetrisNextPieceView(shape: engine.nextShape)
                            }

                            VStack(spacing: 4) {
                                Text("LINES")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                Text("\(engine.score / 100)")
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.primary)
                                    .frame(width: 70, height: 34)
                                    .neumorphicCard(radius: 10)
                            }

                            Spacer()
                        }
                        .frame(width: sidebarWidth)
                    }
                    .padding(.horizontal, hPad)

                    Spacer(minLength: 6)

                    // Seed banner
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.95))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 5)
                        .neumorphicCard(radius: 18)

                    Spacer(minLength: 4)

                    // Hints
                    HStack(spacing: 5) {
                        TetrisHintLabel(symbol: "arrow.left.arrow.right", text: "MOVE")
                        TetrisHintLabel(symbol: "arrow.up", text: "ROTATE")
                        TetrisHintLabel(symbol: "arrow.down.to.line", text: "DROP")
                    }
                    .padding(.horizontal, hPad)
                    .padding(.bottom, isCompact ? 8 : 14)
                }
            }
            .overlay {
                if engine.phase == .gameOver {
                    TetrisGameOverOverlay(score: engine.score, seedInt: seedInt) {
                        seedInt += 1
                        engine.startGame()
                    }
                }
            }
        }
        .onAppear { engine.startGame() }
        .onDisappear { engine.endGame() }
    }
}

import SwiftUI

// MARK: - Private Model Types

private enum CRPlayer {
    case none, red, blue

    var color: Color {
        switch self {
        case .none: return .clear
        case .red:  return .red
        case .blue: return Color(red: 0.2, green: 0.5, blue: 1.0)
        }
    }
}

private struct CRCell {
    var owner: CRPlayer = .none
    var atoms: Int = 0

    func criticalMass(row: Int, col: Int, rows: Int, cols: Int) -> Int {
        var neighbors = 0
        if row > 0        { neighbors += 1 }
        if row < rows - 1 { neighbors += 1 }
        if col > 0        { neighbors += 1 }
        if col < cols - 1 { neighbors += 1 }
        return neighbors
    }
}

private class CRGameModel: ObservableObject {
    static let rows = 6
    static let cols = 6

    @Published var grid: [[CRCell]] = Array(
        repeating: Array(repeating: CRCell(), count: cols),
        count: rows
    )
    @Published var currentPlayer: CRPlayer = .red
    @Published var gameOver: Bool = false
    @Published var winner: CRPlayer = .none
    @Published var isAIThinking: Bool = false
    @Published var moveCount: Int = 0

    func canTap(row: Int, col: Int) -> Bool {
        let cell = grid[row][col]
        return cell.owner == .none || cell.owner == currentPlayer
    }

    func tap(row: Int, col: Int) {
        guard !gameOver, !isAIThinking else { return }
        guard canTap(row: row, col: col) else { return }

        var newGrid = grid
        newGrid[row][col].owner = currentPlayer
        newGrid[row][col].atoms += 1
        grid = newGrid
        moveCount += 1

        explodeIfNeeded()
        checkWinner()

        if !gameOver {
            currentPlayer = .blue
            isAIThinking = true
        }
    }

    func aiMove() {
        guard !gameOver else { isAIThinking = false; return }

        let validCells = allCells().filter { r, c in
            grid[r][c].owner == .none || grid[r][c].owner == .blue
        }

        // Prefer cells about to explode (strategic move)
        let explosive = validCells.filter { r, c in
            let mass = grid[r][c].criticalMass(row: r, col: c,
                                                rows: CRGameModel.rows, cols: CRGameModel.cols)
            return grid[r][c].atoms == mass - 1 && grid[r][c].owner == .blue
        }

        let choice = explosive.randomElement() ?? validCells.randomElement()

        if let (r, c) = choice {
            var newGrid = grid
            newGrid[r][c].owner = .blue
            newGrid[r][c].atoms += 1
            grid = newGrid
            moveCount += 1
            explodeIfNeeded()
            checkWinner()
        }

        if !gameOver {
            currentPlayer = .red
        }
        isAIThinking = false
    }

    private func allCells() -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        for r in 0..<CRGameModel.rows {
            for c in 0..<CRGameModel.cols {
                result.append((r, c))
            }
        }
        return result
    }

    private func explodeIfNeeded() {
        var changed = true
        var iterations = 0
        while changed && iterations < 200 {
            changed = false
            iterations += 1
            var newGrid = grid
            for r in 0..<CRGameModel.rows {
                for c in 0..<CRGameModel.cols {
                    let mass = newGrid[r][c].criticalMass(row: r, col: c,
                                                          rows: CRGameModel.rows, cols: CRGameModel.cols)
                    if newGrid[r][c].atoms >= mass && newGrid[r][c].owner != .none {
                        let explodingOwner = newGrid[r][c].owner
                        newGrid[r][c].atoms -= mass
                        if newGrid[r][c].atoms == 0 { newGrid[r][c].owner = .none }

                        let neighbors = getNeighbors(row: r, col: c)
                        for (nr, nc) in neighbors {
                            newGrid[nr][nc].owner = explodingOwner
                            newGrid[nr][nc].atoms += 1
                        }
                        changed = true
                    }
                }
            }
            grid = newGrid
        }
    }

    private func getNeighbors(row: Int, col: Int) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        if row > 0        { result.append((row - 1, col)) }
        if row < CRGameModel.rows - 1 { result.append((row + 1, col)) }
        if col > 0        { result.append((row, col - 1)) }
        if col < CRGameModel.cols - 1 { result.append((row, col + 1)) }
        return result
    }

    private func checkWinner() {
        guard moveCount >= 2 else { return }

        let redCells = allCells().filter { r, c in grid[r][c].owner == .red }
        let blueCells = allCells().filter { r, c in grid[r][c].owner == .blue }

        if redCells.isEmpty && moveCount > 1 {
            gameOver = true
            winner = .blue
        } else if blueCells.isEmpty && moveCount > 1 {
            gameOver = true
            winner = .red
        }
    }

    func reset() {
        grid = Array(repeating: Array(repeating: CRCell(), count: CRGameModel.cols),
                     count: CRGameModel.rows)
        currentPlayer = .red
        gameOver = false
        winner = .none
        isAIThinking = false
        moveCount = 0
    }
}

// MARK: - Main View

struct ChainReactionView: View {
    @StateObject private var model = CRGameModel()

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                headerView
                gridView
                statusView
                resetButton
            }
            .padding()

            if model.gameOver {
                gameOverOverlay
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
        ) { _ in }
        .onChange(of: model.isAIThinking) { _, thinking in
            if thinking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    model.aiMove()
                }
            }
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain Reaction")
                    .font(.title2.bold())
                Text("6 × 6 Grid")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            playerIndicator
        }
    }

    private var playerIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.currentPlayer.color)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.3), lineWidth: 1)
                )
            Text(model.currentPlayer == .red ? "Your Turn" : "AI Thinking…")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: Grid

    private var gridView: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cellSize = (side - 10) / CGFloat(CRGameModel.cols)

            VStack(spacing: 2) {
                ForEach(0..<CRGameModel.rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<CRGameModel.cols, id: \.self) { col in
                            CRCellView(
                                cell: model.grid[row][col],
                                cellSize: cellSize - 2,
                                row: row, col: col,
                                rows: CRGameModel.rows, cols: CRGameModel.cols
                            )
                            .onTapGesture {
                                if model.currentPlayer == .red && !model.isAIThinking {
                                    model.tap(row: row, col: col)
                                }
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Status

    private var statusView: some View {
        HStack(spacing: 20) {
            playerScoreTag(player: .red, label: "You")
            Spacer()
            playerScoreTag(player: .blue, label: "AI")
        }
        .padding(.horizontal, 8)
    }

    private func playerScoreTag(player: CRPlayer, label: String) -> some View {
        let count = (0..<CRGameModel.rows).flatMap { r in
            (0..<CRGameModel.cols).filter { c in model.grid[r][c].owner == player }
        }.count
        let atoms = (0..<CRGameModel.rows).flatMap { r in
            (0..<CRGameModel.cols).compactMap { c -> Int? in
                model.grid[r][c].owner == player ? model.grid[r][c].atoms : nil
            }
        }.reduce(0, +)

        return HStack(spacing: 6) {
            Circle()
                .fill(player.color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline.bold())
                .foregroundColor(player.color)
            Text("· \(count) cells · \(atoms) atoms")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Reset

    private var resetButton: some View {
        Button(action: model.reset) {
            Label("New Game", systemImage: "arrow.counterclockwise")
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundColor(.accentColor)
        }
    }

    // MARK: Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(model.winner == .red ? "You Win!" : "AI Wins!")
                    .font(.largeTitle.bold())
                    .foregroundColor(model.winner.color)

                Text(model.winner == .red
                     ? "Congratulations, you dominated the grid."
                     : "The AI captured all cells. Try again!")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button(action: model.reset) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(model.winner.color, in: Capsule())
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .padding(40)
        }
    }
}

// MARK: - Cell View

private struct CRCellView: View {
    let cell: CRCell
    let cellSize: CGFloat
    let row: Int
    let col: Int
    let rows: Int
    let cols: Int

    private var criticalMass: Int {
        cell.criticalMass(row: row, col: col, rows: rows, cols: cols)
    }

    private var fillColor: Color {
        switch cell.owner {
        case .none: return Color(.secondarySystemBackground)
        case .red:  return Color.red.opacity(0.15)
        case .blue: return Color(red: 0.2, green: 0.5, blue: 1.0).opacity(0.15)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(cell.owner == .none
                                ? Color.gray.opacity(0.3)
                                : cell.owner.color.opacity(0.6),
                                lineWidth: cell.atoms == criticalMass - 1 ? 2 : 1)
                )

            atomDots(count: cell.atoms, color: cell.owner.color, size: cellSize)
        }
        .frame(width: cellSize, height: cellSize)
        .animation(.easeInOut(duration: 0.15), value: cell.atoms)
    }
}

private func atomDots(count: Int, color: Color, size: CGFloat) -> some View {
    let dotSize = max(size * 0.18, 6)
    let spacing = dotSize * 0.6

    return Group {
        switch count {
        case 1:
            Circle().fill(color).frame(width: dotSize, height: dotSize)
        case 2:
            HStack(spacing: spacing) {
                Circle().fill(color).frame(width: dotSize, height: dotSize)
                Circle().fill(color).frame(width: dotSize, height: dotSize)
            }
        case 3:
            VStack(spacing: spacing * 0.5) {
                Circle().fill(color).frame(width: dotSize, height: dotSize)
                HStack(spacing: spacing) {
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                }
            }
        case let n where n >= 4:
            VStack(spacing: spacing * 0.5) {
                HStack(spacing: spacing) {
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                }
                HStack(spacing: spacing) {
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                    Circle().fill(color).frame(width: dotSize, height: dotSize)
                }
            }
        default:
            EmptyView()
        }
    }
}

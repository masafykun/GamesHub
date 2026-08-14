import SwiftUI

// MARK: - Private Model Types ()

private enum CRPlayer {
    case none, red, blue

    var color: Color {
        switch self {
        case .none: return .clear
        case .red:  return Color(red: 1.0, green: 0.3, blue: 0.4)
        case .blue: return Color(red: 0.3, green: 0.6, blue: 1.0)
        }
    }

    var glowColor: Color {
        switch self {
        case .none: return .clear
        case .red:  return Color(red: 1.0, green: 0.2, blue: 0.3)
        case .blue: return Color(red: 0.2, green: 0.5, blue: 1.0)
        }
    }
}

private struct CRCell {
    var owner: CRPlayer = .none
    var atoms: Int = 0

    func criticalMass(row: Int, col: Int, rows: Int, cols: Int) -> Int {
        var n = 0
        if row > 0        { n += 1 }
        if row < rows - 1 { n += 1 }
        if col > 0        { n += 1 }
        if col < cols - 1 { n += 1 }
        return n
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
    @Published var lastExplosion: (Int, Int)? = nil

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
            for c in 0..<CRGameModel.cols { result.append((r, c)) }
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
                        for (nr, nc) in getNeighbors(row: r, col: c) {
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
        let redCells  = allCells().filter { r, c in grid[r][c].owner == .red  }.count
        let blueCells = allCells().filter { r, c in grid[r][c].owner == .blue }.count
        if redCells == 0  { gameOver = true; winner = .blue }
        else if blueCells == 0 { gameOver = true; winner = .red  }
    }

    func reset() {
        grid = Array(repeating: Array(repeating: CRCell(), count: CRGameModel.cols),
                     count: CRGameModel.rows)
        currentPlayer = .red
        gameOver = false
        winner = .none
        isAIThinking = false
        moveCount = 0
        lastExplosion = nil
    }
}

// MARK: - Main View (Glassmorphism)

struct ChainReactionView: View {
    @StateObject private var model = CRGameModel()

    private let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.05, blue: 0.18),
            Color(red: 0.10, green: 0.06, blue: 0.25),
            Color(red: 0.08, green: 0.12, blue: 0.22)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            // Ambient blobs
            ambientBlobs

            ScrollView {
                VStack(spacing: 24) {
                    headerGlass
                    gridGlass
                    scoreGlass
                    resetGlass
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }

            if model.gameOver {
                gameOverOverlay
            }
        }
        .onChange(of: model.isAIThinking) { _, thinking in
            if thinking {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    model.aiMove()
                }
            }
        }
    }

    // MARK: Ambient blobs

    private var ambientBlobs: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.5, green: 0.2, blue: 1.0).opacity(0.35), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -120, y: -250)
                .blur(radius: 40)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.2, green: 0.4, blue: 1.0).opacity(0.3), .clear],
                        center: .center, startRadius: 0, endRadius: 200
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 130, y: 300)
                .blur(radius: 40)
        }
    }

    // MARK: Header

    private var headerGlass: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain Reaction")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Strategy · 6×6")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            turnBadge
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: model.currentPlayer.glowColor.opacity(0.35), radius: 20, x: 0, y: 4)
    }

    private var turnBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.currentPlayer.color)
                .frame(width: 12, height: 12)
                .shadow(color: model.currentPlayer.glowColor.opacity(0.9), radius: 6)
            Text(model.currentPlayer == .red ? "Your Turn" : "AI…")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 1))
    }

    // MARK: Grid

    private var gridGlass: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let cellSize = (side - 12) / CGFloat(CRGameModel.cols)

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
            .padding(6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Score

    private var scoreGlass: some View {
        HStack(spacing: 12) {
            scoreCard(player: .red, label: "You")
            scoreCard(player: .blue, label: "AI")
        }
    }

    private func scoreCard(player: CRPlayer, label: String) -> some View {
        let cells = (0..<CRGameModel.rows).flatMap { r in
            (0..<CRGameModel.cols).filter { c in model.grid[r][c].owner == player }
        }.count
        let atoms = (0..<CRGameModel.rows).flatMap { r in
            (0..<CRGameModel.cols).compactMap { c -> Int? in
                model.grid[r][c].owner == player ? model.grid[r][c].atoms : nil
            }
        }.reduce(0, +)

        return VStack(spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(player.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: player.glowColor.opacity(0.8), radius: 4)
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            Text("\(cells) cells")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text("\(atoms) atoms")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(player.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: player.glowColor.opacity(0.2), radius: 10)
    }

    // MARK: Reset

    private var resetGlass: some View {
        Button(action: model.reset) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                Text("New Game")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .white.opacity(0.05), radius: 8)
        }
    }

    // MARK: Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 20) {
                Text(model.winner == .red ? "Victory!" : "Defeat!")
                    .font(.system(size: 42, weight: .black))
                    .foregroundColor(model.winner.color)
                    .shadow(color: model.winner.glowColor.opacity(0.8), radius: 20)

                Text(model.winner == .red
                     ? "You dominated the grid!"
                     : "The AI captured everything.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Button(action: model.reset) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 15)
                        .background(
                            model.winner.color.opacity(0.8),
                            in: Capsule()
                        )
                        .shadow(color: model.winner.glowColor.opacity(0.6), radius: 14)
                }
            }
            .padding(36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: model.winner.glowColor.opacity(0.4), radius: 30)
            .padding(40)
        }
    }
}

// MARK: - Cell View ()

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

    private var isNearCritical: Bool {
        cell.atoms == criticalMass - 1 && cell.owner != .none
    }

    var body: some View {
        ZStack {
            // Base glass cell
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cell.owner.color.opacity(cell.owner == .none ? 0 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            cell.owner == .none
                                ? Color.white.opacity(0.08)
                                : cell.owner.color.opacity(isNearCritical ? 0.9 : 0.4),
                            lineWidth: isNearCritical ? 2 : 1
                        )
                )
                .shadow(
                    color: isNearCritical ? cell.owner.glowColor.opacity(0.6) : .clear,
                    radius: 8
                )

            crAtomDots(count: cell.atoms, color: cell.owner.color,
                         glow: cell.owner.glowColor, size: cellSize)
        }
        .frame(width: cellSize, height: cellSize)
        .animation(.easeInOut(duration: 0.18), value: cell.atoms)
    }
}

private func crAtomDots(count: Int, color: Color, glow: Color, size: CGFloat) -> some View {
    let dotSize = max(size * 0.19, 6)
    let spacing = dotSize * 0.55

    func dot() -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.6)],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: dotSize
                )
            )
            .frame(width: dotSize, height: dotSize)
            .shadow(color: glow.opacity(0.85), radius: 5)
    }

    return Group {
        switch count {
        case 1:
            dot()
        case 2:
            HStack(spacing: spacing) { dot(); dot() }
        case 3:
            VStack(spacing: spacing * 0.5) {
                dot()
                HStack(spacing: spacing) { dot(); dot() }
            }
        case let n where n >= 4:
            VStack(spacing: spacing * 0.5) {
                HStack(spacing: spacing) { dot(); dot() }
                HStack(spacing: spacing) { dot(); dot() }
            }
        default:
            EmptyView()
        }
    }
}

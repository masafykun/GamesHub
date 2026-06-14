import SwiftUI

// MARK: - Private Model Types (V3)

private enum CRV3Player {
    case none, red, blue

    var color: Color {
        switch self {
        case .none: return .clear
        case .red:  return Color(red: 0.85, green: 0.2, blue: 0.25)
        case .blue: return Color(red: 0.2, green: 0.45, blue: 0.85)
        }
    }

    var softColor: Color {
        switch self {
        case .none: return Color(.systemGray5)
        case .red:  return Color(red: 1.0, green: 0.88, blue: 0.88)
        case .blue: return Color(red: 0.88, green: 0.92, blue: 1.0)
        }
    }
}

private struct CRV3Cell {
    var owner: CRV3Player = .none
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

private class CRV3GameModel: ObservableObject {
    static let rows = 6
    static let cols = 6

    @Published var grid: [[CRV3Cell]] = Array(
        repeating: Array(repeating: CRV3Cell(), count: cols),
        count: rows
    )
    @Published var currentPlayer: CRV3Player = .red
    @Published var gameOver: Bool = false
    @Published var winner: CRV3Player = .none
    @Published var isAIThinking: Bool = false
    @Published var moveCount: Int = 0
    @Published var pressedCell: (Int, Int)? = nil

    func canTap(row: Int, col: Int) -> Bool {
        let cell = grid[row][col]
        return cell.owner == .none || cell.owner == currentPlayer
    }

    func tap(row: Int, col: Int) {
        guard !gameOver, !isAIThinking else { return }
        guard canTap(row: row, col: col) else { return }

        pressedCell = (row, col)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.pressedCell = nil
        }

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
                                                rows: CRV3GameModel.rows, cols: CRV3GameModel.cols)
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
        for r in 0..<CRV3GameModel.rows {
            for c in 0..<CRV3GameModel.cols { result.append((r, c)) }
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
            for r in 0..<CRV3GameModel.rows {
                for c in 0..<CRV3GameModel.cols {
                    let mass = newGrid[r][c].criticalMass(row: r, col: c,
                                                          rows: CRV3GameModel.rows, cols: CRV3GameModel.cols)
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
        if row < CRV3GameModel.rows - 1 { result.append((row + 1, col)) }
        if col > 0        { result.append((row, col - 1)) }
        if col < CRV3GameModel.cols - 1 { result.append((row, col + 1)) }
        return result
    }

    private func checkWinner() {
        guard moveCount >= 2 else { return }
        let redCells  = allCells().filter { r, c in grid[r][c].owner == .red  }.count
        let blueCells = allCells().filter { r, c in grid[r][c].owner == .blue }.count
        if redCells  == 0 { gameOver = true; winner = .blue }
        else if blueCells == 0 { gameOver = true; winner = .red  }
    }

    func reset() {
        grid = Array(repeating: Array(repeating: CRV3Cell(), count: CRV3GameModel.cols),
                     count: CRV3GameModel.rows)
        currentPlayer = .red
        gameOver = false
        winner = .none
        isAIThinking = false
        moveCount = 0
        pressedCell = nil
    }
}

// MARK: - Neumorphic Modifiers (V3 private)

private struct CRV3NeumorphicCard: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
            .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }
}

private struct CRV3NeumorphicInset: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.14), radius: 4, x: 2, y: 2)
            .shadow(color: .white.opacity(0.6), radius: 4, x: -2, y: -2)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [.black.opacity(0.08), .white.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

private extension View {
    func crV3Card(cornerRadius: CGFloat = 18) -> some View {
        modifier(CRV3NeumorphicCard(cornerRadius: cornerRadius))
    }

    func crV3Inset(cornerRadius: CGFloat = 14) -> some View {
        modifier(CRV3NeumorphicInset(cornerRadius: cornerRadius))
    }
}

// MARK: - Main View (Neumorphism)

struct ChainReactionViewV3: View {
    @StateObject private var model = CRV3GameModel()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    headerNeu
                    gridNeu
                    scoreNeu
                    resetNeu
                }
                .padding(.horizontal, 20)
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

    // MARK: Header

    private var headerNeu: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Chain Reaction")
                    .font(.title2.bold())
                    .foregroundColor(Color(.label))
                Text("6×6 Strategy")
                    .font(.caption)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            turnNeuBadge
        }
        .padding(18)
        .crV3Card()
    }

    private var turnNeuBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(model.currentPlayer.color)
                .frame(width: 11, height: 11)
                .shadow(color: model.currentPlayer.color.opacity(0.4), radius: 3)
            Text(model.currentPlayer == .red ? "Your Turn" : "AI…")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Color(.label))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .crV3Card(cornerRadius: 20)
    }

    // MARK: Grid

    private var gridNeu: some View {
        GeometryReader { geo in
            let side = geo.size.width
            let innerSide = side - 20
            let cellSize = (innerSide - 10) / CGFloat(CRV3GameModel.cols)

            VStack(spacing: 2) {
                ForEach(0..<CRV3GameModel.rows, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<CRV3GameModel.cols, id: \.self) { col in
                            CRV3CellView(
                                cell: model.grid[row][col],
                                cellSize: cellSize - 2,
                                row: row, col: col,
                                rows: CRV3GameModel.rows, cols: CRV3GameModel.cols,
                                isPressed: model.pressedCell.map { $0 == row && $1 == col } ?? false
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
            .padding(10)
            .crV3Card(cornerRadius: 22)
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Score

    private var scoreNeu: some View {
        HStack(spacing: 14) {
            neuScoreCard(player: .red, label: "You")
            neuScoreCard(player: .blue, label: "AI")
        }
    }

    private func neuScoreCard(player: CRV3Player, label: String) -> some View {
        let cells = (0..<CRV3GameModel.rows).flatMap { r in
            (0..<CRV3GameModel.cols).filter { c in model.grid[r][c].owner == player }
        }.count
        let atoms = (0..<CRV3GameModel.rows).flatMap { r in
            (0..<CRV3GameModel.cols).compactMap { c -> Int? in
                model.grid[r][c].owner == player ? model.grid[r][c].atoms : nil
            }
        }.reduce(0, +)

        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(player.color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundColor(player.color)
            }
            Text("\(cells) cells")
                .font(.callout.monospacedDigit())
                .foregroundColor(Color(.label))
            Text("\(atoms) atoms")
                .font(.caption.monospacedDigit())
                .foregroundColor(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .crV3Card()
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(player.softColor, lineWidth: 2)
        )
    }

    // MARK: Reset

    private var resetNeu: some View {
        Button(action: model.reset) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise")
                    .fontWeight(.semibold)
                Text("New Game")
                    .fontWeight(.semibold)
            }
            .foregroundColor(Color(.label))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .crV3Card(cornerRadius: 16)
        }
        .buttonStyle(CRV3PressStyle())
    }

    // MARK: Game Over Overlay

    private var gameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.82).ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(model.winner.softColor)
                        .frame(width: 90, height: 90)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 5, y: 5)
                        .shadow(color: .white.opacity(0.7), radius: 10, x: -5, y: -5)

                    Image(systemName: model.winner == .red ? "crown.fill" : "cpu.fill")
                        .font(.system(size: 36))
                        .foregroundColor(model.winner.color)
                }

                Text(model.winner == .red ? "You Win!" : "AI Wins!")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(model.winner.color)

                Text(model.winner == .red
                     ? "Excellent play — you dominated."
                     : "The AI captured the board. Try again!")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.secondaryLabel))

                Button(action: model.reset) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(model.winner.color)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .crV3Card(cornerRadius: 14)
                }
                .buttonStyle(CRV3PressStyle())
            }
            .padding(34)
            .crV3Card(cornerRadius: 28)
            .padding(36)
        }
    }
}

// MARK: - Button Style

private struct CRV3PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Cell View (V3)

private struct CRV3CellView: View {
    let cell: CRV3Cell
    let cellSize: CGFloat
    let row: Int
    let col: Int
    let rows: Int
    let cols: Int
    let isPressed: Bool

    private var criticalMass: Int {
        cell.criticalMass(row: row, col: col, rows: rows, cols: cols)
    }

    private var isNearCritical: Bool {
        cell.atoms == criticalMass - 1 && cell.owner != .none
    }

    var body: some View {
        ZStack {
            if isPressed {
                // Inset / pressed state
                RoundedRectangle(cornerRadius: 10)
                    .fill(cell.owner == .none ? Color(.systemGray5) : cell.owner.softColor)
                    .shadow(color: .black.opacity(0.14), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.5), radius: 4, x: -2, y: -2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [.black.opacity(0.1), .white.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            } else {
                // Raised neumorphic state
                RoundedRectangle(cornerRadius: 10)
                    .fill(cell.owner == .none ? Color(.systemGray6) : cell.owner.softColor)
                    .shadow(color: .black.opacity(isNearCritical ? 0.22 : 0.15), radius: isNearCritical ? 6 : 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(isNearCritical ? 0.85 : 0.7), radius: isNearCritical ? 6 : 4, x: -3, y: -3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isNearCritical
                                    ? cell.owner.color.opacity(0.5)
                                    : Color.clear,
                                lineWidth: isNearCritical ? 1.5 : 0
                            )
                    )
            }

            crV3AtomDots(count: cell.atoms, color: cell.owner.color, size: cellSize)
        }
        .frame(width: cellSize, height: cellSize)
        .animation(.easeInOut(duration: 0.18), value: cell.atoms)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
    }
}

private func crV3AtomDots(count: Int, color: Color, size: CGFloat) -> some View {
    let dotSize = max(size * 0.18, 6)
    let spacing = dotSize * 0.55

    func dot() -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.85))
                .frame(width: dotSize, height: dotSize)
                .shadow(color: .black.opacity(0.18), radius: 2, x: 1, y: 1)
                .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)

            // Subtle inner highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.4), .clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: dotSize * 0.5
                    )
                )
                .frame(width: dotSize, height: dotSize)
        }
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

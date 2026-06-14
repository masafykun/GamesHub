import SwiftUI

// MARK: - LCG RNG

struct ConnectFourLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let span = UInt64(range.count)
        guard span > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % span)
    }
}

// MARK: - Model

enum ConnectFourV3Cell {
    case empty, player, ai
}

enum ConnectFourV3GameState {
    case playerTurn, aiTurn, playerWin, aiWin, draw
}

struct ConnectFourV3Board {
    static let rows = 6
    static let cols = 7

    var cells: [[ConnectFourV3Cell]] = Array(
        repeating: Array(repeating: .empty, count: ConnectFourV3Board.cols),
        count: ConnectFourV3Board.rows
    )

    func dropRow(col: Int) -> Int? {
        for row in stride(from: ConnectFourV3Board.rows - 1, through: 0, by: -1) {
            if cells[row][col] == .empty { return row }
        }
        return nil
    }

    mutating func drop(col: Int, cell: ConnectFourV3Cell) -> Int? {
        guard let row = dropRow(col: col) else { return nil }
        cells[row][col] = cell
        return row
    }

    func isFull() -> Bool {
        for col in 0..<ConnectFourV3Board.cols {
            if cells[0][col] == .empty { return false }
        }
        return true
    }

    func checkWin(cell: ConnectFourV3Cell) -> Bool {
        let rows = ConnectFourV3Board.rows
        let cols = ConnectFourV3Board.cols
        let directions: [(Int, Int)] = [(0, 1), (1, 0), (1, 1), (1, -1)]
        for r in 0..<rows {
            for c in 0..<cols {
                guard cells[r][c] == cell else { continue }
                for (dr, dc) in directions {
                    var count = 1
                    var nr = r + dr
                    var nc = c + dc
                    while count < 4,
                          nr >= 0, nr < rows,
                          nc >= 0, nc < cols,
                          cells[nr][nc] == cell {
                        count += 1
                        nr += dr
                        nc += dc
                    }
                    if count >= 4 { return true }
                }
            }
        }
        return false
    }

    func validColumns() -> [Int] {
        (0..<ConnectFourV3Board.cols).filter { dropRow(col: $0) != nil }
    }
}

// MARK: - ViewModel

class ConnectFourV3ViewModel: ObservableObject {
    @Published var board = ConnectFourV3Board()
    @Published var gameState: ConnectFourV3GameState = .playerTurn
    @Published var seedInt: Int = 1

    private var rng: ConnectFourLCG
    private var aiWorkItem: DispatchWorkItem?

    init() {
        rng = ConnectFourLCG(seed: 1)
    }

    func restart() {
        aiWorkItem?.cancel()
        aiWorkItem = nil
        seedInt += 1
        rng = ConnectFourLCG(seed: seedInt)
        board = ConnectFourV3Board()
        gameState = .playerTurn
    }

    func playerTap(col: Int) {
        guard gameState == .playerTurn else { return }
        guard board.dropRow(col: col) != nil else { return }

        let _ = board.drop(col: col, cell: .player)

        if board.checkWin(cell: .player) {
            gameState = .playerWin
            return
        }
        if board.isFull() {
            gameState = .draw
            return
        }
        gameState = .aiTurn
        scheduleAI()
    }

    private func scheduleAI() {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.aiMove()
        }
        aiWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: workItem)
    }

    private func aiMove() {
        guard gameState == .aiTurn else { return }
        let valid = board.validColumns()
        guard !valid.isEmpty else {
            gameState = .draw
            return
        }
        let idx = rng.nextInt(in: 0..<valid.count)
        let col = valid[idx]
        let _ = board.drop(col: col, cell: .ai)

        if board.checkWin(cell: .ai) {
            gameState = .aiWin
            return
        }
        if board.isFull() {
            gameState = .draw
            return
        }
        gameState = .playerTurn
    }
}

// MARK: - Main View

struct ConnectFourViewV3: View {
    @StateObject private var vm = ConnectFourV3ViewModel()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 20) {
                // Title
                Text("Connect Four")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                // Seed display — always visible
                Text("SEED: #\(vm.seedInt)")
                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 10)

                // Status
                ConnectFourV3StatusView(gameState: vm.gameState)

                // Board
                ConnectFourV3GridView(board: vm.board) { col in
                    vm.playerTap(col: col)
                }

                // Restart
                Button(action: { vm.restart() }) {
                    Text("Restart")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 24)
                }
            }
            .padding()

            // Win / Draw overlay
            if vm.gameState == .playerWin || vm.gameState == .aiWin || vm.gameState == .draw {
                ConnectFourV3WinOverlayView(
                    gameState: vm.gameState,
                    seedInt: vm.seedInt,
                    onRestart: { vm.restart() }
                )
            }
        }
    }
}

// MARK: - Status View

struct ConnectFourV3StatusView: View {
    let gameState: ConnectFourV3GameState

    var statusText: String {
        switch gameState {
        case .playerTurn: return "Your Turn (Red)"
        case .aiTurn:     return "AI Thinking... (Yellow)"
        case .playerWin:  return "You Win!"
        case .aiWin:      return "AI Wins!"
        case .draw:       return "It's a Draw!"
        }
    }

    var statusColor: Color {
        switch gameState {
        case .playerTurn: return .red
        case .aiTurn:     return Color(red: 0.85, green: 0.7, blue: 0.0)
        case .playerWin:  return .red
        case .aiWin:      return Color(red: 0.85, green: 0.7, blue: 0.0)
        case .draw:       return .gray
        }
    }

    var body: some View {
        Text(statusText)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(statusColor.opacity(0.13))
            .clipShape(Capsule())
            .shadow(color: statusColor.opacity(0.18), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Grid View

struct ConnectFourV3GridView: View {
    let board: ConnectFourV3Board
    let onTap: (Int) -> Void

    private let cellSize: CGFloat = 44
    private let spacing: CGFloat = 6
    private let boardPadding: CGFloat = 10

    var totalWidth: CGFloat {
        CGFloat(ConnectFourV3Board.cols) * cellSize
        + CGFloat(ConnectFourV3Board.cols - 1) * spacing
        + boardPadding * 2
    }

    var totalHeight: CGFloat {
        CGFloat(ConnectFourV3Board.rows) * cellSize
        + CGFloat(ConnectFourV3Board.rows - 1) * spacing
        + boardPadding * 2
    }

    var body: some View {
        ZStack {
            // Neumorphic board backing
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
                .frame(width: totalWidth + 12, height: totalHeight + 12)
                .shadow(color: .white.opacity(0.8), radius: 8, x: -5, y: -5)
                .shadow(color: Color(.systemGray4), radius: 8, x: 5, y: 5)

            // Inner board face
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.blue.opacity(0.82))
                .frame(width: totalWidth, height: totalHeight)
                .shadow(color: .blue.opacity(0.35), radius: 6, x: 0, y: 4)

            // Cells
            VStack(spacing: spacing) {
                ForEach(0..<ConnectFourV3Board.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<ConnectFourV3Board.cols, id: \.self) { col in
                            ConnectFourV3CellView(
                                cell: board.cells[row][col],
                                size: cellSize
                            )
                        }
                    }
                }
            }
            .padding(boardPadding)

            // Tap columns overlay
            HStack(spacing: spacing) {
                ForEach(0..<ConnectFourV3Board.cols, id: \.self) { col in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: cellSize, height: totalHeight)
                        .contentShape(Rectangle())
                        .onTapGesture { onTap(col) }
                }
            }
        }
    }
}

// MARK: - Cell View

struct ConnectFourV3CellView: View {
    let cell: ConnectFourV3Cell
    let size: CGFloat

    var discColor: Color {
        switch cell {
        case .empty:  return Color(.systemGray5)
        case .player: return .red
        case .ai:     return .yellow
        }
    }

    var innerShadowOpacity: Double {
        cell == .empty ? 0.0 : 0.25
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(discColor)
                .frame(width: size, height: size)
                .shadow(color: cell == .empty ? Color(.systemGray3).opacity(0.5) : .black.opacity(0.3),
                        radius: cell == .empty ? 2 : 3,
                        x: cell == .empty ? 1 : 0,
                        y: cell == .empty ? 1 : 2)

            // Highlight glint for placed discs
            if cell != .empty {
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white.opacity(0.35), .clear]),
                            center: UnitPoint(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )
                    .frame(width: size, height: size)
            }
        }
        .animation(.easeOut(duration: 0.18), value: cell == .empty)
    }
}

// MARK: - Win Overlay

struct ConnectFourV3WinOverlayView: View {
    let gameState: ConnectFourV3GameState
    let seedInt: Int
    let onRestart: () -> Void

    var headline: String {
        switch gameState {
        case .playerWin: return "You Win!"
        case .aiWin:     return "AI Wins!"
        case .draw:      return "It's a Draw!"
        default:         return ""
        }
    }

    var headlineColor: Color {
        switch gameState {
        case .playerWin: return .red
        case .aiWin:     return .yellow
        default:         return .gray
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(headline)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(headlineColor)
                    .shadow(color: headlineColor.opacity(0.5), radius: 8, x: 0, y: 3)

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 13)
                        .neumorphicCard(radius: 24)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemGray6))
                    .shadow(color: .white.opacity(0.8), radius: 10, x: -6, y: -6)
                    .shadow(color: Color(.systemGray4), radius: 10, x: 6, y: 6)
            )
            .padding(.horizontal, 36)
        }
    }
}

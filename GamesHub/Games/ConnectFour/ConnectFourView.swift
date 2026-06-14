import SwiftUI

// MARK: - Model

enum ConnectFourCell {
    case empty, player, ai
}

enum ConnectFourGameState {
    case playerTurn, aiTurn, playerWin, aiWin, draw
}

struct ConnectFourBoard {
    static let rows = 6
    static let cols = 7

    var cells: [[ConnectFourCell]] = Array(
        repeating: Array(repeating: .empty, count: ConnectFourBoard.cols),
        count: ConnectFourBoard.rows
    )

    // Returns the row where the disc lands in the given column, or nil if full
    func dropRow(col: Int) -> Int? {
        for row in stride(from: ConnectFourBoard.rows - 1, through: 0, by: -1) {
            if cells[row][col] == .empty {
                return row
            }
        }
        return nil
    }

    mutating func drop(col: Int, cell: ConnectFourCell) -> Int? {
        guard let row = dropRow(col: col) else { return nil }
        cells[row][col] = cell
        return row
    }

    func isFull() -> Bool {
        for col in 0..<ConnectFourBoard.cols {
            if cells[0][col] == .empty { return false }
        }
        return true
    }

    func checkWin(cell: ConnectFourCell) -> Bool {
        let rows = ConnectFourBoard.rows
        let cols = ConnectFourBoard.cols
        let directions: [(Int, Int)] = [(0,1),(1,0),(1,1),(1,-1)]
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
        (0..<ConnectFourBoard.cols).filter { dropRow(col: $0) != nil }
    }
}

// MARK: - ViewModel

class ConnectFourViewModel: ObservableObject {
    @Published var board = ConnectFourBoard()
    @Published var gameState: ConnectFourGameState = .playerTurn
    @Published var droppingCol: Int? = nil

    private var aiWorkItem: DispatchWorkItem?

    func restart() {
        aiWorkItem?.cancel()
        aiWorkItem = nil
        board = ConnectFourBoard()
        gameState = .playerTurn
        droppingCol = nil
    }

    func playerTap(col: Int) {
        guard gameState == .playerTurn else { return }
        guard board.dropRow(col: col) != nil else { return }

        droppingCol = col
        let _ = board.drop(col: col, cell: .player)
        droppingCol = nil

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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func aiMove() {
        guard gameState == .aiTurn else { return }
        let valid = board.validColumns()
        guard !valid.isEmpty else {
            gameState = .draw
            return
        }
        let col = valid.randomElement()!
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

struct ConnectFourView: View {
    @StateObject private var vm = ConnectFourViewModel()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Connect Four")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                ConnectFourStatusView(gameState: vm.gameState)

                ConnectFourGridView(board: vm.board) { col in
                    vm.playerTap(col: col)
                }

                Button(action: { vm.restart() }) {
                    Text("Restart")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.4), radius: 6, x: 0, y: 4)
                }
            }
            .padding()

            if vm.gameState == .playerWin || vm.gameState == .aiWin || vm.gameState == .draw {
                ConnectFourWinOverlayView(gameState: vm.gameState) {
                    vm.restart()
                }
            }
        }
    }
}

// MARK: - Status View

struct ConnectFourStatusView: View {
    let gameState: ConnectFourGameState

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
        case .aiTurn:     return .yellow
        case .playerWin:  return .red
        case .aiWin:      return .yellow
        case .draw:       return .gray
        }
    }

    var body: some View {
        Text(statusText)
            .font(.system(size: 18, weight: .semibold, design: .rounded))
            .foregroundColor(statusColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Grid View

struct ConnectFourGridView: View {
    let board: ConnectFourBoard
    let onTap: (Int) -> Void

    private let cellSize: CGFloat = 44
    private let spacing: CGFloat = 6
    private let boardPadding: CGFloat = 10

    var body: some View {
        let totalWidth = CGFloat(ConnectFourBoard.cols) * cellSize
                       + CGFloat(ConnectFourBoard.cols - 1) * spacing
                       + boardPadding * 2
        let totalHeight = CGFloat(ConnectFourBoard.rows) * cellSize
                        + CGFloat(ConnectFourBoard.rows - 1) * spacing
                        + boardPadding * 2

        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.85))
                .frame(width: totalWidth, height: totalHeight)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

            VStack(spacing: spacing) {
                ForEach(0..<ConnectFourBoard.rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<ConnectFourBoard.cols, id: \.self) { col in
                            ConnectFourCellView(cell: board.cells[row][col], size: cellSize)
                        }
                    }
                }
            }
            .padding(boardPadding)

            // Tap regions per column (overlay)
            HStack(spacing: spacing) {
                ForEach(0..<ConnectFourBoard.cols, id: \.self) { col in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: cellSize, height: totalHeight)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(col)
                        }
                }
            }
        }
    }
}

// MARK: - Cell View

struct ConnectFourCellView: View {
    let cell: ConnectFourCell
    let size: CGFloat

    var discColor: Color {
        switch cell {
        case .empty:  return Color(.systemGray6).opacity(0.9)
        case .player: return .red
        case .ai:     return .yellow
        }
    }

    var body: some View {
        Circle()
            .fill(discColor)
            .frame(width: size, height: size)
            .shadow(color: cell == .empty ? .clear : .black.opacity(0.25), radius: 2, x: 0, y: 2)
            .animation(.easeIn(duration: 0.15), value: cell == .empty)
    }
}

// MARK: - Win Overlay

struct ConnectFourWinOverlayView: View {
    let gameState: ConnectFourGameState
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
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 24) {
                Text(headline)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(headlineColor)
                    .shadow(color: headlineColor.opacity(0.5), radius: 8, x: 0, y: 4)

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.5), radius: 8, x: 0, y: 4)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(40)
        }
    }
}

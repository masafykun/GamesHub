import SwiftUI

// MARK: - Models (V3)

enum TicTacToeCellV3: Equatable {
    case empty
    case x
    case o
}

enum TicTacToeGameStateV3 {
    case playing
    case xWins
    case oWins
    case draw
}

// MARK: - 4x4 Board (V3)

struct TicTacToeBoardV3 {
    static let size = 4
    static let count = size * size

    var cells: [TicTacToeCellV3] = Array(repeating: .empty, count: TicTacToeBoardV3.count)

    // Lines needed to win on a 4x4 board (4-in-a-row)
    static var lines: [[Int]] {
        var result: [[Int]] = []
        let s = size
        // Rows
        for r in 0..<s {
            result.append((0..<s).map { r * s + $0 })
        }
        // Columns
        for c in 0..<s {
            result.append((0..<s).map { $0 * s + c })
        }
        // Diagonals
        result.append((0..<s).map { $0 * s + $0 })
        result.append((0..<s).map { $0 * s + (s - 1 - $0) })
        return result
    }

    func winner() -> TicTacToeCellV3? {
        for line in TicTacToeBoardV3.lines {
            let first = cells[line[0]]
            guard first != .empty else { continue }
            if line.allSatisfy({ cells[$0] == first }) {
                return first
            }
        }
        return nil
    }

    func isDraw() -> Bool {
        cells.allSatisfy { $0 != .empty } && winner() == nil
    }

    func winningLine() -> [Int]? {
        for line in TicTacToeBoardV3.lines {
            let first = cells[line[0]]
            guard first != .empty else { continue }
            if line.allSatisfy({ cells[$0] == first }) {
                return line
            }
        }
        return nil
    }

    func availableMoves() -> [Int] {
        cells.indices.filter { cells[$0] == .empty }
    }

    mutating func place(_ cell: TicTacToeCellV3, at index: Int) {
        cells[index] = cell
    }
}

// MARK: - LCG RNG (V3)

struct TicTacToeLCGV3 {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = UInt64(range.count)
        guard n > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % n)
    }
}

// MARK: - Minimax AI with seed randomization (V3)

struct TicTacToeAIV3 {
    // Minimax with limited depth for 4x4 performance; uses seed to pick among equal-score moves
    func bestMove(for board: TicTacToeBoardV3, seed: Int) -> Int? {
        let moves = board.availableMoves()
        guard !moves.isEmpty else { return nil }

        var rng = TicTacToeLCGV3(seed: seed)

        var bestScore = Int.min
        var bestMoves: [Int] = []

        for move in moves {
            var newBoard = board
            newBoard.place(.o, at: move)
            let score = minimax(board: newBoard, depth: 0, maxDepth: 4, isMaximizing: false, alpha: Int.min, beta: Int.max)
            if score > bestScore {
                bestScore = score
                bestMoves = [move]
            } else if score == bestScore {
                bestMoves.append(move)
            }
        }

        // Use LCG to pick among equally-scored moves
        if bestMoves.count == 1 {
            return bestMoves[0]
        }
        let idx = rng.nextInt(in: 0..<bestMoves.count)
        return bestMoves[idx]
    }

    private func minimax(board: TicTacToeBoardV3, depth: Int, maxDepth: Int, isMaximizing: Bool, alpha: Int, beta: Int) -> Int {
        if let winner = board.winner() {
            return winner == .o ? (10 - depth) : (depth - 10)
        }
        if board.isDraw() { return 0 }
        if depth >= maxDepth { return heuristic(board: board) }

        let moves = board.availableMoves()
        var alpha = alpha
        var beta = beta

        if isMaximizing {
            var best = Int.min
            for move in moves {
                var newBoard = board
                newBoard.place(.o, at: move)
                let score = minimax(board: newBoard, depth: depth + 1, maxDepth: maxDepth, isMaximizing: false, alpha: alpha, beta: beta)
                best = max(best, score)
                alpha = max(alpha, best)
                if beta <= alpha { break }
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                var newBoard = board
                newBoard.place(.x, at: move)
                let score = minimax(board: newBoard, depth: depth + 1, maxDepth: maxDepth, isMaximizing: true, alpha: alpha, beta: beta)
                best = min(best, score)
                beta = min(beta, best)
                if beta <= alpha { break }
            }
            return best
        }
    }

    // Simple heuristic: count partial lines for each side
    private func heuristic(board: TicTacToeBoardV3) -> Int {
        var score = 0
        for line in TicTacToeBoardV3.lines {
            let vals = line.map { board.cells[$0] }
            let oCount = vals.filter { $0 == .o }.count
            let xCount = vals.filter { $0 == .x }.count
            if xCount == 0 {
                score += oCount * oCount
            } else if oCount == 0 {
                score -= xCount * xCount
            }
        }
        return score
    }
}

// MARK: - ViewModel (V3)

class TicTacToeViewModelV3: ObservableObject {
    @Published var board = TicTacToeBoardV3()
    @Published var gameState: TicTacToeGameStateV3 = .playing
    @Published var xWins = 0
    @Published var oWins = 0
    @Published var draws = 0
    @Published var isAIThinking = false
    @Published var seedInt: Int = 1

    private let ai = TicTacToeAIV3()

    func playerTap(at index: Int) {
        guard gameState == .playing,
              board.cells[index] == .empty,
              !isAIThinking else { return }

        board.place(.x, at: index)
        checkState()

        if gameState == .playing {
            isAIThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                self.aiMove()
            }
        }
    }

    private func aiMove() {
        guard gameState == .playing else {
            isAIThinking = false
            return
        }
        if let move = ai.bestMove(for: board, seed: seedInt) {
            board.place(.o, at: move)
            checkState()
        }
        isAIThinking = false
    }

    private func checkState() {
        if let winner = board.winner() {
            if winner == .x {
                gameState = .xWins
                xWins += 1
            } else {
                gameState = .oWins
                oWins += 1
            }
        } else if board.isDraw() {
            gameState = .draw
            draws += 1
        }
    }

    func restart() {
        seedInt += 1
        board = TicTacToeBoardV3()
        gameState = .playing
        isAIThinking = false
    }
}

// MARK: - X Shape (V3)

struct TicTacToeXShapeV3: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

// MARK: - Cell View (V3)

struct TicTacToeCellViewV3: View {
    let cell: TicTacToeCellV3
    let isWinningCell: Bool

    var body: some View {
        ZStack {
            // Neumorphic cell background
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
                .shadow(color: .white.opacity(isWinningCell ? 0.4 : 0.9), radius: isWinningCell ? 2 : 5, x: -3, y: -3)
                .shadow(color: Color(.systemGray3).opacity(isWinningCell ? 0.3 : 0.8), radius: isWinningCell ? 2 : 5, x: 3, y: 3)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            isWinningCell
                                ? Color.yellow.opacity(0.18)
                                : Color.clear
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isWinningCell ? Color.yellow.opacity(0.55) : Color.clear,
                            lineWidth: 2
                        )
                )

            switch cell {
            case .x:
                TicTacToeXShapeV3()
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .padding(12)
                    .transition(.scale.combined(with: .opacity))
            case .o:
                Circle()
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 3.5))
                    .padding(11)
                    .transition(.scale.combined(with: .opacity))
            case .empty:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: cell)
    }
}

// MARK: - Score Badge (V3)

struct TicTacToeScoreBadgeV3: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color.opacity(0.8))
                .textCase(.uppercase)
                .tracking(0.8)
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(minWidth: 58)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .neumorphicCard(radius: 13)
    }
}

// MARK: - Seed Badge (V3)

struct TicTacToeSeedBadgeV3: View {
    let seed: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "dice.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.purple.opacity(0.8))
            Text("SEED: #\(seed)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.purple)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .neumorphicCard(radius: 20)
    }
}

// MARK: - Main View (V3)

struct TicTacToeViewV3: View {
    @StateObject private var vm = TicTacToeViewModelV3()

    private var winningLine: [Int]? {
        vm.board.winningLine()
    }

    private var statusText: String {
        switch vm.gameState {
        case .playing:
            return vm.isAIThinking ? "AI is thinking..." : "Your turn (X)"
        case .xWins:
            return "You win!"
        case .oWins:
            return "AI wins!"
        case .draw:
            return "It's a draw!"
        }
    }

    private var statusColor: Color {
        switch vm.gameState {
        case .playing:
            return vm.isAIThinking ? .orange : .cyan
        case .xWins:
            return .cyan
        case .oWins:
            return .orange
        case .draw:
            return Color(.systemGray)
        }
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 20) {

                // Title
                Text("Tic-Tac-Toe")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))

                // Seed badge — always visible
                TicTacToeSeedBadgeV3(seed: vm.seedInt)

                // Score row
                HStack(spacing: 10) {
                    TicTacToeScoreBadgeV3(label: "You (X)", count: vm.xWins, color: .cyan)
                    TicTacToeScoreBadgeV3(label: "Draw", count: vm.draws, color: Color(.systemGray))
                    TicTacToeScoreBadgeV3(label: "AI (O)", count: vm.oWins, color: .orange)
                }

                // Status text
                Text(statusText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                    .frame(height: 22)
                    .animation(.easeInOut(duration: 0.2), value: statusText)

                // 4x4 Board
                VStack(spacing: 8) {
                    ForEach(0..<TicTacToeBoardV3.size, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(0..<TicTacToeBoardV3.size, id: \.self) { col in
                                let index = row * TicTacToeBoardV3.size + col
                                let isWinning = winningLine?.contains(index) ?? false

                                TicTacToeCellViewV3(
                                    cell: vm.board.cells[index],
                                    isWinningCell: isWinning
                                )
                                .aspectRatio(1, contentMode: .fit)
                                .onTapGesture {
                                    vm.playerTap(at: index)
                                }
                            }
                        }
                    }
                }
                .padding(14)
                .neumorphicCard(radius: 22)
                .padding(.horizontal, 4)

                // Restart button
                Button(action: { vm.restart() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text("New Game")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 30)
                    .padding(.vertical, 13)
                    .neumorphicCard(radius: 24)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - Preview

#Preview {
    TicTacToeViewV3()
}

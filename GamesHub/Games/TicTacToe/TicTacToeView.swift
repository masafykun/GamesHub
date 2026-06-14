import SwiftUI

// MARK: - Models

enum TicTacToeCell {
    case empty
    case x
    case o
}

enum TicTacToeGameState {
    case playing
    case xWins
    case oWins
    case draw
}

// MARK: - Game Logic

struct TicTacToeBoard {
    var cells: [TicTacToeCell] = Array(repeating: .empty, count: 9)

    func winner() -> TicTacToeCell? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        for line in lines {
            let a = cells[line[0]], b = cells[line[1]], c = cells[line[2]]
            if a != .empty && a == b && b == c {
                return a
            }
        }
        return nil
    }

    func isDraw() -> Bool {
        return cells.allSatisfy { $0 != .empty } && winner() == nil
    }

    func winningLine() -> [Int]? {
        let lines = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        for line in lines {
            let a = cells[line[0]], b = cells[line[1]], c = cells[line[2]]
            if a != .empty && a == b && b == c {
                return line
            }
        }
        return nil
    }

    func availableMoves() -> [Int] {
        cells.indices.filter { cells[$0] == .empty }
    }

    mutating func place(_ cell: TicTacToeCell, at index: Int) {
        cells[index] = cell
    }
}

// MARK: - Minimax AI

struct TicTacToeAI {
    func bestMove(for board: TicTacToeBoard) -> Int? {
        let moves = board.availableMoves()
        guard !moves.isEmpty else { return nil }

        var bestScore = Int.min
        var bestMove = moves[0]

        for move in moves {
            var newBoard = board
            newBoard.place(.o, at: move)
            let score = minimax(board: newBoard, depth: 0, isMaximizing: false)
            if score > bestScore {
                bestScore = score
                bestMove = move
            }
        }
        return bestMove
    }

    private func minimax(board: TicTacToeBoard, depth: Int, isMaximizing: Bool) -> Int {
        if let winner = board.winner() {
            return winner == .o ? 10 - depth : depth - 10
        }
        if board.isDraw() { return 0 }

        let moves = board.availableMoves()

        if isMaximizing {
            var best = Int.min
            for move in moves {
                var newBoard = board
                newBoard.place(.o, at: move)
                best = max(best, minimax(board: newBoard, depth: depth + 1, isMaximizing: false))
            }
            return best
        } else {
            var best = Int.max
            for move in moves {
                var newBoard = board
                newBoard.place(.x, at: move)
                best = min(best, minimax(board: newBoard, depth: depth + 1, isMaximizing: true))
            }
            return best
        }
    }
}

// MARK: - ViewModel

class TicTacToeViewModel: ObservableObject {
    @Published var board = TicTacToeBoard()
    @Published var gameState: TicTacToeGameState = .playing
    @Published var xWins = 0
    @Published var oWins = 0
    @Published var draws = 0
    @Published var isAIThinking = false

    private let ai = TicTacToeAI()

    func playerTap(at index: Int) {
        guard gameState == .playing,
              board.cells[index] == .empty,
              !isAIThinking else { return }

        board.place(.x, at: index)
        checkState()

        if gameState == .playing {
            isAIThinking = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                self.aiMove()
            }
        }
    }

    private func aiMove() {
        guard gameState == .playing else {
            isAIThinking = false
            return
        }
        if let move = ai.bestMove(for: board) {
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
        board = TicTacToeBoard()
        gameState = .playing
        isAIThinking = false
    }
}

// MARK: - Cell View

struct TicTacToeCellView: View {
    let cell: TicTacToeCell
    let isWinningCell: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    isWinningCell
                        ? Color.yellow.opacity(0.25)
                        : Color(white: 0.15)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isWinningCell ? Color.yellow.opacity(0.7) : Color.white.opacity(0.08),
                            lineWidth: isWinningCell ? 2 : 1
                        )
                )

            switch cell {
            case .x:
                TicTacToeXShape()
                    .stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .padding(18)
                    .transition(.scale.combined(with: .opacity))
            case .o:
                Circle()
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 4))
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
            case .empty:
                EmptyView()
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: cell)
    }
}

// MARK: - X Shape

struct TicTacToeXShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return path
    }
}

// MARK: - Score Badge

struct TicTacToeScoreBadge: View {
    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color.opacity(0.85))
                .textCase(.uppercase)
                .tracking(1)
            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Main View

struct TicTacToeView: View {
    @StateObject private var vm = TicTacToeViewModel()

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
            return vm.isAIThinking ? Color.orange.opacity(0.8) : Color.cyan.opacity(0.9)
        case .xWins:
            return .cyan
        case .oWins:
            return .orange
        case .draw:
            return .gray
        }
    }

    var body: some View {
        ZStack {
            Color(white: 0.08).ignoresSafeArea()

            VStack(spacing: 24) {

                // Title
                Text("Tic-Tac-Toe")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Score row
                HStack(spacing: 12) {
                    TicTacToeScoreBadge(label: "You (X)", count: vm.xWins, color: .cyan)
                    TicTacToeScoreBadge(label: "Draw", count: vm.draws, color: .gray)
                    TicTacToeScoreBadge(label: "AI (O)", count: vm.oWins, color: .orange)
                }

                // Status
                Text(statusText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(statusColor)
                    .animation(.easeInOut(duration: 0.2), value: statusText)
                    .frame(height: 24)

                // Board
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { col in
                                let index = row * 3 + col
                                let isWinning = winningLine?.contains(index) ?? false

                                TicTacToeCellView(
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
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                // Restart button
                Button(action: { vm.restart() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                        Text("New Game")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - Preview

#Preview {
    TicTacToeView()
}

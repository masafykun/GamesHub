import SwiftUI

// MARK: - Private Model Types

private enum CheckersPiece: Equatable {
    case none, red, black, redKing, blackKing

    var isRed: Bool { self == .red || self == .redKing }
    var isBlack: Bool { self == .black || self == .blackKing }
    var isKing: Bool { self == .redKing || self == .blackKing }
    var isEmpty: Bool { self == .none }
}

private struct CheckersPosition: Equatable, Hashable {
    let row: Int
    let col: Int
}

private struct CheckersMove {
    let from: CheckersPosition
    let to: CheckersPosition
    let captured: CheckersPosition?
}

// MARK: - Game Logic

private class CheckersGame: ObservableObject {
    @Published var board: [[CheckersPiece]] = []
    @Published var selectedPos: CheckersPosition? = nil
    @Published var turn: CheckersPiece = .red  // red or black
    @Published var redCount: Int = 12
    @Published var blackCount: Int = 12
    @Published var winner: String? = nil
    @Published var validMoves: [CheckersMove] = []
    @Published var message: String = "Your turn (Red)"

    init() {
        setupBoard()
    }

    func setupBoard() {
        var b = Array(repeating: Array(repeating: CheckersPiece.none, count: 8), count: 8)
        for row in 0..<3 {
            for col in 0..<8 {
                if (row + col) % 2 == 1 {
                    b[row][col] = .black
                }
            }
        }
        for row in 5..<8 {
            for col in 0..<8 {
                if (row + col) % 2 == 1 {
                    b[row][col] = .red
                }
            }
        }
        board = b
        selectedPos = nil
        turn = .red
        redCount = 12
        blackCount = 12
        winner = nil
        validMoves = []
        message = "Your turn (Red)"
    }

    // All moves for a given player (forced capture if any)
    func allMoves(for player: CheckersPiece) -> [CheckersMove] {
        let isRedPlayer = player.isRed
        var captures: [CheckersMove] = []
        var normals: [CheckersMove] = []

        for row in 0..<8 {
            for col in 0..<8 {
                let piece = board[row][col]
                let belongs = isRedPlayer ? piece.isRed : piece.isBlack
                if belongs {
                    let pos = CheckersPosition(row: row, col: col)
                    let c = captureMoves(from: pos)
                    let n = normalMoves(from: pos)
                    captures.append(contentsOf: c)
                    normals.append(contentsOf: n)
                }
            }
        }
        return captures.isEmpty ? normals : captures
    }

    func movesFrom(_ pos: CheckersPosition) -> [CheckersMove] {
        let allValid = allMoves(for: turn)
        let hasCaptures = allValid.contains { $0.captured != nil }
        if hasCaptures {
            return captureMoves(from: pos)
        }
        return normalMoves(from: pos)
    }

    private func normalMoves(from pos: CheckersPosition) -> [CheckersMove] {
        let piece = board[pos.row][pos.col]
        var directions: [(Int, Int)] = []
        if piece == .red || piece == .redKing { directions.append((-1, -1)); directions.append((-1, 1)) }
        if piece == .black || piece == .blackKing { directions.append((1, -1)); directions.append((1, 1)) }
        if piece.isKing {
            directions = [(-1,-1),(-1,1),(1,-1),(1,1)]
        }
        var moves: [CheckersMove] = []
        for (dr, dc) in directions {
            let nr = pos.row + dr
            let nc = pos.col + dc
            if inBounds(nr, nc) && board[nr][nc].isEmpty {
                moves.append(CheckersMove(from: pos, to: CheckersPosition(row: nr, col: nc), captured: nil))
            }
        }
        return moves
    }

    private func captureMoves(from pos: CheckersPosition) -> [CheckersMove] {
        let piece = board[pos.row][pos.col]
        var directions: [(Int, Int)]
        if piece.isKing {
            directions = [(-1,-1),(-1,1),(1,-1),(1,1)]
        } else if piece.isRed {
            directions = [(-1,-1),(-1,1)]
        } else {
            directions = [(1,-1),(1,1)]
        }
        var moves: [CheckersMove] = []
        for (dr, dc) in directions {
            let mr = pos.row + dr
            let mc = pos.col + dc
            let lr = pos.row + 2*dr
            let lc = pos.col + 2*dc
            if inBounds(mr, mc) && inBounds(lr, lc) {
                let middle = board[mr][mc]
                let isEnemy = piece.isRed ? middle.isBlack : middle.isRed
                if isEnemy && board[lr][lc].isEmpty {
                    moves.append(CheckersMove(from: pos,
                                              to: CheckersPosition(row: lr, col: lc),
                                              captured: CheckersPosition(row: mr, col: mc)))
                }
            }
        }
        return moves
    }

    func select(pos: CheckersPosition) {
        guard winner == nil, turn == .red else { return }
        let piece = board[pos.row][pos.col]

        // If tapping a valid destination
        if let sel = selectedPos, let move = validMoves.first(where: { $0.to == pos }) {
            applyMove(move)
            selectedPos = nil
            validMoves = []
            checkWinner()
            if winner == nil {
                turn = .black
                message = "AI thinking..."
            }
            return
        }

        // Select red piece
        if piece.isRed {
            selectedPos = pos
            validMoves = movesFrom(pos)
            if validMoves.isEmpty { selectedPos = nil }
        } else {
            selectedPos = nil
            validMoves = []
        }
    }

    func applyMove(_ move: CheckersMove) {
        var piece = board[move.from.row][move.from.col]
        board[move.from.row][move.from.col] = .none
        if let cap = move.captured {
            board[cap.row][cap.col] = .none
            if piece.isRed { blackCount -= 1 } else { redCount -= 1 }
        }
        // Kinging
        if piece == .red && move.to.row == 0 { piece = .redKing }
        if piece == .black && move.to.row == 7 { piece = .blackKing }
        board[move.to.row][move.to.col] = piece
    }

    func checkWinner() {
        if blackCount == 0 { winner = "Red wins!"; return }
        if redCount == 0 { winner = "Black wins!"; return }
        if allMoves(for: .red).isEmpty { winner = "Black wins!"; return }
        if allMoves(for: .black).isEmpty { winner = "Red wins!"; return }
    }

    func aiMove() {
        guard winner == nil, turn == .black else { return }
        let moves = allMoves(for: .black)
        guard !moves.isEmpty else {
            winner = "Red wins!"
            return
        }
        // Prefer captures
        let captures = moves.filter { $0.captured != nil }
        let chosen = (captures.isEmpty ? moves : captures).randomElement()!
        applyMove(chosen)
        checkWinner()
        if winner == nil {
            turn = .red
            message = "Your turn (Red)"
        } else {
            message = winner!
        }
    }

    private func inBounds(_ r: Int, _ c: Int) -> Bool {
        r >= 0 && r < 8 && c >= 0 && c < 8
    }
}

// MARK: - View

struct CheckersView: View {
    @StateObject private var game = CheckersGame()

    private let lightSquare = Color(red: 0.87, green: 0.72, blue: 0.53)
    private let darkSquare  = Color(red: 0.45, green: 0.28, blue: 0.12)
    private let boardBorder = Color(red: 0.30, green: 0.18, blue: 0.08)

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                titleBar
                scoreBar
                boardView
                messageView
                newGameButton
            }
            .padding()

            if game.winner != nil {
                winnerOverlay
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in }
        .onChange(of: game.turn) { newTurn in
            if newTurn == .black {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    game.aiMove()
                }
            }
        }
    }

    private var titleBar: some View {
        Text("Checkers")
            .font(.largeTitle.bold())
            .foregroundColor(.primary)
    }

    private var scoreBar: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Circle().fill(Color.red).frame(width: 16, height: 16)
                Text("Red: \(game.redCount)")
                    .font(.headline)
                    .foregroundColor(game.turn == .red ? .red : .secondary)
            }
            Spacer()
            HStack(spacing: 6) {
                Text("Black: \(game.blackCount)")
                    .font(.headline)
                    .foregroundColor(game.turn == .black ? .primary : .secondary)
                Circle().fill(Color.primary).frame(width: 16, height: 16)
            }
        }
        .padding(.horizontal, 8)
    }

    private var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(boardBorder)
                    .frame(width: size + 8, height: size + 8)
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                cellView(row: row, col: col, size: cell)
                            }
                        }
                    }
                }
                .frame(width: size, height: size)
            }
            .frame(width: size + 8, height: size + 8)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isDark = (row + col) % 2 == 1
        let pos = CheckersPosition(row: row, col: col)
        let isSelected = game.selectedPos == pos
        let isValidDest = game.validMoves.contains { $0.to == pos }
        let piece = game.board[row][col]

        ZStack {
            Rectangle()
                .fill(isDark ? darkSquare : lightSquare)

            if isSelected {
                Rectangle().fill(Color.yellow.opacity(0.45))
            }
            if isValidDest {
                Circle()
                    .fill(Color.green.opacity(0.45))
                    .padding(size * 0.28)
            }

            if piece != .none {
                pieceView(piece: piece, size: size)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture {
            game.select(pos: pos)
        }
    }

    @ViewBuilder
    private func pieceView(piece: CheckersPiece, size: CGFloat) -> some View {
        let isRed = piece.isRed
        let color: Color = isRed ? .red : Color(.label)
        ZStack {
            Circle()
                .fill(color)
                .shadow(color: .black.opacity(0.4), radius: 3, x: 2, y: 2)
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.3), .clear]),
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.4
                    )
                )
            if piece.isKing {
                Text("♛")
                    .font(.system(size: size * 0.32))
                    .foregroundColor(.white)
            }
        }
        .padding(size * 0.1)
    }

    private var messageView: some View {
        Text(game.winner ?? game.message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var newGameButton: some View {
        Button(action: { game.setupBoard() }) {
            Text("New Game")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
        }
    }

    private var winnerOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Text(game.winner ?? "")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Button(action: { game.setupBoard() }) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
            .padding(40)
            .background(Color(.systemGray3).opacity(0.95))
            .cornerRadius(20)
        }
    }
}

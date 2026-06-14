import SwiftUI

// MARK: - Private Model Types (V3)

private enum CheckersV3Piece: Equatable {
    case none, red, black, redKing, blackKing

    var isRed: Bool { self == .red || self == .redKing }
    var isBlack: Bool { self == .black || self == .blackKing }
    var isKing: Bool { self == .redKing || self == .blackKing }
    var isEmpty: Bool { self == .none }
}

private struct CheckersV3Position: Equatable, Hashable {
    let row: Int
    let col: Int
}

private struct CheckersV3Move {
    let from: CheckersV3Position
    let to: CheckersV3Position
    let captured: CheckersV3Position?
}

// MARK: - Game Logic (V3)

private class CheckersV3Game: ObservableObject {
    @Published var board: [[CheckersV3Piece]] = []
    @Published var selectedPos: CheckersV3Position? = nil
    @Published var turn: CheckersV3Piece = .red
    @Published var redCount: Int = 12
    @Published var blackCount: Int = 12
    @Published var winner: String? = nil
    @Published var validMoves: [CheckersV3Move] = []
    @Published var message: String = "Your turn (Red)"

    init() { setupBoard() }

    func setupBoard() {
        var b = Array(repeating: Array(repeating: CheckersV3Piece.none, count: 8), count: 8)
        for row in 0..<3 {
            for col in 0..<8 where (row + col) % 2 == 1 { b[row][col] = .black }
        }
        for row in 5..<8 {
            for col in 0..<8 where (row + col) % 2 == 1 { b[row][col] = .red }
        }
        board = b; selectedPos = nil; turn = .red
        redCount = 12; blackCount = 12; winner = nil; validMoves = []
        message = "Your turn (Red)"
    }

    func allMoves(for player: CheckersV3Piece) -> [CheckersV3Move] {
        let isRedPlayer = player.isRed
        var captures: [CheckersV3Move] = []
        var normals: [CheckersV3Move] = []
        for row in 0..<8 {
            for col in 0..<8 {
                let piece = board[row][col]
                let belongs = isRedPlayer ? piece.isRed : piece.isBlack
                if belongs {
                    let pos = CheckersV3Position(row: row, col: col)
                    captures.append(contentsOf: captureMoves(from: pos))
                    normals.append(contentsOf: normalMoves(from: pos))
                }
            }
        }
        return captures.isEmpty ? normals : captures
    }

    func movesFrom(_ pos: CheckersV3Position) -> [CheckersV3Move] {
        let all = allMoves(for: turn)
        let hasCaptures = all.contains { $0.captured != nil }
        return hasCaptures ? captureMoves(from: pos) : normalMoves(from: pos)
    }

    private func dirs(for piece: CheckersV3Piece) -> [(Int, Int)] {
        if piece.isKing { return [(-1,-1),(-1,1),(1,-1),(1,1)] }
        if piece.isRed  { return [(-1,-1),(-1,1)] }
        return [(1,-1),(1,1)]
    }

    private func normalMoves(from pos: CheckersV3Position) -> [CheckersV3Move] {
        let piece = board[pos.row][pos.col]
        return dirs(for: piece).compactMap { (dr, dc) in
            let nr = pos.row + dr; let nc = pos.col + dc
            guard inBounds(nr, nc) && board[nr][nc].isEmpty else { return nil }
            return CheckersV3Move(from: pos, to: CheckersV3Position(row: nr, col: nc), captured: nil)
        }
    }

    private func captureMoves(from pos: CheckersV3Position) -> [CheckersV3Move] {
        let piece = board[pos.row][pos.col]
        return dirs(for: piece).compactMap { (dr, dc) in
            let mr = pos.row + dr; let mc = pos.col + dc
            let lr = pos.row + 2*dr; let lc = pos.col + 2*dc
            guard inBounds(mr, mc) && inBounds(lr, lc) else { return nil }
            let mid = board[mr][mc]
            let isEnemy = piece.isRed ? mid.isBlack : mid.isRed
            guard isEnemy && board[lr][lc].isEmpty else { return nil }
            return CheckersV3Move(from: pos,
                                  to: CheckersV3Position(row: lr, col: lc),
                                  captured: CheckersV3Position(row: mr, col: mc))
        }
    }

    func select(pos: CheckersV3Position) {
        guard winner == nil, turn == .red else { return }
        let piece = board[pos.row][pos.col]
        if let _ = selectedPos, let move = validMoves.first(where: { $0.to == pos }) {
            applyMove(move); selectedPos = nil; validMoves = []
            checkWinner()
            if winner == nil { turn = .black; message = "AI thinking..." }
            return
        }
        if piece.isRed {
            selectedPos = pos
            validMoves = movesFrom(pos)
            if validMoves.isEmpty { selectedPos = nil }
        } else {
            selectedPos = nil; validMoves = []
        }
    }

    func applyMove(_ move: CheckersV3Move) {
        var piece = board[move.from.row][move.from.col]
        board[move.from.row][move.from.col] = .none
        if let cap = move.captured {
            board[cap.row][cap.col] = .none
            if piece.isRed { blackCount -= 1 } else { redCount -= 1 }
        }
        if piece == .red && move.to.row == 0 { piece = .redKing }
        if piece == .black && move.to.row == 7 { piece = .blackKing }
        board[move.to.row][move.to.col] = piece
    }

    func checkWinner() {
        if blackCount == 0 { winner = "Red wins!"; return }
        if redCount == 0   { winner = "Black wins!"; return }
        if allMoves(for: .red).isEmpty   { winner = "Black wins!"; return }
        if allMoves(for: .black).isEmpty { winner = "Red wins!"; return }
    }

    func aiMove() {
        guard winner == nil, turn == .black else { return }
        let moves = allMoves(for: .black)
        guard !moves.isEmpty else { winner = "Red wins!"; return }
        let captures = moves.filter { $0.captured != nil }
        let chosen = (captures.isEmpty ? moves : captures).randomElement()!
        applyMove(chosen); checkWinner()
        if winner == nil { turn = .red; message = "Your turn (Red)" }
        else { message = winner! }
    }

    private func inBounds(_ r: Int, _ c: Int) -> Bool { r >= 0 && r < 8 && c >= 0 && c < 8 }
}

// MARK: - Neumorphic Helpers

private extension View {
    func neuCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(Color(.systemGray6))
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
            .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    func neuInset(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(Color(.systemGray5))
            .cornerRadius(cornerRadius)
            .shadow(color: .white.opacity(0.7), radius: 4, x: 2, y: 2)
            .shadow(color: .black.opacity(0.15), radius: 4, x: -2, y: -2)
    }
}

// MARK: - Neumorphism View (V3)

struct CheckersViewV3: View {
    @StateObject private var game = CheckersV3Game()

    private let bgColor = Color(.systemGray6)
    private let darkSq  = Color(red: 0.60, green: 0.50, blue: 0.42)
    private let lightSq = Color(red: 0.88, green: 0.82, blue: 0.75)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            VStack(spacing: 16) {
                neuTitleBar
                neuScoreBar
                neuBoardView
                neuMessage
                neuNewGameButton
            }
            .padding()

            if game.winner != nil {
                neuWinnerOverlay
            }
        }
        .onChange(of: game.turn) { newTurn in
            if newTurn == .black {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    game.aiMove()
                }
            }
        }
    }

    // MARK: Neumorphic Components

    private var neuTitleBar: some View {
        Text("Checkers")
            .font(.largeTitle.bold())
            .foregroundColor(Color(.label))
            .padding(.vertical, 12)
    }

    private var neuScoreBar: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 2)
                        .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Red").font(.caption).foregroundColor(.secondary)
                    Text("\(game.redCount)").font(.title3.bold())
                        .foregroundColor(game.turn == .red ? .red : Color(.label).opacity(0.5))
                }
            }
            Spacer()
            VStack(spacing: 2) {
                Text("VS").font(.caption.bold()).foregroundColor(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Black").font(.caption).foregroundColor(.secondary)
                    Text("\(game.blackCount)").font(.title3.bold())
                        .foregroundColor(game.turn == .black ? Color(.label) : Color(.label).opacity(0.5))
                }
                ZStack {
                    Circle()
                        .fill(Color(red: 0.20, green: 0.15, blue: 0.12))
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 2)
                        .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .neuCard()
    }

    private var neuBoardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgColor)
                    .frame(width: size + 20, height: size + 20)
                    .shadow(color: .black.opacity(0.18), radius: 12, x: 6, y: 6)
                    .shadow(color: .white.opacity(0.7), radius: 12, x: -6, y: -6)

                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                neuCellView(row: row, col: col, size: cell)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: size, height: size)
            }
            .frame(width: size + 20, height: size + 20)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func neuCellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isDark = (row + col) % 2 == 1
        let pos = CheckersV3Position(row: row, col: col)
        let isSelected = game.selectedPos == pos
        let isValidDest = game.validMoves.contains { $0.to == pos }
        let piece = game.board[row][col]

        ZStack {
            Rectangle()
                .fill(isDark ? darkSq : lightSq)

            if isSelected {
                Rectangle()
                    .fill(Color.yellow.opacity(0.35))
            }
            if isValidDest {
                // Inset "pressed" ring for valid destination
                Circle()
                    .fill(Color.green.opacity(0.25))
                    .overlay(
                        Circle()
                            .stroke(Color.green.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.5), radius: 3, x: -2, y: -2)
                    .padding(size * 0.25)
            }
            if piece != .none {
                neuV3PieceView(piece: piece, size: size)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture { game.select(pos: pos) }
    }

    @ViewBuilder
    private func neuV3PieceView(piece: CheckersV3Piece, size: CGFloat) -> some View {
        let isRed = piece.isRed
        let baseColor: Color = isRed ? Color.red.opacity(0.85) : Color(red: 0.18, green: 0.13, blue: 0.10)
        let shadowDark: Color = isRed ? Color(red: 0.6, green: 0.0, blue: 0.0).opacity(0.4) : Color.black.opacity(0.4)

        ZStack {
            // Outer raised circle (neumorphic)
            Circle()
                .fill(baseColor)
                .shadow(color: shadowDark, radius: 5, x: 3, y: 3)
                .shadow(color: Color.white.opacity(isRed ? 0.4 : 0.15), radius: 5, x: -3, y: -3)

            // Inner highlight ring (inset effect)
            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 1.5)
                .padding(size * 0.04)

            if piece.isKing {
                // King crown indicator: inset circle + symbol
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .padding(size * 0.15)
                    .shadow(color: shadowDark, radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.5), radius: 3, x: -2, y: -2)
                Text("♛")
                    .font(.system(size: size * 0.28))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(size * 0.10)
    }

    private var neuMessage: some View {
        Text(game.winner ?? game.message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .neuInset()
    }

    private var neuNewGameButton: some View {
        Button(action: { game.setupBoard() }) {
            Text("New Game")
                .font(.headline.bold())
                .foregroundColor(Color(.label))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(bgColor)
                .cornerRadius(14)
                .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
        }
    }

    private var neuWinnerOverlay: some View {
        ZStack {
            bgColor.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(game.winner ?? "")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(Color(.label))

                Button(action: { game.setupBoard() }) {
                    Text("Play Again")
                        .font(.headline.bold())
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(bgColor)
                        .cornerRadius(14)
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                        .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
                }
            }
            .padding(40)
            .background(bgColor)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.18), radius: 16, x: 8, y: 8)
            .shadow(color: .white.opacity(0.7), radius: 16, x: -8, y: -8)
        }
    }
}

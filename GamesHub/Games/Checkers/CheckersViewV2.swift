import SwiftUI

// MARK: - Private Model Types (V2)

private enum CheckersV2Piece: Equatable {
    case none, red, black, redKing, blackKing

    var isRed: Bool { self == .red || self == .redKing }
    var isBlack: Bool { self == .black || self == .blackKing }
    var isKing: Bool { self == .redKing || self == .blackKing }
    var isEmpty: Bool { self == .none }
}

private struct CheckersV2Position: Equatable, Hashable {
    let row: Int
    let col: Int
}

private struct CheckersV2Move {
    let from: CheckersV2Position
    let to: CheckersV2Position
    let captured: CheckersV2Position?
}

// MARK: - Game Logic (V2)

private class CheckersV2Game: ObservableObject {
    @Published var board: [[CheckersV2Piece]] = []
    @Published var selectedPos: CheckersV2Position? = nil
    @Published var turn: CheckersV2Piece = .red
    @Published var redCount: Int = 12
    @Published var blackCount: Int = 12
    @Published var winner: String? = nil
    @Published var validMoves: [CheckersV2Move] = []
    @Published var message: String = "Your turn (Red)"

    init() { setupBoard() }

    func setupBoard() {
        var b = Array(repeating: Array(repeating: CheckersV2Piece.none, count: 8), count: 8)
        for row in 0..<3 {
            for col in 0..<8 where (row + col) % 2 == 1 {
                b[row][col] = .black
            }
        }
        for row in 5..<8 {
            for col in 0..<8 where (row + col) % 2 == 1 {
                b[row][col] = .red
            }
        }
        board = b; selectedPos = nil; turn = .red
        redCount = 12; blackCount = 12; winner = nil; validMoves = []
        message = "Your turn (Red)"
    }

    func allMoves(for player: CheckersV2Piece) -> [CheckersV2Move] {
        let isRedPlayer = player.isRed
        var captures: [CheckersV2Move] = []
        var normals: [CheckersV2Move] = []
        for row in 0..<8 {
            for col in 0..<8 {
                let piece = board[row][col]
                let belongs = isRedPlayer ? piece.isRed : piece.isBlack
                if belongs {
                    let pos = CheckersV2Position(row: row, col: col)
                    captures.append(contentsOf: captureMoves(from: pos))
                    normals.append(contentsOf: normalMoves(from: pos))
                }
            }
        }
        return captures.isEmpty ? normals : captures
    }

    func movesFrom(_ pos: CheckersV2Position) -> [CheckersV2Move] {
        let all = allMoves(for: turn)
        let hasCaptures = all.contains { $0.captured != nil }
        return hasCaptures ? captureMoves(from: pos) : normalMoves(from: pos)
    }

    private func dirs(for piece: CheckersV2Piece) -> [(Int, Int)] {
        if piece.isKing { return [(-1,-1),(-1,1),(1,-1),(1,1)] }
        if piece.isRed  { return [(-1,-1),(-1,1)] }
        return [(1,-1),(1,1)]
    }

    private func normalMoves(from pos: CheckersV2Position) -> [CheckersV2Move] {
        let piece = board[pos.row][pos.col]
        return dirs(for: piece).compactMap { (dr, dc) in
            let nr = pos.row + dr; let nc = pos.col + dc
            guard inBounds(nr, nc) && board[nr][nc].isEmpty else { return nil }
            return CheckersV2Move(from: pos, to: CheckersV2Position(row: nr, col: nc), captured: nil)
        }
    }

    private func captureMoves(from pos: CheckersV2Position) -> [CheckersV2Move] {
        let piece = board[pos.row][pos.col]
        return dirs(for: piece).compactMap { (dr, dc) in
            let mr = pos.row + dr; let mc = pos.col + dc
            let lr = pos.row + 2*dr; let lc = pos.col + 2*dc
            guard inBounds(mr, mc) && inBounds(lr, lc) else { return nil }
            let mid = board[mr][mc]
            let isEnemy = piece.isRed ? mid.isBlack : mid.isRed
            guard isEnemy && board[lr][lc].isEmpty else { return nil }
            return CheckersV2Move(from: pos,
                                  to: CheckersV2Position(row: lr, col: lc),
                                  captured: CheckersV2Position(row: mr, col: mc))
        }
    }

    func select(pos: CheckersV2Position) {
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

    func applyMove(_ move: CheckersV2Move) {
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

// MARK: - Glassmorphism View (V2)

struct CheckersViewV2: View {
    @StateObject private var game = CheckersV2Game()

    // Glass board colors
    private let darkSq  = Color(red: 0.25, green: 0.15, blue: 0.40)
    private let lightSq = Color(red: 0.55, green: 0.40, blue: 0.70).opacity(0.35)

    private var bgGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.20),
                Color(red: 0.10, green: 0.05, blue: 0.30),
                Color(red: 0.15, green: 0.10, blue: 0.35)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            bgGradient.ignoresSafeArea()
            // Decorative glows
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -200)
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 250, height: 250)
                .blur(radius: 70)
                .offset(x: 100, y: 250)

            VStack(spacing: 16) {
                glassTitle
                glassScoreBar
                glassBoardView
                glassMessage
                glassNewGameButton
            }
            .padding()

            if game.winner != nil {
                glassWinnerOverlay
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

    // MARK: Glass Components

    private var glassTitle: some View {
        Text("Checkers")
            .font(.largeTitle.bold())
            .foregroundColor(.white)
            .shadow(color: Color.purple.opacity(0.6), radius: 12)
    }

    private var glassScoreBar: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.red.opacity(0.7), radius: 6)
                Text("Red: \(game.redCount)")
                    .font(.headline)
                    .foregroundColor(game.turn == .red ? .white : Color.white.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 8) {
                Text("Black: \(game.blackCount)")
                    .font(.headline)
                    .foregroundColor(game.turn == .black ? .white : Color.white.opacity(0.5))
                Circle()
                    .fill(Color(red: 0.15, green: 0.08, blue: 0.25))
                    .frame(width: 14, height: 14)
                    .shadow(color: Color.purple.opacity(0.7), radius: 6)
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.purple.opacity(0.4), radius: 20)
    }

    private var glassBoardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cell = size / 8
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: size + 16, height: size + 16)
                    .shadow(color: Color.purple.opacity(0.4), radius: 20)
                    .shadow(color: Color.blue.opacity(0.3), radius: 30)
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<8, id: \.self) { col in
                                glassCellView(row: row, col: col, size: cell)
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(width: size, height: size)
            }
            .frame(width: size + 16, height: size + 16)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func glassCellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isDark = (row + col) % 2 == 1
        let pos = CheckersV2Position(row: row, col: col)
        let isSelected = game.selectedPos == pos
        let isValidDest = game.validMoves.contains { $0.to == pos }
        let piece = game.board[row][col]

        ZStack {
            Rectangle()
                .fill(isDark ? darkSq : lightSq)
            if isSelected {
                Rectangle().fill(Color.yellow.opacity(0.30))
            }
            if isValidDest {
                Circle()
                    .fill(Color.green.opacity(0.35))
                    .shadow(color: Color.green.opacity(0.6), radius: 8)
                    .padding(size * 0.28)
            }
            if piece != .none {
                glassV2PieceView(piece: piece, size: size)
            }
        }
        .frame(width: size, height: size)
        .onTapGesture { game.select(pos: pos) }
    }

    @ViewBuilder
    private func glassV2PieceView(piece: CheckersV2Piece, size: CGFloat) -> some View {
        let isRed = piece.isRed
        let baseColor: Color = isRed ? Color.red : Color(red: 0.12, green: 0.06, blue: 0.22)
        let glowColor: Color = isRed ? Color.red : Color.purple

        ZStack {
            Circle()
                .fill(baseColor)
                .shadow(color: glowColor.opacity(0.5), radius: 10)
            // Gloss highlight
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.white.opacity(0.35), .clear]),
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: size * 0.4
                    )
                )
            // Outer ring
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.2)
            if piece.isKing {
                Text("♛")
                    .font(.system(size: size * 0.30))
                    .foregroundColor(.white)
                    .shadow(color: .white.opacity(0.8), radius: 4)
            }
        }
        .padding(size * 0.10)
    }

    private var glassMessage: some View {
        Text(game.winner ?? game.message)
            .font(.subheadline)
            .foregroundColor(Color.white.opacity(0.75))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var glassNewGameButton: some View {
        Button(action: { game.setupBoard() }) {
            Text("New Game")
                .font(.headline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.purple, Color.blue]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.purple.opacity(0.5), radius: 12)
        }
    }

    private var glassWinnerOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 24) {
                Text(game.winner ?? "")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: Color.purple.opacity(0.8), radius: 16)
                Button(action: { game.setupBoard() }) {
                    Text("Play Again")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.purple, Color.blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: Color.purple.opacity(0.5), radius: 12)
                }
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.purple.opacity(0.4), radius: 24)
        }
    }
}

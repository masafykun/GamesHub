import SwiftUI

// MARK: - Models

enum SkbnGamePhase { case start, playing, complete }
enum SkbnMoveDir { case up, down, left, right }

struct SkbnPos: Equatable, Hashable {
    var col: Int
    var row: Int
}

struct SkbnGameState {
    var playerPos: SkbnPos
    var boxes: Set<SkbnPos>
    var targets: Set<SkbnPos>
    var walls: Set<SkbnPos>
    var moves: Int
    var history: [(player: SkbnPos, boxes: Set<SkbnPos>)]

    var isComplete: Bool { boxes == targets }
}

// MARK: - Levels
// Legend: W=wall, .=floor, P=player, B=box, T=target, X=box on target

private let skbnLevels: [[String]] = [
    [
        "WWWWWWWW",
        "W......W",
        "W.B..T.W",
        "W......W",
        "W.T..B.W",
        "W...P..W",
        "W......W",
        "WWWWWWWW"
    ],
    [
        "WWWWWWWW",
        "W.....WW",
        "W.B.T..W",
        "WW..B..W",
        "W.T....W",
        "W..P...W",
        "W...B.TW",
        "WWWWWWWW"
    ],
    [
        "WWWWWWWW",
        "WW.....W",
        "W.B.B..W",
        "W.TTT..W",
        "W......W",
        "WW..P..W",
        "W......W",
        "WWWWWWWW"
    ],
    [
        "WWWWWWWW",
        "W......W",
        "W.B.B.BW",
        "W......W",
        "W.T.T.TW",
        "W......W",
        "W...P..W",
        "WWWWWWWW"
    ]
]

private func skbnParseLevel(_ lines: [String]) -> SkbnGameState {
    var player = SkbnPos(col: 0, row: 0)
    var boxes: Set<SkbnPos> = []
    var targets: Set<SkbnPos> = []
    var walls: Set<SkbnPos> = []
    for (r, line) in lines.enumerated() {
        for (c, ch) in line.enumerated() {
            let pos = SkbnPos(col: c, row: r)
            switch ch {
            case "W": walls.insert(pos)
            case "P": player = pos
            case "B": boxes.insert(pos)
            case "T": targets.insert(pos)
            case "X": boxes.insert(pos); targets.insert(pos)
            default: break
            }
        }
    }
    return SkbnGameState(playerPos: player, boxes: boxes, targets: targets, walls: walls, moves: 0, history: [])
}

// MARK: - View

struct SokobanView: View {
    @State private var phase: SkbnGamePhase = .start
    @State private var levelIndex: Int = 0
    @State private var game: SkbnGameState = skbnParseLevel(skbnLevels[0])
    @State private var totalMoves: Int = 0

    let cellSize: CGFloat = 38

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("SOKOBAN")
                .font(.system(size: 42, weight: .black, design: .monospaced))
                .foregroundColor(.yellow)
            Text("Push all boxes\nonto the targets")
                .font(.system(size: 16, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Text("Swipe to move")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray.opacity(0.7))
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    var gameScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LVL \(levelIndex + 1)/\(skbnLevels.count)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.yellow)
                Spacer()
                Text("MOVES: \(game.moves)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            gridView
                .gesture(DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        let h = value.translation.width
                        let v = value.translation.height
                        if abs(h) > abs(v) {
                            move(h > 0 ? .right : .left)
                        } else {
                            move(v > 0 ? .down : .up)
                        }
                    }
                )

            HStack(spacing: 20) {
                Button(action: undoMove) {
                    Text("UNDO")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button(action: resetLevel) {
                    Text("RESET")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.gray)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    var gridView: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { col in
                        cellView(pos: SkbnPos(col: col, row: row))
                    }
                }
            }
        }
    }

    func cellView(pos: SkbnPos) -> some View {
        let isWall = game.walls.contains(pos)
        let isPlayer = game.playerPos == pos
        let isBox = game.boxes.contains(pos)
        let isTarget = game.targets.contains(pos)
        let boxOnTarget = isBox && isTarget

        return ZStack {
            Rectangle()
                .fill(isWall ? Color(white: 0.25) : Color(white: 0.1))
                .frame(width: cellSize, height: cellSize)
            if isTarget && !isBox {
                Text("*")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.green)
            }
            if isBox {
                RoundedRectangle(cornerRadius: 4)
                    .fill(boxOnTarget ? Color.green : Color.orange)
                    .frame(width: cellSize - 6, height: cellSize - 6)
                Text("#")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
            }
            if isPlayer {
                Text("@")
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.cyan)
            }
        }
    }

    var completeScreen: some View {
        VStack(spacing: 20) {
            Text("LEVEL CLEAR!")
                .font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundColor(.green)
            Text("Moves: \(totalMoves)")
                .font(.system(size: 18, design: .monospaced))
                .foregroundColor(.white)
            if levelIndex + 1 < skbnLevels.count {
                Button(action: nextLevel) {
                    Text("NEXT LEVEL")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                Text("All levels complete!")
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundColor(.yellow)
                Button(action: startGame) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.black)
                        .padding(.horizontal, 30).padding(.vertical, 12)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Button(action: { phase = .start }) {
                Text("MENU")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }

    func startGame() {
        levelIndex = 0
        game = skbnParseLevel(skbnLevels[0])
        totalMoves = 0
        phase = .playing
    }

    func resetLevel() {
        game = skbnParseLevel(skbnLevels[levelIndex])
    }

    func nextLevel() {
        levelIndex += 1
        game = skbnParseLevel(skbnLevels[levelIndex])
        phase = .playing
    }

    func move(_ dir: SkbnMoveDir) {
        let delta: SkbnPos
        switch dir {
        case .up:    delta = SkbnPos(col: 0, row: -1)
        case .down:  delta = SkbnPos(col: 0, row: 1)
        case .left:  delta = SkbnPos(col: -1, row: 0)
        case .right: delta = SkbnPos(col: 1, row: 0)
        }
        let newPlayer = SkbnPos(col: game.playerPos.col + delta.col, row: game.playerPos.row + delta.row)
        guard !game.walls.contains(newPlayer) else { return }

        if game.boxes.contains(newPlayer) {
            let newBox = SkbnPos(col: newPlayer.col + delta.col, row: newPlayer.row + delta.row)
            guard !game.walls.contains(newBox), !game.boxes.contains(newBox) else { return }
            game.history.append((player: game.playerPos, boxes: game.boxes))
            game.boxes.remove(newPlayer)
            game.boxes.insert(newBox)
        } else {
            game.history.append((player: game.playerPos, boxes: game.boxes))
        }
        game.playerPos = newPlayer
        game.moves += 1

        if game.isComplete {
            totalMoves = game.moves
            phase = .complete
        }
    }

    func undoMove() {
        guard let last = game.history.popLast() else { return }
        game.playerPos = last.player
        game.boxes = last.boxes
        game.moves = max(0, game.moves - 1)
    }
}

#Preview { SokobanView() }

import SwiftUI

// MARK: - Models (V2)

enum SkbnV2Phase { case start, playing, complete }
enum SkbnV2Dir { case up, down, left, right }

struct SkbnV2Pos: Equatable, Hashable {
    var col: Int
    var row: Int
}

struct SkbnV2State {
    var playerPos: SkbnV2Pos
    var boxes: Set<SkbnV2Pos>
    var targets: Set<SkbnV2Pos>
    var walls: Set<SkbnV2Pos>
    var moves: Int
    var history: [(player: SkbnV2Pos, boxes: Set<SkbnV2Pos>)]

    var isComplete: Bool { boxes == targets }
}

// MARK: - Levels (V2)

private let skbnV2Levels: [[String]] = [
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

private func skbnV2ParseLevel(_ lines: [String]) -> SkbnV2State {
    var player = SkbnV2Pos(col: 0, row: 0)
    var boxes: Set<SkbnV2Pos> = []
    var targets: Set<SkbnV2Pos> = []
    var walls: Set<SkbnV2Pos> = []
    for (r, line) in lines.enumerated() {
        for (c, ch) in line.enumerated() {
            let pos = SkbnV2Pos(col: c, row: r)
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
    return SkbnV2State(playerPos: player, boxes: boxes, targets: targets, walls: walls, moves: 0, history: [])
}

// MARK: - Adaptive Difficulty

private func skbnV2DifficultyMultiplier(results: [Bool]) -> Double {
    let recent = results.suffix(5)
    guard recent.count == 5 else { return 1.0 }
    let successCount = recent.filter { $0 }.count
    return successCount > 4 ? 1.2 : 1.0
}

// MARK: - View (V2)

struct SokobanViewV2: View {
    @State private var phase: SkbnV2Phase = .start
    @State private var levelIndex: Int = 0
    @State private var game: SkbnV2State = skbnV2ParseLevel(skbnV2Levels[0])
    @State private var totalMoves: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var moveLimit: Int = 40

    private let baseMoveLimit = 40
    let cellSize: CGFloat = 36

    var difficultyLabel: String {
        let mult = skbnV2DifficultyMultiplier(results: recentResults)
        return mult > 1.0 ? "HARD" : "NORMAL"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.0, blue: 0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("SOKOBAN")
                .font(.system(size: 44, weight: .black, design: .monospaced))
                .foregroundColor(.white)
            Text("Push boxes onto targets.\nAdaptive difficulty adjusts\nbased on your performance.")
                .font(.system(size: 14))
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            Button(action: startGame) {
                Text("START GAME")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(24)
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL \(levelIndex + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                    Text(difficultyLabel)
                        .font(.system(size: 11))
                        .foregroundColor(difficultyLabel == "HARD" ? .orange : .green)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MOVES: \(game.moves)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("LIMIT: \(moveLimit)")
                        .font(.system(size: 11))
                        .foregroundColor(game.moves > moveLimit - 5 ? .red : .white.opacity(0.6))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 16)

            gridView
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
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

            HStack(spacing: 14) {
                actionButton("UNDO", color: .orange) { undoMove() }
                actionButton("RESET", color: Color(white: 0.5)) { resetLevel() }
            }
        }
    }

    var gridView: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { col in
                        cellView(pos: SkbnV2Pos(col: col, row: row))
                    }
                }
            }
        }
    }

    func cellView(pos: SkbnV2Pos) -> some View {
        let isWall = game.walls.contains(pos)
        let isPlayer = game.playerPos == pos
        let isBox = game.boxes.contains(pos)
        let isTarget = game.targets.contains(pos)
        let boxOnTarget = isBox && isTarget

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isWall
                      ? Color.white.opacity(0.12)
                      : Color.white.opacity(0.04))
                .frame(width: cellSize, height: cellSize)
            if isTarget && !isBox {
                Circle()
                    .fill(Color.green.opacity(0.5))
                    .frame(width: 10, height: 10)
            }
            if isBox {
                RoundedRectangle(cornerRadius: 5)
                    .fill(boxOnTarget
                          ? LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
                          : LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: cellSize - 5, height: cellSize - 5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            if isPlayer {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                    .frame(width: cellSize - 8, height: cellSize - 8)
                    .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
    }

    func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(color.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
        }
    }

    var completeScreen: some View {
        VStack(spacing: 22) {
            let withinLimit = game.moves <= moveLimit
            Text(withinLimit ? "LEVEL CLEAR!" : "COMPLETE")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(withinLimit ? .green : .yellow)
            Text("Moves: \(game.moves) / Limit: \(moveLimit)")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.8))
            Text("Difficulty: \(difficultyLabel)")
                .font(.system(size: 13))
                .foregroundColor(difficultyLabel == "HARD" ? .orange : .green)

            if levelIndex + 1 < skbnV2Levels.count {
                actionButton("NEXT LEVEL", color: .green) { nextLevel() }
            } else {
                actionButton("PLAY AGAIN", color: .purple) { startGame() }
            }
            Button(action: { phase = .start }) {
                Text("MENU")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(24)
    }

    func startGame() {
        levelIndex = 0
        recentResults = []
        let mult = skbnV2DifficultyMultiplier(results: recentResults)
        moveLimit = Int(Double(baseMoveLimit) / mult)
        game = skbnV2ParseLevel(skbnV2Levels[0])
        totalMoves = 0
        phase = .playing
    }

    func resetLevel() {
        game = skbnV2ParseLevel(skbnV2Levels[levelIndex])
    }

    func nextLevel() {
        let success = game.moves <= moveLimit
        recentResults.append(success)
        levelIndex += 1
        let mult = skbnV2DifficultyMultiplier(results: recentResults)
        moveLimit = Int(Double(baseMoveLimit) / mult)
        game = skbnV2ParseLevel(skbnV2Levels[levelIndex])
        phase = .playing
    }

    func move(_ dir: SkbnV2Dir) {
        let delta: SkbnV2Pos
        switch dir {
        case .up:    delta = SkbnV2Pos(col: 0, row: -1)
        case .down:  delta = SkbnV2Pos(col: 0, row: 1)
        case .left:  delta = SkbnV2Pos(col: -1, row: 0)
        case .right: delta = SkbnV2Pos(col: 1, row: 0)
        }
        let newPlayer = SkbnV2Pos(col: game.playerPos.col + delta.col, row: game.playerPos.row + delta.row)
        guard !game.walls.contains(newPlayer) else { return }

        if game.boxes.contains(newPlayer) {
            let newBox = SkbnV2Pos(col: newPlayer.col + delta.col, row: newPlayer.row + delta.row)
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

#Preview { SokobanViewV2() }

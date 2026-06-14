import SwiftUI

// MARK: - LCG Random (V3)

struct SkbnLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models (V3)

enum SkbnV3Phase { case start, playing, complete }
enum SkbnV3Dir { case up, down, left, right }

struct SkbnV3Pos: Equatable, Hashable {
    var col: Int
    var row: Int
}

struct SkbnV3State {
    var playerPos: SkbnV3Pos
    var boxes: Set<SkbnV3Pos>
    var targets: Set<SkbnV3Pos>
    var walls: Set<SkbnV3Pos>
    var moves: Int
    var history: [(player: SkbnV3Pos, boxes: Set<SkbnV3Pos>)]

    var isComplete: Bool { boxes == targets }
}

// MARK: - Procedural Level Generation

private func skbnV3GenerateLevel(seed: Int) -> SkbnV3State {
    var rng = SkbnLCG(seed: seed)
    let gridSize = 8

    // Build border walls
    var walls: Set<SkbnV3Pos> = []
    for c in 0..<gridSize {
        walls.insert(SkbnV3Pos(col: c, row: 0))
        walls.insert(SkbnV3Pos(col: c, row: gridSize - 1))
    }
    for r in 0..<gridSize {
        walls.insert(SkbnV3Pos(col: 0, row: r))
        walls.insert(SkbnV3Pos(col: gridSize - 1, row: r))
    }

    // Add 3-5 interior walls
    let interiorWallCount = 3 + rng.nextInt(3)
    for _ in 0..<interiorWallCount {
        let c = 1 + rng.nextInt(gridSize - 2)
        let r = 1 + rng.nextInt(gridSize - 2)
        walls.insert(SkbnV3Pos(col: c, row: r))
    }

    // Collect open floor cells
    var openCells: [SkbnV3Pos] = []
    for r in 1..<(gridSize - 1) {
        for c in 1..<(gridSize - 1) {
            let pos = SkbnV3Pos(col: c, row: r)
            if !walls.contains(pos) { openCells.append(pos) }
        }
    }

    // Shuffle open cells using LCG
    var cells = openCells
    for i in stride(from: cells.count - 1, through: 1, by: -1) {
        let j = rng.nextInt(i + 1)
        cells.swapAt(i, j)
    }

    // Assign player, 2 boxes, 2 targets from shuffled cells
    let numBoxes = 2
    let player = cells[0]
    var boxes: Set<SkbnV3Pos> = []
    var targets: Set<SkbnV3Pos> = []

    for i in 0..<numBoxes {
        boxes.insert(cells[1 + i])
    }
    for i in 0..<numBoxes {
        targets.insert(cells[1 + numBoxes + i])
    }

    return SkbnV3State(
        playerPos: player,
        boxes: boxes,
        targets: targets,
        walls: walls,
        moves: 0,
        history: []
    )
}

// MARK: - View (V3)

struct SokobanViewV3: View {
    @State private var phase: SkbnV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var game: SkbnV3State = skbnV3GenerateLevel(seed: 1)
    @State private var totalMoves: Int = 0
    @State private var bestMoves: [Int: Int] = [:]

    let cellSize: CGFloat = 38

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(Color(.label))
            VStack(spacing: 8) {
                Text("Push all boxes onto targets")
                    .font(.system(size: 15))
                    .foregroundColor(Color(.secondaryLabel))
                Text("Swipe to move • Each game is unique")
                    .font(.system(size: 13))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            Button(action: startGame) {
                Text("START")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 48).padding(.vertical, 14)
            }
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(24)
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MOVES")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("\(game.moves)")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(.label))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                    if let best = bestMoves[seedInt] {
                        Text("BEST: \(best)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                }
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .neumorphicCard(radius: 12)
            .padding(.horizontal, 16)

            gridView
                .padding(12)
                .neumorphicCard(radius: 16)
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
                neumorphicActionButton("UNDO") { undoMove() }
                neumorphicActionButton("RESET") { resetLevel() }
                neumorphicActionButton("NEW") { newGame() }
            }
            .padding(.horizontal, 16)
        }
    }

    var gridView: some View {
        VStack(spacing: 2) {
            ForEach(0..<8, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<8, id: \.self) { col in
                        cellView(pos: SkbnV3Pos(col: col, row: row))
                    }
                }
            }
        }
    }

    func cellView(pos: SkbnV3Pos) -> some View {
        let isWall = game.walls.contains(pos)
        let isPlayer = game.playerPos == pos
        let isBox = game.boxes.contains(pos)
        let isTarget = game.targets.contains(pos)
        let boxOnTarget = isBox && isTarget

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isWall
                      ? Color(.systemGray3)
                      : Color(.systemGray6))
                .frame(width: cellSize, height: cellSize)
                .shadow(color: isWall ? .clear : Color.white.opacity(0.8), radius: 2, x: -1, y: -1)
                .shadow(color: isWall ? .clear : Color.black.opacity(0.15), radius: 2, x: 1, y: 1)

            if isTarget && !isBox {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.green.opacity(0.8), lineWidth: 2)
                    .frame(width: cellSize - 10, height: cellSize - 10)
            }
            if isBox {
                RoundedRectangle(cornerRadius: 5)
                    .fill(boxOnTarget ? Color.green.opacity(0.75) : Color.orange.opacity(0.75))
                    .frame(width: cellSize - 6, height: cellSize - 6)
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
                    .shadow(color: Color.white.opacity(0.6), radius: 1, x: -1, y: -1)
            }
            if isPlayer {
                Circle()
                    .fill(Color(red: 0.3, green: 0.5, blue: 0.9))
                    .frame(width: cellSize - 10, height: cellSize - 10)
                    .shadow(color: Color.blue.opacity(0.4), radius: 3, x: 1, y: 1)
            }
        }
    }

    func neumorphicActionButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(.label))
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .neumorphicCard(radius: 10)
    }

    var completeScreen: some View {
        VStack(spacing: 22) {
            let isRecord = bestMoves[seedInt] == totalMoves
            Text("SOLVED!")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(Color(.label))
            VStack(spacing: 6) {
                Text("\(totalMoves) moves")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(.secondaryLabel))
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                if isRecord {
                    Text("NEW BEST!")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.green)
                }
            }

            VStack(spacing: 12) {
                Button(action: newGame) {
                    Text("NEXT PUZZLE")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 36).padding(.vertical, 12)
                }
                .neumorphicCard(radius: 12)

                Button(action: { phase = .start }) {
                    Text("MENU")
                        .font(.system(size: 13))
                        .foregroundColor(Color(.tertiaryLabel))
                }
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(24)
    }

    func startGame() {
        seedInt = 1
        game = skbnV3GenerateLevel(seed: seedInt)
        totalMoves = 0
        phase = .playing
    }

    func newGame() {
        seedInt += 1
        game = skbnV3GenerateLevel(seed: seedInt)
        phase = .playing
    }

    func resetLevel() {
        game = skbnV3GenerateLevel(seed: seedInt)
    }

    func move(_ dir: SkbnV3Dir) {
        let delta: SkbnV3Pos
        switch dir {
        case .up:    delta = SkbnV3Pos(col: 0, row: -1)
        case .down:  delta = SkbnV3Pos(col: 0, row: 1)
        case .left:  delta = SkbnV3Pos(col: -1, row: 0)
        case .right: delta = SkbnV3Pos(col: 1, row: 0)
        }
        let newPlayer = SkbnV3Pos(col: game.playerPos.col + delta.col, row: game.playerPos.row + delta.row)
        guard !game.walls.contains(newPlayer) else { return }

        if game.boxes.contains(newPlayer) {
            let newBox = SkbnV3Pos(col: newPlayer.col + delta.col, row: newPlayer.row + delta.row)
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
            if let existing = bestMoves[seedInt] {
                if totalMoves < existing { bestMoves[seedInt] = totalMoves }
            } else {
                bestMoves[seedInt] = totalMoves
            }
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

#Preview { SokobanViewV3() }

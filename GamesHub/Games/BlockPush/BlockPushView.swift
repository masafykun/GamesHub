import SwiftUI

// MARK: - Models

enum BkPsPhase { case start, playing, won }

enum BkPsColor: String, CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return .red
        case .blue: return .blue
        case .green: return .green
        }
    }
}

struct BkPsBlock: Identifiable {
    let id: UUID
    var col: Int
    var row: Int
    var color: BkPsColor
}

struct BkPsLevel {
    var blocks: [BkPsBlock]
}

// MARK: - Game Logic

struct BkPsEngine {
    static let gridSize = 6

    static func makeLevel(_ index: Int) -> BkPsLevel {
        let configs: [[(Int, Int, BkPsColor)]] = [
            [(0,0,.red),(5,0,.red),(0,5,.blue),(5,5,.blue),(2,2,.green),(3,3,.green)],
            [(0,0,.red),(0,1,.red),(5,0,.blue),(5,1,.blue),(3,0,.green),(3,5,.green)],
            [(1,1,.red),(4,4,.red),(1,4,.blue),(4,1,.blue),(0,3,.green),(5,2,.green)],
            [(0,2,.red),(5,2,.red),(2,0,.blue),(2,5,.blue),(0,0,.green),(5,5,.green)]
        ]
        let cfg = configs[index % configs.count]
        return BkPsLevel(blocks: cfg.map { BkPsBlock(id: UUID(), col: $0.0, row: $0.1, color: $0.2) })
    }

    static func slide(_ blocks: [BkPsBlock], dir: BkPsDir) -> [BkPsBlock] {
        var result = blocks
        // Sort order for processing
        let sorted: [BkPsBlock]
        switch dir {
        case .left:  sorted = result.sorted { $0.col < $1.col }
        case .right: sorted = result.sorted { $0.col > $1.col }
        case .up:    sorted = result.sorted { $0.row < $1.row }
        case .down:  sorted = result.sorted { $0.row > $1.row }
        }
        var moved: [BkPsBlock] = []
        for block in sorted {
            var b = block
            var pos = dir.start(b)
            while pos >= 0 && pos < gridSize {
                let next = dir.step(pos)
                if next < 0 || next >= gridSize { break }
                let occupied = moved.first { dir.pos($0) == next && dir.perp($0) == dir.perp(b) }
                if let occ = occupied {
                    if occ.color == b.color {
                        // Merge: remove other, stop here
                        moved.removeAll { $0.id == occ.id }
                        dir.setPos(&b, next)
                    }
                    break
                }
                pos = next
                dir.setPos(&b, pos)
            }
            moved.append(b)
        }
        return moved
    }

    static func isWon(_ blocks: [BkPsBlock]) -> Bool {
        for c in BkPsColor.allCases {
            if blocks.filter({ $0.color == c }).count > 1 { return false }
        }
        return true
    }
}

enum BkPsDir {
    case left, right, up, down
    func pos(_ b: BkPsBlock) -> Int { self == .left || self == .right ? b.col : b.row }
    func perp(_ b: BkPsBlock) -> Int { self == .left || self == .right ? b.row : b.col }
    func start(_ b: BkPsBlock) -> Int { pos(b) }
    func step(_ p: Int) -> Int {
        switch self {
        case .left, .up: return p - 1
        case .right, .down: return p + 1
        }
    }
    func setPos(_ b: inout BkPsBlock, _ v: Int) {
        if self == .left || self == .right { b.col = v } else { b.row = v }
    }
}

// MARK: - View

struct BlockPushView: View {
    @State private var phase: BkPsPhase = .start
    @State private var levelIndex = 0
    @State private var blocks: [BkPsBlock] = []
    @State private var moves = 0
    @State private var dragStart: CGPoint = .zero

    let cellSize: CGFloat = 48
    let levels = 4

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: wonScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("BlockPush").font(.largeTitle.bold())
            Text("Swipe to slide blocks.\nMerge all same-color blocks!").multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(levelIndex + 1)").font(.headline)
                Spacer()
                Text("Moves: \(moves)").font(.headline)
            }.padding(.horizontal)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: cellSize * 6 + 8, height: cellSize * 6 + 8)
                // Grid lines
                ForEach(0..<6) { r in
                    ForEach(0..<6) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray4))
                            .frame(width: cellSize - 4, height: cellSize - 4)
                            .offset(x: CGFloat(c) * cellSize - cellSize * 2.5,
                                    y: CGFloat(r) * cellSize - cellSize * 2.5)
                    }
                }
                // Blocks
                ForEach(blocks) { block in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(block.color.color)
                        .frame(width: cellSize - 6, height: cellSize - 6)
                        .offset(x: CGFloat(block.col) * cellSize - cellSize * 2.5,
                                y: CGFloat(block.row) * cellSize - cellSize * 2.5)
                        .animation(.easeInOut(duration: 0.2), value: block.col)
                        .animation(.easeInOut(duration: 0.2), value: block.row)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { val in
                        let dx = val.translation.width
                        let dy = val.translation.height
                        let dir: BkPsDir
                        if abs(dx) > abs(dy) { dir = dx > 0 ? .right : .left }
                        else { dir = dy > 0 ? .down : .up }
                        applySwipe(dir)
                    }
            )

            Text("Swipe to move all blocks").font(.caption).foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button("Restart Level") { startGame() }.buttonStyle(.bordered)
                if levelIndex < levels - 1 {
                    Button("Next Level") { nextLevel() }.buttonStyle(.bordered)
                }
            }
        }
    }

    var wonScreen: some View {
        VStack(spacing: 24) {
            Text("Merged!").font(.largeTitle.bold())
            Text("Level \(levelIndex + 1) complete in \(moves) moves!")
            if levelIndex < levels - 1 {
                Button("Next Level") { nextLevel() }.buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Text("All levels complete!").font(.headline).foregroundStyle(.green)
                Button("Play Again") { levelIndex = 0; startGame() }.buttonStyle(.borderedProminent)
            }
            Button("Main Menu") { phase = .start }.buttonStyle(.bordered)
        }.padding()
    }

    func startGame() {
        blocks = BkPsEngine.makeLevel(levelIndex).blocks
        moves = 0
        phase = .playing
    }

    func nextLevel() {
        levelIndex = min(levelIndex + 1, levels - 1)
        startGame()
    }

    func applySwipe(_ dir: BkPsDir) {
        let newBlocks = BkPsEngine.slide(blocks, dir: dir)
        if newBlocks.count != blocks.count || zip(newBlocks, blocks).contains(where: { $0.col != $1.col || $0.row != $1.row }) {
            moves += 1
        }
        blocks = newBlocks
        if BkPsEngine.isWon(blocks) { phase = .won }
    }
}

#Preview { BlockPushView() }

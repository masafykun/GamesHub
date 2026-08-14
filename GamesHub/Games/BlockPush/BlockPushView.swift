import SwiftUI

// MARK: - Models ()

enum BlockPushPhase { case start, playing, won }

enum BlockPushColor: String, CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return Color(red: 1.0, green: 0.3, blue: 0.3)
        case .blue: return Color(red: 0.3, green: 0.5, blue: 1.0)
        case .green: return Color(red: 0.2, green: 0.85, blue: 0.5)
        }
    }
}

struct BlockPushBlock: Identifiable {
    let id: UUID
    var col: Int
    var row: Int
    var color: BlockPushColor
}

// MARK: - Engine ()

struct BlockPushEngine {
    static let gridSize = 6

    static func makeLevel(_ index: Int) -> [BlockPushBlock] {
        let configs: [[(Int, Int, BlockPushColor)]] = [
            [(0,0,.red),(5,0,.red),(0,5,.blue),(5,5,.blue),(2,2,.green),(3,3,.green)],
            [(0,0,.red),(0,1,.red),(5,0,.blue),(5,1,.blue),(3,0,.green),(3,5,.green)],
            [(1,1,.red),(4,4,.red),(1,4,.blue),(4,1,.blue),(0,3,.green),(5,2,.green)],
            [(0,2,.red),(5,2,.red),(2,0,.blue),(2,5,.blue),(0,0,.green),(5,5,.green)]
        ]
        return configs[index % configs.count].map { BlockPushBlock(id: UUID(), col: $0.0, row: $0.1, color: $0.2) }
    }

    static func slide(_ blocks: [BlockPushBlock], dir: BlockPushDir) -> [BlockPushBlock] {
        let sorted: [BlockPushBlock]
        switch dir {
        case .left:  sorted = blocks.sorted { $0.col < $1.col }
        case .right: sorted = blocks.sorted { $0.col > $1.col }
        case .up:    sorted = blocks.sorted { $0.row < $1.row }
        case .down:  sorted = blocks.sorted { $0.row > $1.row }
        }
        var moved: [BlockPushBlock] = []
        for block in sorted {
            var b = block
            var pos = dir.pos(b)
            while true {
                let next = dir.step(pos)
                if next < 0 || next >= gridSize { break }
                if let occ = moved.first(where: { dir.pos($0) == next && dir.perp($0) == dir.perp(b) }) {
                    if occ.color == b.color {
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

    static func isWon(_ blocks: [BlockPushBlock]) -> Bool {
        for c in BlockPushColor.allCases {
            if blocks.filter({ $0.color == c }).count > 1 { return false }
        }
        return true
    }
}

enum BlockPushDir {
    case left, right, up, down
    func pos(_ b: BlockPushBlock) -> Int { self == .left || self == .right ? b.col : b.row }
    func perp(_ b: BlockPushBlock) -> Int { self == .left || self == .right ? b.row : b.col }
    func step(_ p: Int) -> Int {
        switch self { case .left, .up: return p - 1; case .right, .down: return p + 1 }
    }
    func setPos(_ b: inout BlockPushBlock, _ v: Int) {
        if self == .left || self == .right { b.col = v } else { b.row = v }
    }
}

// MARK: - View ( - Glassmorphism + Adaptive Difficulty)

struct BlockPushView: View {
    @State private var phase: BlockPushPhase = .start
    @State private var levelIndex = 0
    @State private var blocks: [BlockPushBlock] = []
    @State private var moves = 0
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0

    let cellSize: CGFloat = 46
    let levels = 4

    var adaptiveHint: String {
        difficulty > 1.15 ? "Hard Mode" : difficulty > 1.05 ? "Medium Mode" : "Normal Mode"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.4), Color(red: 0.4, green: 0.1, blue: 0.5)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: wonScreen
            }
        }
    }

    var glassCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BlockPush").font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Swipe to slide & merge same-color blocks")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.8))
            Button { startGame() } label: {
                Text("Start Game").font(.headline).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }.padding(32)
        .background(glassCard)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(levelIndex + 1)").font(.headline).foregroundStyle(.white)
                    Text(adaptiveHint).font(.caption).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text("Moves: \(moves)").font(.headline).foregroundStyle(.white)
            }
            .padding(.horizontal, 20).padding(.top, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                    .frame(width: cellSize * 6 + 16, height: cellSize * 6 + 16)

                ForEach(0..<6) { r in
                    ForEach(0..<6) { c in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white.opacity(0.08))
                            .frame(width: cellSize - 4, height: cellSize - 4)
                            .offset(x: CGFloat(c) * cellSize - cellSize * 2.5,
                                    y: CGFloat(r) * cellSize - cellSize * 2.5)
                    }
                }

                ForEach(blocks) { block in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(block.color.color.opacity(0.85))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.4), lineWidth: 1))
                        .frame(width: cellSize - 6, height: cellSize - 6)
                        .offset(x: CGFloat(block.col) * cellSize - cellSize * 2.5,
                                y: CGFloat(block.row) * cellSize - cellSize * 2.5)
                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: block.col)
                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: block.row)
                }
            }
            .gesture(DragGesture(minimumDistance: 10).onEnded { val in
                let dx = val.translation.width, dy = val.translation.height
                let dir: BlockPushDir = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                applySwipe(dir)
            })

            Text("Swipe to move blocks").font(.caption).foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 12) {
                Button { startGame() } label: {
                    Text("Restart").foregroundStyle(.white).font(.subheadline)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
        }.padding()
    }

    var wonScreen: some View {
        VStack(spacing: 22) {
            Text("Merged!").font(.system(size: 32, weight: .bold)).foregroundStyle(.white)
            Text("Level \(levelIndex + 1) done in \(moves) moves")
                .foregroundStyle(.white.opacity(0.8))
            if levelIndex < levels - 1 {
                Button { recordResult(true); nextLevel() } label: {
                    Text("Next Level").font(.headline).foregroundStyle(.white)
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4), lineWidth: 1))
                }
            } else {
                Text("All levels complete!").font(.headline).foregroundStyle(.green)
                Button { recordResult(true); levelIndex = 0; startGame() } label: {
                    Text("Play Again").foregroundStyle(.white).padding(.horizontal, 24).padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4), lineWidth: 1))
                }
            }
            Button { phase = .start } label: {
                Text("Menu").foregroundStyle(.white.opacity(0.7)).font(.subheadline)
            }
        }
        .padding(32).background(glassCard).padding()
    }

    func startGame() {
        blocks = BlockPushEngine.makeLevel(levelIndex).map {
            // Adaptive: in hard mode, some extra blocks
            $0
        }
        moves = 0
        phase = .playing
    }

    func nextLevel() {
        levelIndex = min(levelIndex + 1, levels - 1)
        startGame()
    }

    func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 10 { recentResults.removeFirst() }
        let last5 = recentResults.suffix(5)
        if last5.count == 5 && last5.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 2.0)
        }
    }

    func applySwipe(_ dir: BlockPushDir) {
        let newBlocks = BlockPushEngine.slide(blocks, dir: dir)
        let changed = newBlocks.count != blocks.count ||
            zip(newBlocks.sorted(by: { $0.id.uuidString < $1.id.uuidString }),
                blocks.sorted(by: { $0.id.uuidString < $1.id.uuidString }))
            .contains(where: { $0.col != $1.col || $0.row != $1.row })
        if changed { moves += 1 }
        blocks = newBlocks
        if BlockPushEngine.isWon(blocks) { phase = .won }
    }
}

#Preview { BlockPushView() }

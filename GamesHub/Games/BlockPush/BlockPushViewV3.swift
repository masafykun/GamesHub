import SwiftUI

// MARK: - LCG Seeded Random

struct BkPsLCG {
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

enum BkPsV3Phase { case start, playing, won }

enum BkPsV3Color: CaseIterable {
    case red, blue, green
    var color: Color {
        switch self {
        case .red: return Color(red: 0.85, green: 0.25, blue: 0.25)
        case .blue: return Color(red: 0.25, green: 0.45, blue: 0.85)
        case .green: return Color(red: 0.2, green: 0.72, blue: 0.4)
        }
    }
    var label: String {
        switch self { case .red: return "R"; case .blue: return "B"; case .green: return "G" }
    }
}

struct BkPsV3Block: Identifiable {
    let id: UUID
    var col: Int
    var row: Int
    var color: BkPsV3Color
}

// MARK: - Engine (V3)

struct BkPsV3Engine {
    static let gridSize = 6

    static func generateLevel(seed: Int) -> [BkPsV3Block] {
        var rng = BkPsLCG(seed: seed)
        var cells = Set<String>()
        var blocks: [BkPsV3Block] = []

        for color in BkPsV3Color.allCases {
            var placed = 0
            var attempts = 0
            while placed < 2 && attempts < 50 {
                attempts += 1
                let c = rng.nextInt(gridSize)
                let r = rng.nextInt(gridSize)
                let key = "\(c),\(r)"
                if !cells.contains(key) {
                    cells.insert(key)
                    blocks.append(BkPsV3Block(id: UUID(), col: c, row: r, color: color))
                    placed += 1
                }
            }
        }
        return blocks
    }

    static func slide(_ blocks: [BkPsV3Block], dir: BkPsV3Dir) -> [BkPsV3Block] {
        let sorted: [BkPsV3Block]
        switch dir {
        case .left:  sorted = blocks.sorted { $0.col < $1.col }
        case .right: sorted = blocks.sorted { $0.col > $1.col }
        case .up:    sorted = blocks.sorted { $0.row < $1.row }
        case .down:  sorted = blocks.sorted { $0.row > $1.row }
        }
        var moved: [BkPsV3Block] = []
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

    static func isWon(_ blocks: [BkPsV3Block]) -> Bool {
        for c in BkPsV3Color.allCases {
            if blocks.filter({ $0.color == c }).count > 1 { return false }
        }
        return true
    }
}

enum BkPsV3Dir {
    case left, right, up, down
    func pos(_ b: BkPsV3Block) -> Int { self == .left || self == .right ? b.col : b.row }
    func perp(_ b: BkPsV3Block) -> Int { self == .left || self == .right ? b.row : b.col }
    func step(_ p: Int) -> Int {
        switch self { case .left, .up: return p - 1; case .right, .down: return p + 1 }
    }
    func setPos(_ b: inout BkPsV3Block, _ v: Int) {
        if self == .left || self == .right { b.col = v } else { b.row = v }
    }
}

// MARK: - View (V3 - Neumorphism + Seeded Procedural)

struct BlockPushViewV3: View {
    @State private var phase: BkPsV3Phase = .start
    @State private var blocks: [BkPsV3Block] = []
    @State private var moves = 0
    @State private var seedInt: Int = 1

    let cellSize: CGFloat = 46

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .won: wonScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BlockPush").font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))
            Text("Swipe to slide blocks.\nMerge all same-color pairs!")
                .multilineTextAlignment(.center).foregroundStyle(Color(.secondaryLabel))
            Button { startGame() } label: {
                Text("Start Game").font(.headline).foregroundStyle(Color(.label))
                    .padding(.horizontal, 36).padding(.vertical, 14)
            }
            .neumorphicCard(radius: 12)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BlockPush").font(.headline).foregroundStyle(Color(.label))
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(.tertiaryLabel))
                }
                Spacer()
                Text("Moves: \(moves)").font(.headline).foregroundStyle(Color(.label))
            }
            .padding(.horizontal, 8)

            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray6))
                    .frame(width: cellSize * 6 + 16, height: cellSize * 6 + 16)
                    .shadow(color: .white.opacity(0.8), radius: 6, x: -4, y: -4)
                    .shadow(color: Color(.systemGray3).opacity(0.7), radius: 6, x: 4, y: 4)

                ForEach(0..<6) { r in
                    ForEach(0..<6) { c in
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(.systemGray5))
                            .frame(width: cellSize - 5, height: cellSize - 5)
                            .shadow(color: .white.opacity(0.7), radius: 2, x: -1, y: -1)
                            .shadow(color: Color(.systemGray3).opacity(0.5), radius: 2, x: 1, y: 1)
                            .offset(x: CGFloat(c) * cellSize - cellSize * 2.5,
                                    y: CGFloat(r) * cellSize - cellSize * 2.5)
                    }
                }

                ForEach(blocks) { block in
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(block.color.color)
                            .shadow(color: block.color.color.opacity(0.5), radius: 4, x: 2, y: 2)
                            .shadow(color: .white.opacity(0.6), radius: 3, x: -2, y: -2)
                        Text(block.color.label)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(width: cellSize - 8, height: cellSize - 8)
                    .offset(x: CGFloat(block.col) * cellSize - cellSize * 2.5,
                            y: CGFloat(block.row) * cellSize - cellSize * 2.5)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: block.col)
                    .animation(.spring(response: 0.22, dampingFraction: 0.7), value: block.row)
                }
            }
            .gesture(DragGesture(minimumDistance: 10).onEnded { val in
                let dx = val.translation.width, dy = val.translation.height
                let dir: BkPsV3Dir = abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                applySwipe(dir)
            })

            Text("Swipe to move all blocks").font(.caption).foregroundStyle(Color(.tertiaryLabel))

            HStack(spacing: 14) {
                Button { startGame() } label: {
                    Text("Restart").font(.subheadline).foregroundStyle(Color(.label))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
                .neumorphicCard(radius: 10)

                Button { newSeedGame() } label: {
                    Text("New Seed").font(.subheadline).foregroundStyle(Color(.label))
                        .padding(.horizontal, 20).padding(.vertical, 10)
                }
                .neumorphicCard(radius: 10)
            }
        }
        .padding()
    }

    var wonScreen: some View {
        VStack(spacing: 24) {
            Text("Merged!").font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color(.label))
            Text("Seed #\(seedInt) solved in \(moves) moves!")
                .foregroundStyle(Color(.secondaryLabel))
            Button { newSeedGame() } label: {
                Text("New Puzzle").font(.headline).foregroundStyle(Color(.label))
                    .padding(.horizontal, 32).padding(.vertical, 14)
            }
            .neumorphicCard(radius: 12)
            Button { phase = .start } label: {
                Text("Menu").font(.subheadline).foregroundStyle(Color(.tertiaryLabel))
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding()
    }

    func startGame() {
        blocks = BkPsV3Engine.generateLevel(seed: seedInt)
        moves = 0
        phase = .playing
    }

    func newSeedGame() {
        seedInt += 1
        startGame()
    }

    func applySwipe(_ dir: BkPsV3Dir) {
        let newBlocks = BkPsV3Engine.slide(blocks, dir: dir)
        let changed = newBlocks.count != blocks.count ||
            zip(newBlocks.sorted(by: { $0.id.uuidString < $1.id.uuidString }),
                blocks.sorted(by: { $0.id.uuidString < $1.id.uuidString }))
            .contains(where: { $0.col != $1.col || $0.row != $1.row })
        if changed { moves += 1 }
        blocks = newBlocks
        if BkPsV3Engine.isWon(blocks) { phase = .won }
    }
}

#Preview { BlockPushViewV3() }

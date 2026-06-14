import SwiftUI

// MARK: - LCG Seeded RNG

struct DngLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models V3

enum DngV3CellType {
    case empty, monster, treasure, exit, trap
}

struct DngV3Cell {
    var type: DngV3CellType
}

enum DngV3Phase {
    case start, playing, gameOver, win
}

// MARK: - DungeonViewV3

struct DungeonViewV3: View {
    let gridSize = 10
    let maxLevels = 3

    @State private var phase: DngV3Phase = .start
    @State private var grid: [[DngV3Cell]] = []
    @State private var heroPos: (row: Int, col: Int) = (9, 0)
    @State private var score: Int = 0
    @State private var hp: Int = 3
    @State private var level: Int = 1
    @State private var message: String = ""
    @State private var seedInt: Int = 1
    @State private var rng: DngLCG = DngLCG(seed: 1)

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: resultScreen(title: "GAME OVER", accent: .red)
            case .win: resultScreen(title: "YOU WIN!", accent: .orange)
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("DUNGEON")
                .font(.system(size: 52, weight: .black))
                .foregroundColor(.primary)

            VStack(spacing: 6) {
                Text("⚔️ Step on 👹 monsters: +10pts, -1 HP")
                Text("💰 Collect treasure: +5pts")
                Text("⚠️ Watch for hidden traps!")
                Text("🚪 Reach the exit to advance")
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)

            Button(action: startGame) {
                Text("ENTER DUNGEON")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(Color.orange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    func resultScreen(title: String, accent: Color) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 44, weight: .black))
                .foregroundColor(accent)
            Text("Score: \(score)")
                .font(.title.bold())
                .foregroundColor(.primary)
            Text("Level reached: \(level) of \(maxLevels)")
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt - 1)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            Button(action: {
                phase = .start
            }) {
                Text("PLAY AGAIN")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Text(hpString)
                    .font(.title2)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Score: \(score)")
                        .font(.headline.bold())
                        .foregroundColor(.orange)
                    Text("Level \(level)/\(maxLevels)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            HStack {
                if !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)

            gridView
                .padding(.horizontal)
                .gesture(DragGesture(minimumDistance: 20)
                    .onEnded { value in handleSwipe(translation: value.translation) })

            dpadView
                .padding(.bottom, 8)
        }
        .padding(.top)
    }

    var hpString: String {
        String(repeating: "❤️", count: hp) + String(repeating: "🖤", count: 3 - hp)
    }

    var gridView: some View {
        let available = min(UIScreen.main.bounds.width - 48, UIScreen.main.bounds.height * 0.52)
        let cellSize = (available - CGFloat(gridSize - 1) * 2) / CGFloat(gridSize)
        return VStack(spacing: 2) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        cellView(row: row, col: col, size: cellSize)
                    }
                }
            }
        }
        .padding(8)
        .neumorphicCard(radius: 16)
    }

    func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isHero = row == heroPos.row && col == heroPos.col
        let cell = grid[row][col]
        let bg: Color = isHero ? .orange.opacity(0.25) : Color(.systemGray5)
        let emoji: String = isHero ? "🧙" :
            cell.type == .monster ? "👹" :
            cell.type == .treasure ? "💰" :
            cell.type == .exit ? "🚪" :
            cell.type == .trap ? "⚠️" : ""

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(bg)
                .frame(width: size, height: size)
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.62))
            }
        }
    }

    var dpadView: some View {
        VStack(spacing: 4) {
            dpadButton("↑") { move(dr: -1, dc: 0) }
            HStack(spacing: 4) {
                dpadButton("←") { move(dr: 0, dc: -1) }
                Color.clear.frame(width: 52, height: 52)
                dpadButton("→") { move(dr: 0, dc: 1) }
            }
            dpadButton("↓") { move(dr: 1, dc: 0) }
        }
    }

    func dpadButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.bold())
                .foregroundColor(.primary)
                .frame(width: 52, height: 52)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .white, radius: 4, x: -2, y: -2)
                .shadow(color: Color(.systemGray3), radius: 4, x: 2, y: 2)
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0
        hp = 3
        level = 1
        message = ""
        seedInt += 1
        rng = DngLCG(seed: seedInt)
        buildLevel()
        phase = .playing
    }

    func buildLevel() {
        var newGrid = Array(repeating: Array(repeating: DngV3Cell(type: .empty), count: gridSize), count: gridSize)
        heroPos = (9, 0)

        var positions = allPositions().filter { !($0.0 == 9 && $0.1 == 0) }
        // Shuffle using LCG
        for i in stride(from: positions.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            positions.swapAt(i, j)
        }

        let monsterCount = 5 + level * 2
        let treasureCount = 3 + level
        let trapCount = level

        var idx = 0
        for _ in 0..<monsterCount where idx < positions.count {
            newGrid[positions[idx].0][positions[idx].1].type = .monster
            idx += 1
        }
        for _ in 0..<treasureCount where idx < positions.count {
            newGrid[positions[idx].0][positions[idx].1].type = .treasure
            idx += 1
        }
        for _ in 0..<trapCount where idx < positions.count {
            newGrid[positions[idx].0][positions[idx].1].type = .trap
            idx += 1
        }
        if idx < positions.count {
            newGrid[positions[idx].0][positions[idx].1].type = .exit
        } else {
            newGrid[0][9].type = .exit
        }
        grid = newGrid
    }

    func allPositions() -> [(Int, Int)] {
        var pos: [(Int, Int)] = []
        for r in 0..<gridSize { for c in 0..<gridSize { pos.append((r, c)) } }
        return pos
    }

    func handleSwipe(translation: CGSize) {
        let dx = translation.width, dy = translation.height
        if abs(dx) > abs(dy) { move(dr: 0, dc: dx > 0 ? 1 : -1) }
        else { move(dr: dy > 0 ? 1 : -1, dc: 0) }
    }

    func move(dr: Int, dc: Int) {
        let newRow = heroPos.row + dr
        let newCol = heroPos.col + dc
        guard newRow >= 0, newRow < gridSize, newCol >= 0, newCol < gridSize else { return }
        heroPos = (newRow, newCol)
        let cell = grid[newRow][newCol]
        switch cell.type {
        case .monster:
            score += 10; hp -= 1
            message = "Monster defeated! +10pts -1HP"
            grid[newRow][newCol].type = .empty
            if hp <= 0 { phase = .gameOver }
        case .treasure:
            score += 5
            message = "Treasure found! +5pts"
            grid[newRow][newCol].type = .empty
        case .trap:
            hp -= 1
            message = "Trap! -1 HP"
            grid[newRow][newCol].type = .empty
            if hp <= 0 { phase = .gameOver }
        case .exit:
            if level >= maxLevels { score += 20; phase = .win }
            else { score += 20; level += 1; message = "Level \(level)! Deeper you go..."; buildLevel() }
        case .empty:
            message = ""
        }
    }
}

#Preview { DungeonViewV3() }

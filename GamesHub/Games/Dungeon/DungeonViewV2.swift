import SwiftUI

// MARK: - Models V2

enum DngV2CellType {
    case empty, monster, treasure, exit
}

struct DngV2Cell {
    var type: DngV2CellType
}

enum DngV2Phase {
    case start, playing, gameOver, win
}

// MARK: - DungeonViewV2

struct DungeonViewV2: View {
    let gridSize = 10
    let maxLevels = 3

    @State private var phase: DngV2Phase = .start
    @State private var grid: [[DngV2Cell]] = []
    @State private var heroPos: (row: Int, col: Int) = (9, 0)
    @State private var score: Int = 0
    @State private var hp: Int = 3
    @State private var level: Int = 1
    @State private var message: String = ""

    // Adaptive difficulty
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    var adaptedMonsterCount: Int {
        Int(Double(5 + level * 2) * difficultyMultiplier)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.05, blue: 0.2), Color(red: 0.2, green: 0.05, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: resultScreen(title: "GAME OVER", accent: .red)
            case .win: resultScreen(title: "YOU WIN!", accent: .yellow)
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("DUNGEON")
                .font(.system(size: 52, weight: .black))
                .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))

            VStack(spacing: 8) {
                Text("⚔️ Defeat monsters for +10pts")
                Text("💰 Collect treasure for +5pts")
                Text("🚪 Find the exit to advance")
            }
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.8))

            glassButton("ENTER DUNGEON", accent: .orange) {
                startGame()
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    func resultScreen(title: String, accent: Color) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 44, weight: .black))
                .foregroundColor(accent)
            Text("Score: \(score)")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("Level: \(level) | Difficulty: \(String(format: "%.0f%%", difficultyMultiplier * 100))")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            glassButton("PLAY AGAIN", accent: accent) {
                phase = .start
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 10) {
            HStack {
                Text(hpString)
                    .font(.title2)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Score: \(score)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                    Text("Lv \(level)/\(maxLevels)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.cyan)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            gridView
                .padding(.horizontal)
                .gesture(DragGesture(minimumDistance: 20)
                    .onEnded { value in handleSwipe(translation: value.translation) })

            if difficultyMultiplier > 1.0 {
                Text("ADAPTIVE: \(String(format: "%.0f%%", difficultyMultiplier * 100)) difficulty")
                    .font(.caption2)
                    .foregroundColor(.orange.opacity(0.7))
            }

            Text("Swipe to move")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.top)
    }

    var hpString: String {
        String(repeating: "❤️", count: hp) + String(repeating: "🖤", count: 3 - hp)
    }

    var gridView: some View {
        let available = min(UIScreen.main.bounds.width - 48, UIScreen.main.bounds.height * 0.55)
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
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isHero = row == heroPos.row && col == heroPos.col
        let cell = grid[row][col]
        let bg: Color = isHero ? .orange.opacity(0.6) : Color.white.opacity(0.05)
        let emoji: String = isHero ? "🧙" :
            cell.type == .monster ? "👹" :
            cell.type == .treasure ? "💰" :
            cell.type == .exit ? "🚪" : ""

        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(bg)
                .frame(width: size, height: size)
            if !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: size * 0.65))
            }
        }
    }

    func glassButton(_ label: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline.bold())
                .foregroundColor(accent)
                .padding(.horizontal, 36)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(accent.opacity(0.5), lineWidth: 1))
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0
        hp = 3
        level = 1
        message = ""
        recentResults = []
        difficultyMultiplier = 1.0
        buildLevel()
        phase = .playing
    }

    func buildLevel() {
        var newGrid = Array(repeating: Array(repeating: DngV2Cell(type: .empty), count: gridSize), count: gridSize)
        heroPos = (9, 0)

        var positions = allPositions().filter { !($0.0 == 9 && $0.1 == 0) }
        positions.shuffle()

        let monsterCount = adaptedMonsterCount
        let treasureCount = 3 + level

        for i in 0..<monsterCount where i < positions.count {
            newGrid[positions[i].0][positions[i].1].type = .monster
        }
        for i in monsterCount..<(monsterCount + treasureCount) where i < positions.count {
            newGrid[positions[i].0][positions[i].1].type = .treasure
        }
        let exitIdx = monsterCount + treasureCount
        if exitIdx < positions.count {
            newGrid[positions[exitIdx].0][positions[exitIdx].1].type = .exit
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

    func recordResult(success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.5)
        }
    }

    func handleSwipe(translation: CGSize) {
        let dx = translation.width, dy = translation.height
        var dr = 0, dc = 0
        if abs(dx) > abs(dy) { dc = dx > 0 ? 1 : -1 } else { dr = dy > 0 ? 1 : -1 }
        let newRow = heroPos.row + dr
        let newCol = heroPos.col + dc
        guard newRow >= 0, newRow < gridSize, newCol >= 0, newCol < gridSize else { return }
        heroPos = (newRow, newCol)
        let cell = grid[newRow][newCol]
        switch cell.type {
        case .monster:
            score += 10; hp -= 1
            message = "Monster! -1 HP +10pts"
            grid[newRow][newCol].type = .empty
            recordResult(success: false)
            if hp <= 0 { phase = .gameOver }
        case .treasure:
            score += 5
            message = "Treasure! +5pts"
            grid[newRow][newCol].type = .empty
            recordResult(success: true)
        case .exit:
            recordResult(success: true)
            if level >= maxLevels { score += 20; phase = .win }
            else { score += 20; level += 1; message = "Level \(level)!"; buildLevel() }
        case .empty:
            message = ""
        }
    }
}

#Preview { DungeonViewV2() }

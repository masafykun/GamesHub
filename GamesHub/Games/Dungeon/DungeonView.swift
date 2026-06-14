import SwiftUI

// MARK: - Models

enum DngCellType {
    case empty, monster, treasure, exit
}

struct DngCell {
    var type: DngCellType
}

enum DngGamePhase {
    case start, playing, gameOver, win
}

// MARK: - Main View

struct DungeonView: View {
    let gridSize = 10
    let maxLevels = 3

    @State private var phase: DngGamePhase = .start
    @State private var grid: [[DngCell]] = []
    @State private var heroPos: (row: Int, col: Int) = (9, 0)
    @State private var score: Int = 0
    @State private var hp: Int = 3
    @State private var level: Int = 1
    @State private var message: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                resultScreen(title: "GAME OVER", color: .red)
            case .win:
                resultScreen(title: "YOU WIN!", color: .yellow)
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("DUNGEON")
                .font(.system(size: 48, weight: .black))
                .foregroundColor(.orange)
            Text("⚔️ Defeat monsters, collect treasure\nfind the 🚪 exit on each level")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Text("❤️❤️❤️  3 HP  |  3 Levels")
                .foregroundColor(.white)
            Button("START") {
                startGame()
            }
            .font(.title2.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.orange)
            .cornerRadius(12)
        }
        .padding()
    }

    func resultScreen(title: String, color: Color) -> some View {
        VStack(spacing: 20) {
            Text(title)
                .font(.system(size: 44, weight: .black))
                .foregroundColor(color)
            Text("Score: \(score)")
                .font(.title.bold())
                .foregroundColor(.white)
            Text("Level reached: \(level)")
                .foregroundColor(.gray)
            Button("PLAY AGAIN") {
                phase = .start
            }
            .font(.title2.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(12)
        }
    }

    var gameScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Text(hpString)
                    .font(.title2)
                Spacer()
                Text("Score: \(score)")
                    .font(.headline)
                    .foregroundColor(.yellow)
                Spacer()
                Text("Level \(level)/\(maxLevels)")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal)
            .foregroundColor(.white)

            if !message.isEmpty {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.cyan)
            }

            gridView
                .gesture(DragGesture(minimumDistance: 20)
                    .onEnded { value in
                        handleSwipe(translation: value.translation)
                    })

            swipeHint
        }
        .padding(.top)
    }

    var hpString: String {
        String(repeating: "❤️", count: hp) + String(repeating: "🖤", count: 3 - hp)
    }

    var gridView: some View {
        let cellSize: CGFloat = min(UIScreen.main.bounds.width - 32, UIScreen.main.bounds.height * 0.55) / CGFloat(gridSize)
        return VStack(spacing: 2) {
            ForEach(0..<gridSize, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<gridSize, id: \.self) { col in
                        cellView(row: row, col: col, size: cellSize)
                    }
                }
            }
        }
        .padding(4)
        .background(Color(white: 0.1))
        .cornerRadius(8)
    }

    func cellView(row: Int, col: Int, size: CGFloat) -> some View {
        let isHero = row == heroPos.row && col == heroPos.col
        let cell = grid[row][col]

        let bg: Color = isHero ? .orange.opacity(0.8) :
            (cell.type == .empty ? Color(white: 0.18) : Color(white: 0.15))
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

    var swipeHint: some View {
        Text("Swipe to move")
            .font(.caption)
            .foregroundColor(Color(white: 0.4))
            .padding(.bottom, 8)
    }

    // MARK: - Logic

    func startGame() {
        score = 0
        hp = 3
        level = 1
        message = ""
        buildLevel()
        phase = .playing
    }

    func buildLevel() {
        var newGrid = Array(repeating: Array(repeating: DngCell(type: .empty), count: gridSize), count: gridSize)
        heroPos = (9, 0)

        var positions = allPositions().filter { !($0 == (9, 0)) }
        positions.shuffle()

        let monsterCount = 5 + level * 2
        let treasureCount = 3 + level

        for i in 0..<monsterCount {
            if i < positions.count { newGrid[positions[i].0][positions[i].1].type = .monster }
        }
        for i in monsterCount..<(monsterCount + treasureCount) {
            if i < positions.count { newGrid[positions[i].0][positions[i].1].type = .treasure }
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

    func handleSwipe(translation: CGSize) {
        let dx = translation.width
        let dy = translation.height
        var dr = 0, dc = 0
        if abs(dx) > abs(dy) { dc = dx > 0 ? 1 : -1 } else { dr = dy > 0 ? 1 : -1 }
        let newRow = heroPos.row + dr
        let newCol = heroPos.col + dc
        guard newRow >= 0, newRow < gridSize, newCol >= 0, newCol < gridSize else { return }
        heroPos = (newRow, newCol)
        let cell = grid[newRow][newCol]
        switch cell.type {
        case .monster:
            score += 10
            hp -= 1
            message = "Hit monster! -1 HP +10pts"
            grid[newRow][newCol].type = .empty
            if hp <= 0 { phase = .gameOver }
        case .treasure:
            score += 5
            message = "Treasure! +5pts"
            grid[newRow][newCol].type = .empty
        case .exit:
            if level >= maxLevels {
                score += 20
                phase = .win
            } else {
                score += 20
                level += 1
                message = "Level \(level)!"
                buildLevel()
            }
        case .empty:
            message = ""
        }
    }
}

#Preview { DungeonView() }

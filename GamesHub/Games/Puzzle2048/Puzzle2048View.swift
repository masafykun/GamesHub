import SwiftUI

// MARK: - Tile Color Helper
struct Puzzle2048TileStyle {
    static func background(for value: Int) -> Color {
        switch value {
        case 0:    return Color(.systemGray4)
        case 2:    return Color(red: 0.93, green: 0.89, blue: 0.85)
        case 4:    return Color(red: 0.93, green: 0.87, blue: 0.78)
        case 8:    return Color.orange
        case 16:   return Color(red: 0.96, green: 0.55, blue: 0.24)
        case 32:   return Color.red
        case 64:   return Color(red: 0.78, green: 0.08, blue: 0.08)
        case 128:  return Color.yellow
        case 256:  return Color(red: 1.0,  green: 0.84, blue: 0.0)
        case 512:  return Color(red: 1.0,  green: 0.60, blue: 0.0)
        case 1024: return Color.purple
        case 2048: return Color.blue
        default:   return Color.black
        }
    }

    static func foreground(for value: Int) -> Color {
        switch value {
        case 0, 2, 4: return Color(red: 0.47, green: 0.43, blue: 0.40)
        default:       return .white
        }
    }
}

// MARK: - Board Logic
struct Puzzle2048Board {
    var grid: [[Int]]
    var score: Int = 0

    init() {
        grid = Array(repeating: Array(repeating: 0, count: 4), count: 4)
        addRandomTile()
        addRandomTile()
    }

    // Slide and merge a single row to the left
    mutating func slideLeft(_ row: [Int]) -> (result: [Int], gained: Int) {
        var tiles = row.filter { $0 != 0 }
        var gained = 0
        var i = 0
        while i < tiles.count - 1 {
            if tiles[i] == tiles[i + 1] {
                tiles[i] *= 2
                gained += tiles[i]
                tiles.remove(at: i + 1)
            }
            i += 1
        }
        while tiles.count < 4 { tiles.append(0) }
        return (tiles, gained)
    }

    mutating func moveLeft() -> Bool {
        var changed = false
        for r in 0..<4 {
            let (newRow, gained) = slideLeft(grid[r])
            if newRow != grid[r] { changed = true }
            grid[r] = newRow
            score += gained
        }
        return changed
    }

    mutating func moveRight() -> Bool {
        var changed = false
        for r in 0..<4 {
            let reversed = Array(grid[r].reversed())
            let (newRow, gained) = slideLeft(reversed)
            let final = Array(newRow.reversed())
            if final != grid[r] { changed = true }
            grid[r] = final
            score += gained
        }
        return changed
    }

    mutating func moveUp() -> Bool {
        var changed = false
        for c in 0..<4 {
            let col = (0..<4).map { grid[$0][c] }
            let (newCol, gained) = slideLeft(col)
            for r in 0..<4 {
                if grid[r][c] != newCol[r] { changed = true }
                grid[r][c] = newCol[r]
            }
            score += gained
        }
        return changed
    }

    mutating func moveDown() -> Bool {
        var changed = false
        for c in 0..<4 {
            let col = (0..<4).map { grid[$0][c] }
            let reversed = Array(col.reversed())
            let (newCol, gained) = slideLeft(reversed)
            let final = Array(newCol.reversed())
            for r in 0..<4 {
                if grid[r][c] != final[r] { changed = true }
                grid[r][c] = final[r]
            }
            score += gained
        }
        return changed
    }

    mutating func addRandomTile() {
        var empties: [(Int, Int)] = []
        for r in 0..<4 {
            for c in 0..<4 {
                if grid[r][c] == 0 { empties.append((r, c)) }
            }
        }
        guard let (r, c) = empties.randomElement() else { return }
        grid[r][c] = Int.random(in: 1...10) == 1 ? 4 : 2
    }

    var hasWon: Bool {
        grid.flatMap { $0 }.contains(2048)
    }

    var isGameOver: Bool {
        // Any empty cell?
        for r in 0..<4 {
            for c in 0..<4 {
                if grid[r][c] == 0 { return false }
            }
        }
        // Any horizontal merge?
        for r in 0..<4 {
            for c in 0..<3 {
                if grid[r][c] == grid[r][c + 1] { return false }
            }
        }
        // Any vertical merge?
        for r in 0..<3 {
            for c in 0..<4 {
                if grid[r][c] == grid[r + 1][c] { return false }
            }
        }
        return true
    }
}

// MARK: - Tile View
struct Puzzle2048TileView: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Puzzle2048TileStyle.background(for: value))
            if value != 0 {
                Text(value >= 1000 ? "\(value)" : "\(value)")
                    .font(.system(size: value >= 1000 ? size * 0.28 : size * 0.34, weight: .bold, design: .rounded))
                    .foregroundColor(Puzzle2048TileStyle.foreground(for: value))
                    .minimumScaleFactor(0.5)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main View
struct Puzzle2048View: View {
    @State private var board = Puzzle2048Board()
    @State private var showWin = false
    @State private var keptPlaying = false
    @AppStorage("p2048Best") private var bestScore: Int = 0

    private let spacing: CGFloat = 10
    private let padding: CGFloat = 12

    private var tileSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let available = screen - padding * 2 - spacing * 3
        return available / 4
    }

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.94, blue: 0.90)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("2048")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundColor(Color(red: 0.47, green: 0.43, blue: 0.40))
                        Text("Swipe to combine tiles!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            scoreBox(label: "SCORE", value: board.score)
                            scoreBox(label: "BEST", value: bestScore)
                        }
                        Button(action: restart) {
                            Text("New Game")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.55, green: 0.50, blue: 0.46))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, padding)

                // Grid
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.73, green: 0.68, blue: 0.63))
                        .padding(.horizontal, padding)

                    VStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<4, id: \.self) { col in
                                    Puzzle2048TileView(value: board.grid[row][col], size: tileSize)
                                }
                            }
                        }
                    }
                    .padding(padding)
                }
                .aspectRatio(1, contentMode: .fit)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            handleSwipe(translation: value.translation)
                        }
                )

                Spacer()
            }
            .padding(.top, 16)

            // Win Overlay
            if showWin && !keptPlaying {
                winOverlay
            }

            // Game Over Overlay
            if board.isGameOver && !showWin {
                gameOverOverlay
            }
        }
    }

    // MARK: - Overlay Views
    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("You Win!")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(.yellow)
                Text("You reached 2048!")
                    .font(.title3)
                    .foregroundColor(.white)
                HStack(spacing: 16) {
                    Button("Keep Playing") {
                        keptPlaying = true
                    }
                    .buttonStyle(Puzzle2048ButtonStyle(color: Color(red: 0.55, green: 0.50, blue: 0.46)))

                    Button("Restart") {
                        restart()
                    }
                    .buttonStyle(Puzzle2048ButtonStyle(color: .orange))
                }
            }
            .padding(40)
            .background(Color(red: 0.24, green: 0.22, blue: 0.20).opacity(0.95))
            .cornerRadius(20)
            .padding(.horizontal, 30)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Game Over!")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.red)
                Text("Score: \(board.score)")
                    .font(.title2)
                    .foregroundColor(.white)
                Button("Try Again") {
                    restart()
                }
                .buttonStyle(Puzzle2048ButtonStyle(color: .orange))
            }
            .padding(40)
            .background(Color(red: 0.24, green: 0.22, blue: 0.20).opacity(0.95))
            .cornerRadius(20)
            .padding(.horizontal, 30)
        }
    }

    // MARK: - Helper Views
    private func scoreBox(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(red: 0.87, green: 0.83, blue: 0.80))
            Text("\(value)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
        }
        .frame(minWidth: 64)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(red: 0.47, green: 0.43, blue: 0.40))
        .cornerRadius(8)
    }

    // MARK: - Game Logic
    private func handleSwipe(translation: CGSize) {
        let dx = translation.width
        let dy = translation.height
        let absDx = abs(dx)
        let absDy = abs(dy)

        let moved: Bool
        if absDx > absDy {
            moved = dx > 0 ? board.moveRight() : board.moveLeft()
        } else {
            moved = dy > 0 ? board.moveDown() : board.moveUp()
        }

        if moved {
            board.addRandomTile()
            if board.score > bestScore { bestScore = board.score }
            if board.hasWon && !keptPlaying { showWin = true }
        }
    }

    private func restart() {
        board = Puzzle2048Board()
        showWin = false
        keptPlaying = false
    }
}

// MARK: - Button Style
struct Puzzle2048ButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.7 : 1.0))
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
    }
}

#Preview {
    Puzzle2048View()
}

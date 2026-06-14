import SwiftUI

// MARK: - V2 Difficulty
enum Puzzle2048V2Difficulty {
    case easy, medium, hard

    var gridSize: Int {
        switch self {
        case .easy:   return 3
        case .medium: return 4
        case .hard:   return 5
        }
    }

    var label: String {
        switch self {
        case .easy:   return "3×3 Easy"
        case .medium: return "4×4 Medium"
        case .hard:   return "5×5 Hard"
        }
    }

    var badgeColor: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }

    var winTarget: Int {
        switch self {
        case .easy:   return 256
        case .medium: return 2048
        case .hard:   return 2048
        }
    }
}

// MARK: - V2 Tile Style (Neon)
struct Puzzle2048V2TileStyle {
    static func neonColor(for value: Int) -> Color {
        switch value {
        case 0:    return Color.white.opacity(0.0)
        case 2:    return Color(red: 0.40, green: 0.90, blue: 1.00)
        case 4:    return Color(red: 0.30, green: 0.70, blue: 1.00)
        case 8:    return Color(red: 0.20, green: 0.90, blue: 0.60)
        case 16:   return Color(red: 0.50, green: 1.00, blue: 0.30)
        case 32:   return Color(red: 1.00, green: 0.90, blue: 0.10)
        case 64:   return Color(red: 1.00, green: 0.60, blue: 0.10)
        case 128:  return Color(red: 1.00, green: 0.30, blue: 0.30)
        case 256:  return Color(red: 1.00, green: 0.10, blue: 0.60)
        case 512:  return Color(red: 0.80, green: 0.10, blue: 1.00)
        case 1024: return Color(red: 0.50, green: 0.20, blue: 1.00)
        case 2048: return Color(red: 0.10, green: 0.30, blue: 1.00)
        default:   return Color.white
        }
    }

    static func fontSizeMultiplier(for value: Int) -> CGFloat {
        value >= 1000 ? 0.26 : 0.34
    }
}

// MARK: - V2 Board Logic
struct Puzzle2048V2Board {
    var grid: [[Int]]
    var score: Int = 0
    let size: Int

    init(size: Int) {
        self.size = size
        grid = Array(repeating: Array(repeating: 0, count: size), count: size)
        addRandomTile()
        addRandomTile()
    }

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
        while tiles.count < size { tiles.append(0) }
        return (tiles, gained)
    }

    mutating func moveLeft() -> Bool {
        var changed = false
        for r in 0..<size {
            let (newRow, gained) = slideLeft(grid[r])
            if newRow != grid[r] { changed = true }
            grid[r] = newRow
            score += gained
        }
        return changed
    }

    mutating func moveRight() -> Bool {
        var changed = false
        for r in 0..<size {
            let (newRow, gained) = slideLeft(Array(grid[r].reversed()))
            let final = Array(newRow.reversed())
            if final != grid[r] { changed = true }
            grid[r] = final
            score += gained
        }
        return changed
    }

    mutating func moveUp() -> Bool {
        var changed = false
        for c in 0..<size {
            let col = (0..<size).map { grid[$0][c] }
            let (newCol, gained) = slideLeft(col)
            for r in 0..<size {
                if grid[r][c] != newCol[r] { changed = true }
                grid[r][c] = newCol[r]
            }
            score += gained
        }
        return changed
    }

    mutating func moveDown() -> Bool {
        var changed = false
        for c in 0..<size {
            let col = (0..<size).map { grid[$0][c] }
            let (newCol, gained) = slideLeft(Array(col.reversed()))
            let final = Array(newCol.reversed())
            for r in 0..<size {
                if grid[r][c] != final[r] { changed = true }
                grid[r][c] = final[r]
            }
            score += gained
        }
        return changed
    }

    mutating func addRandomTile() {
        var empties: [(Int, Int)] = []
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == 0 { empties.append((r, c)) }
            }
        }
        guard let (r, c) = empties.randomElement() else { return }
        grid[r][c] = Int.random(in: 1...10) == 1 ? 4 : 2
    }

    var maxTile: Int { grid.flatMap { $0 }.max() ?? 0 }

    var isGameOver: Bool {
        for r in 0..<size {
            for c in 0..<size {
                if grid[r][c] == 0 { return false }
            }
        }
        for r in 0..<size {
            for c in 0..<(size - 1) {
                if grid[r][c] == grid[r][c + 1] { return false }
            }
        }
        for r in 0..<(size - 1) {
            for c in 0..<size {
                if grid[r][c] == grid[r + 1][c] { return false }
            }
        }
        return true
    }
}

// MARK: - V2 Merge Scale Key
struct Puzzle2048V2MergeKey: Hashable {
    let row: Int
    let col: Int
}

// MARK: - V2 Tile View (Glassmorphism)
struct Puzzle2048V2TileView: View {
    let value: Int
    let size: CGFloat
    let didMerge: Bool

    @State private var scale: CGFloat = 1.0

    var neonColor: Color { Puzzle2048V2TileStyle.neonColor(for: value) }

    var body: some View {
        ZStack {
            if value != 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(neonColor.opacity(0.8), lineWidth: 2)
                    )
                    .shadow(color: neonColor.opacity(0.6), radius: 8, x: 0, y: 0)

                Text("\(value)")
                    .font(.system(
                        size: size * Puzzle2048V2TileStyle.fontSizeMultiplier(for: value),
                        weight: .black,
                        design: .rounded
                    ))
                    .foregroundColor(neonColor)
                    .shadow(color: neonColor.opacity(0.8), radius: 4)
                    .minimumScaleFactor(0.4)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .onChange(of: didMerge) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    scale = 1.25
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6).delay(0.15)) {
                    scale = 1.0
                }
            }
        }
    }
}

// MARK: - Main V2 View
struct Puzzle2048ViewV2: View {
    @State private var board: Puzzle2048V2Board
    @State private var difficulty: Puzzle2048V2Difficulty = .easy
    @State private var roundScores: [Int] = []
    @State private var showWin = false
    @State private var keptPlaying = false
    @State private var mergeSet: Set<Puzzle2048V2MergeKey> = []
    @AppStorage("p2048V2Best") private var bestScore: Int = 0

    init() {
        _board = State(initialValue: Puzzle2048V2Board(size: 3))
    }

    private var spacing: CGFloat { 8 }
    private var gridPadding: CGFloat { 10 }

    private var tileSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let n = CGFloat(board.size)
        let available = screen - gridPadding * 2 - spacing * (n - 1) - 32
        return available / n
    }

    private var movingAvg: Double {
        guard !roundScores.isEmpty else { return 0 }
        let last = roundScores.suffix(5)
        return Double(last.reduce(0, +)) / Double(last.count)
    }

    private func nextDifficulty() -> Puzzle2048V2Difficulty {
        if movingAvg >= 800 { return .hard }
        if movingAvg >= 200 { return .medium }
        return .easy
    }

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.20),
                    Color(red: 0.10, green: 0.02, blue: 0.25),
                    Color(red: 0.02, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                // Frosted glass score panel
                frostedScorePanel

                // Difficulty badge
                HStack {
                    difficultyBadge
                    Spacer()
                    if !roundScores.isEmpty {
                        Text("Avg: \(Int(movingAvg)) pts")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)

                // Grid
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)

                    VStack(spacing: spacing) {
                        ForEach(0..<board.size, id: \.self) { row in
                            HStack(spacing: spacing) {
                                ForEach(0..<board.size, id: \.self) { col in
                                    Puzzle2048V2TileView(
                                        value: board.grid[row][col],
                                        size: tileSize,
                                        didMerge: mergeSet.contains(Puzzle2048V2MergeKey(row: row, col: col))
                                    )
                                }
                            }
                        }
                    }
                    .padding(gridPadding)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(.horizontal, 16)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            handleSwipe(translation: value.translation)
                        }
                )

                Spacer()
            }
            .padding(.top, 12)

            // Win overlay
            if showWin && !keptPlaying {
                v2WinOverlay
            }

            // Game over overlay
            if board.isGameOver && !showWin {
                v2GameOverOverlay
            }
        }
    }

    // MARK: - Subviews
    private var frostedScorePanel: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("2048")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Glass Edition")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            HStack(spacing: 10) {
                v2ScoreBox(label: "SCORE", value: board.score, accentColor: .cyan)
                v2ScoreBox(label: "BEST", value: bestScore, accentColor: .purple)
            }
            Button(action: restart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.1)),
            alignment: .bottom
        )
    }

    private func v2ScoreBox(label: String, value: Int, accentColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(accentColor.opacity(0.8))
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
        }
        .frame(minWidth: 58)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.thinMaterial)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(accentColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var difficultyBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(difficulty.badgeColor)
                .frame(width: 8, height: 8)
                .shadow(color: difficulty.badgeColor, radius: 4)
            Text(difficulty.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(difficulty.badgeColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(difficulty.badgeColor.opacity(0.5), lineWidth: 1)
        )
    }

    private var v2WinOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("You Win!")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                Text("Reached \(difficulty.winTarget)!")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 14) {
                    Button("Keep Playing") { keptPlaying = true }
                        .buttonStyle(Puzzle2048V2GlassButtonStyle(accent: .cyan))
                    Button("New Game") { restart() }
                        .buttonStyle(Puzzle2048V2GlassButtonStyle(accent: .orange))
                }
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 30)
        }
    }

    private var v2GameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Game Over")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing))
                Text("Score: \(board.score)")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                let next = nextDifficulty()
                if next != difficulty {
                    Text("Next: \(next.label)")
                        .font(.callout)
                        .foregroundColor(next.badgeColor)
                }
                Button("Play Again") { restart() }
                    .buttonStyle(Puzzle2048V2GlassButtonStyle(accent: .purple))
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 30)
        }
    }

    // MARK: - Game Logic
    private func handleSwipe(translation: CGSize) {
        mergeSet = []
        let dx = translation.width, dy = translation.height
        let moved: Bool
        if abs(dx) > abs(dy) {
            moved = dx > 0 ? board.moveRight() : board.moveLeft()
        } else {
            moved = dy > 0 ? board.moveDown() : board.moveUp()
        }
        if moved {
            board.addRandomTile()
            if board.score > bestScore { bestScore = board.score }
            if board.maxTile >= difficulty.winTarget && !keptPlaying { showWin = true }
        }
    }

    private func restart() {
        roundScores.append(board.score)
        if roundScores.count > 5 { roundScores.removeFirst() }
        difficulty = nextDifficulty()
        board = Puzzle2048V2Board(size: difficulty.gridSize)
        showWin = false
        keptPlaying = false
        mergeSet = []
    }
}

// MARK: - Glass Button Style
struct Puzzle2048V2GlassButtonStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(accent)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(accent.opacity(0.6), lineWidth: 1.5)
            )
            .shadow(color: accent.opacity(0.4), radius: 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

#Preview {
    Puzzle2048ViewV2()
}

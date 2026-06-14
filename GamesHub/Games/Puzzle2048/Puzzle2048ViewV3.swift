import SwiftUI

// MARK: - LCG Random Generator (Seed-based)
struct Puzzle2048V3LCG {
    var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // LCG parameters from Numerical Recipes
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = UInt64(range.count)
        return range.lowerBound + Int(next() % n)
    }
}

// MARK: - Seed Code Generator
struct Puzzle2048V3SeedCode {
    static let charset: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func code(from counter: Int) -> String {
        var n = UInt64(max(counter, 0) + 1)
        // Mix bits so sequential counters yield visually distinct codes
        n = n &* 2654435761
        n ^= (n >> 16)
        n = n &* 2246822519
        n ^= (n >> 13)
        let base = UInt64(charset.count)
        var chars: [Character] = []
        var v = n
        for _ in 0..<4 {
            chars.append(charset[Int(v % base)])
            v /= base
        }
        return String(chars)
    }

    static func seedValue(from counter: Int) -> UInt64 {
        var n = UInt64(max(counter, 0) + 1)
        n = n &* 6364136223846793005 &+ 1442695040888963407
        n ^= (n >> 33)
        n = n &* 0xff51afd7ed558ccd
        n ^= (n >> 33)
        return n == 0 ? 1 : n
    }
}

// MARK: - V3 Board (Seeded)
struct Puzzle2048V3Board {
    var grid: [[Int]]
    var score: Int = 0
    private var rng: Puzzle2048V3LCG

    init(seed: UInt64) {
        rng = Puzzle2048V3LCG(seed: seed)
        grid = Array(repeating: Array(repeating: 0, count: 4), count: 4)
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
            let (newCol, gained) = slideLeft(Array(col.reversed()))
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
        guard !empties.isEmpty else { return }
        let idx = rng.nextInt(in: 0..<empties.count)
        let (r, c) = empties[idx]
        let value = rng.nextInt(in: 1..<11) == 1 ? 4 : 2
        grid[r][c] = value
    }

    var hasWon: Bool { grid.flatMap { $0 }.contains(2048) }

    var isGameOver: Bool {
        for r in 0..<4 {
            for c in 0..<4 { if grid[r][c] == 0 { return false } }
        }
        for r in 0..<4 {
            for c in 0..<3 { if grid[r][c] == grid[r][c + 1] { return false } }
        }
        for r in 0..<3 {
            for c in 0..<4 { if grid[r][c] == grid[r + 1][c] { return false } }
        }
        return true
    }
}

// MARK: - V3 Tile Color
struct Puzzle2048V3TileStyle {
    static func textColor(for value: Int) -> Color {
        switch value {
        case 0:         return .clear
        case 2, 4:      return Color(.systemGray)
        case 8, 16, 32: return Color(.systemOrange)
        case 64, 128:   return Color(.systemRed)
        case 256, 512:  return Color(.systemPurple)
        default:        return Color(.systemBlue)
        }
    }

    static func innerShadowOpacity(for value: Int) -> Double {
        value == 0 ? 0.0 : 0.12
    }
}

// MARK: - V3 Neumorphic Tile View
struct Puzzle2048V3TileView: View {
    let value: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            if value != 0 {
                // Raised neumorphic tile
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.white.opacity(0.85), radius: 5, x: -3, y: -3)
                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 3, y: 3)

                // Subtle inner highlight
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.6), Color.black.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                Text("\(value)")
                    .font(.system(
                        size: value >= 1000 ? size * 0.26 : (value >= 100 ? size * 0.30 : size * 0.36),
                        weight: .bold,
                        design: .rounded
                    ))
                    .foregroundColor(Puzzle2048V3TileStyle.textColor(for: value))
                    .minimumScaleFactor(0.4)
            } else {
                // Inset empty cell (pressed/recessed)
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: -2, y: -2)
                    .shadow(color: Color.white.opacity(0.75), radius: 4, x: 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Main V3 View
struct Puzzle2048ViewV3: View {
    @State private var seedCounter: Int = 0
    @State private var board: Puzzle2048V3Board = Puzzle2048V3Board(seed: Puzzle2048V3SeedCode.seedValue(from: 0))
    @State private var currentSeedCode: String = Puzzle2048V3SeedCode.code(from: 0)
    @State private var showWin = false
    @State private var keptPlaying = false
    @AppStorage("p2048V3Best") private var bestScore: Int = 0

    private let spacing: CGFloat = 10
    private let padding: CGFloat = 12

    private var tileSize: CGFloat {
        let screen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let available = screen - padding * 2 - spacing * 3 - 32
        return available / 4
    }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                // Header Panel
                headerPanel

                // Seed display
                seedBadge

                // Grid
                gridView

                Spacer()
            }
            .padding(.top, 12)

            // Win overlay
            if showWin && !keptPlaying {
                v3WinOverlay
            }

            // Game over overlay
            if board.isGameOver && !showWin {
                v3GameOverOverlay
            }
        }
    }

    // MARK: - Header
    private var headerPanel: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("2048")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
                Text("Neumorphism Edition")
                    .font(.caption2)
                    .foregroundColor(Color(.secondaryLabel))
            }
            Spacer()
            HStack(spacing: 10) {
                v3ScoreBox(label: "SCORE", value: board.score)
                v3ScoreBox(label: "BEST", value: bestScore)
            }
            Button(action: restart) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color(.label))
                    .frame(width: 40, height: 40)
                    .neumorphicCard(radius: 20)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func v3ScoreBox(label: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(.secondaryLabel))
            Text("\(value)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
                .minimumScaleFactor(0.5)
        }
        .frame(minWidth: 60)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .neumorphicCard(radius: 10)
    }

    // MARK: - Seed Badge
    private var seedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.caption)
                .foregroundColor(Color(.systemPurple))
            Text("SEED: \(currentSeedCode)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(Color(.systemPurple))
            Spacer()
            Text("Counter #\(seedCounter + 1)")
                .font(.caption2)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .neumorphicCard(radius: 12)
        .padding(.horizontal, 20)
    }

    // MARK: - Grid
    private var gridView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.16), radius: 10, x: 6, y: 6)
                .shadow(color: Color.white.opacity(0.80), radius: 10, x: -6, y: -6)
                .padding(.horizontal, 16)

            VStack(spacing: spacing) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<4, id: \.self) { col in
                            Puzzle2048V3TileView(value: board.grid[row][col], size: tileSize)
                        }
                    }
                }
            }
            .padding(padding)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(.horizontal, 16)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    handleSwipe(translation: value.translation)
                }
        )
    }

    // MARK: - Win Overlay
    private var v3WinOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("You Win!")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(Color(.systemGreen))

                Text("SEED: \(currentSeedCode)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(Color(.systemPurple))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 10)

                Text("Score: \(board.score)")
                    .font(.title2.bold())
                    .foregroundColor(Color(.label))

                HStack(spacing: 16) {
                    Button("Keep Playing") { keptPlaying = true }
                        .buttonStyle(Puzzle2048V3NeumorphicButtonStyle())
                    Button("New Game") { restart() }
                        .buttonStyle(Puzzle2048V3NeumorphicButtonStyle(accent: Color(.systemGreen)))
                }
            }
            .padding(36)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Game Over Overlay
    private var v3GameOverOverlay: some View {
        ZStack {
            Color(.systemGray6).opacity(0.88).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Game Over")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color(.systemRed))

                Text("SEED: \(currentSeedCode)")
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(Color(.systemPurple))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 10)

                Text("Score: \(board.score)")
                    .font(.title2.bold())
                    .foregroundColor(Color(.label))

                Button("Play Again") { restart() }
                    .buttonStyle(Puzzle2048V3NeumorphicButtonStyle(accent: Color(.systemOrange)))
            }
            .padding(36)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Game Logic
    private func handleSwipe(translation: CGSize) {
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
            if board.hasWon && !keptPlaying { showWin = true }
        }
    }

    private func restart() {
        seedCounter += 1
        currentSeedCode = Puzzle2048V3SeedCode.code(from: seedCounter)
        let seed = Puzzle2048V3SeedCode.seedValue(from: seedCounter)
        board = Puzzle2048V3Board(seed: seed)
        showWin = false
        keptPlaying = false
    }
}

// MARK: - Neumorphic Button Style
struct Puzzle2048V3NeumorphicButtonStyle: ButtonStyle {
    var accent: Color = Color(.label)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(accent)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                    if configuration.isPressed {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.04))
                        // Inset (pressed) shadows
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    } else {
                        // Raised (idle) shadows done via the outer shadow modifiers
                        EmptyView()
                    }
                }
            )
            .shadow(
                color: configuration.isPressed ? .clear : Color.white.opacity(0.8),
                radius: 5, x: -3, y: -3
            )
            .shadow(
                color: configuration.isPressed ? .clear : Color.black.opacity(0.15),
                radius: 5, x: 3, y: 3
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

#Preview {
    Puzzle2048ViewV3()
}

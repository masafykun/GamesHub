import SwiftUI

// MARK: - Models

enum WordSearchDifficulty: String {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        }
    }

    var gridSize: Int {
        switch self {
        case .easy: return 8
        case .medium: return 10
        case .hard: return 12
        }
    }

    var wordCount: Int {
        switch self {
        case .easy: return 5
        case .medium: return 8
        case .hard: return 10
        }
    }
}

// MARK: - Puzzle Data

struct WordSearchPuzzleData {
    static let allWordPools: [[String]] = [
        ["SWIFT", "APPLE", "XCODE", "BUILD", "CLOUD", "STORE", "WATCH", "PHONE", "TABLE", "MUSIC"],
        ["OCEAN", "RIVER", "MOUNT", "STORM", "PLAIN", "FOREST", "DESERT", "ISLAND", "CREEK", "VALLEY"],
        ["PIZZA", "BREAD", "PASTA", "SALAD", "CURRY", "SUSHI", "TACOS", "CREPE", "BAGEL", "TOAST"],
        ["TIGER", "EAGLE", "SHARK", "WHALE", "COBRA", "PANDA", "KOALA", "LLAMA", "BISON", "CRANE"],
        ["CHESS", "POKER", "DARTS", "RUGBY", "TENNIS", "SOCCER", "GOLF", "SWIM", "SKATE", "BOWL"]
    ]

    /// Places as many words as it can and reports which ones made it in,
    /// so the puzzle never lists a word that is not actually in the grid.
    static func buildGrid(words: [String], size: Int) -> (grid: [[Character]], placed: [String]) {
        var cells: [[Character?]] = Array(repeating: Array(repeating: nil, count: size), count: size)
        let letters: [Character] = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
        var placed: [String] = []

        for word in words {
            let chars = Array(word)
            guard chars.count <= size else { continue }

            var attempts = 0
            while attempts < 300 {
                attempts += 1
                let horizontal = Bool.random()
                let rowLimit = horizontal ? size : size - chars.count + 1
                let colLimit = horizontal ? size - chars.count + 1 : size
                let row = Int.random(in: 0..<rowLimit)
                let col = Int.random(in: 0..<colLimit)

                var canPlace = true
                for (i, ch) in chars.enumerated() {
                    let r = horizontal ? row : row + i
                    let c = horizontal ? col + i : col
                    if let existing = cells[r][c], existing != ch {
                        canPlace = false
                        break
                    }
                }
                guard canPlace else { continue }

                for (i, ch) in chars.enumerated() {
                    let r = horizontal ? row : row + i
                    let c = horizontal ? col + i : col
                    cells[r][c] = ch
                }
                placed.append(word)
                break
            }
        }

        let grid = cells.map { row in row.map { $0 ?? letters.randomElement()! } }
        return (grid, placed)
    }
}

// MARK: - Main View

struct WordSearchView: View {
    @State var roundScores: [Int] = []
    @State private var difficulty: WordSearchDifficulty = .medium
    @State private var grid: [[Character]] = []
    @State private var words: [String] = []
    @State private var foundWords: Set<String> = []
    @State private var selectedCells: [(Int, Int)] = []
    @State private var highlightedCells: [String: [(Int, Int)]] = [:]
    @State private var wordColors: [String: Color] = [:]
    @State private var elapsedTime: Int = 0
    @State private var timerActive = false
    @State private var gameOver = false
    @State private var gameStarted = false
    @State private var dragStart: (Int, Int)? = nil
    @State private var dragCurrent: (Int, Int)? = nil
    @State private var timer: Timer? = nil
    @State private var showDifficultyBadge = true
    @State private var movingAverage: Double = 0
    @State private var gridSize: Int = 10
    @State private var score: Int = 0

    let wordColorPalette: [Color] = [
        .blue, .green, .orange, .purple, .pink, .red, .teal, .yellow, .cyan, .indigo
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.08, blue: 0.18),
                    Color(red: 0.12, green: 0.05, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if !gameStarted {
                startScreen
            } else if gameOver {
                gameOverScreen
            } else {
                gameScreen
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Start Screen

    var startScreen: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Word Search")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Drag across the letters to find every word")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }

            // Difficulty badge
            difficultyBadgeView(difficulty: difficulty)

            if !roundScores.isEmpty {
                VStack(spacing: 6) {
                    Text("Moving Average")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    Text(String(format: "%.0fs", movingAverage))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            VStack(spacing: 8) {
                Text("Grid: \(difficulty.gridSize)x\(difficulty.gridSize)")
                    .foregroundColor(.white.opacity(0.8))
                Text("Words: \(difficulty.wordCount)")
                    .foregroundColor(.white.opacity(0.8))
            }
            .font(.system(size: 16, weight: .medium))
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(action: startGame) {
                Text("Start Game")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 200, height: 56)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.5), radius: 12, x: 0, y: 6)
            }
        }
        .padding()
    }

    // MARK: - Game Screen

    var gameScreen: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        difficultyBadgeView(difficulty: difficulty)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(timeString(elapsedTime))
                                .font(.system(size: 22, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                            Text("\(foundWords.count)/\(words.count) found")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Grid
                    let cellSize = min((geo.size.width - 40) / CGFloat(gridSize), 40)
                    let totalGridWidth = cellSize * CGFloat(gridSize)

                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)

                        gridView(cellSize: cellSize, totalWidth: totalGridWidth)
                            .padding(8)
                    }
                    .frame(width: totalGridWidth + 16, height: totalGridWidth + 16)
                    .padding(.horizontal, (geo.size.width - totalGridWidth - 16) / 2)

                    // Word list
                    wordListView
                        .padding(.horizontal)

                    Spacer(minLength: 20)
                }
            }
        }
    }

    func gridView(cellSize: CGFloat, totalWidth: CGFloat) -> some View {
        let totalHeight = cellSize * CGFloat(gridSize)

        return ZStack(alignment: .topLeading) {
            // Highlight layers
            ForEach(Array(highlightedCells.keys), id: \.self) { word in
                if let cells = highlightedCells[word], let color = wordColors[word] {
                    ForEach(0..<cells.count, id: \.self) { i in
                        let cell = cells[i]
                        RoundedRectangle(cornerRadius: 6)
                            .fill(color.opacity(0.4))
                            .frame(width: cellSize - 2, height: cellSize - 2)
                            .offset(
                                x: CGFloat(cell.1) * cellSize + 1,
                                y: CGFloat(cell.0) * cellSize + 1
                            )
                    }
                }
            }

            // Drag selection highlight
            ForEach(0..<selectedCells.count, id: \.self) { i in
                let cell = selectedCells[i]
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.25))
                    .frame(width: cellSize - 2, height: cellSize - 2)
                    .offset(
                        x: CGFloat(cell.1) * cellSize + 1,
                        y: CGFloat(cell.0) * cellSize + 1
                    )
            }

            // Letter cells
            VStack(spacing: 0) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            let letter = grid.indices.contains(row) && grid[row].indices.contains(col)
                                ? String(grid[row][col]) : "?"
                            Text(letter)
                                .font(.system(size: cellSize * 0.45, weight: .bold, design: .monospaced))
                                .foregroundColor(cellTextColor(row: row, col: col))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(width: totalWidth, height: totalHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let col = Int(value.location.x / cellSize)
                    let row = Int(value.location.y / cellSize)
                    let clampedRow = max(0, min(gridSize - 1, row))
                    let clampedCol = max(0, min(gridSize - 1, col))

                    if dragStart == nil {
                        dragStart = (clampedRow, clampedCol)
                    }
                    dragCurrent = (clampedRow, clampedCol)
                    updateSelectedCells()
                }
                .onEnded { _ in
                    checkSelectedWord()
                    dragStart = nil
                    dragCurrent = nil
                    selectedCells = []
                }
        )
    }

    var wordListView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(words, id: \.self) { word in
                let found = foundWords.contains(word)
                HStack {
                    if found {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(wordColors[word] ?? .green)
                            .font(.system(size: 14))
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.white.opacity(0.3))
                            .font(.system(size: 14))
                    }
                    Text(word)
                        .font(.system(size: 14, weight: found ? .bold : .regular, design: .monospaced))
                        .foregroundColor(found ? (wordColors[word] ?? .white) : .white.opacity(0.7))
                        .strikethrough(found)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Game Over Screen

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("Puzzle Complete!")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Score card
            VStack(spacing: 16) {
                HStack(spacing: 40) {
                    statView(label: "Time", value: timeString(elapsedTime))
                    statView(label: "Words", value: "\(foundWords.count)/\(words.count)")
                    statView(label: "Score", value: "\(score)")
                }

                Divider()
                    .background(Color.white.opacity(0.3))

                if roundScores.count > 1 {
                    VStack(spacing: 4) {
                        Text("Moving Average (last \(roundScores.count))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Text(String(format: "%.0fs", movingAverage))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }

                // Next difficulty
                HStack(spacing: 8) {
                    Text("Next difficulty:")
                        .foregroundColor(.white.opacity(0.7))
                    difficultyBadgeView(difficulty: difficulty)
                }

                // Round history
                if !roundScores.isEmpty {
                    VStack(spacing: 6) {
                        Text("Recent Times")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        HStack(spacing: 8) {
                            ForEach(roundScores, id: \.self) { s in
                                Text("\(s)s")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            .padding(24)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button(action: resetToStart) {
                    Text("Menu")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 110, height: 50)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }

                Button(action: startGame) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 4)
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Views

    func difficultyBadgeView(difficulty: WordSearchDifficulty) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(difficulty.color.opacity(0.25))
        .overlay(
            Capsule()
                .strokeBorder(difficulty.color.opacity(0.6), lineWidth: 1)
        )
        .clipShape(Capsule())
    }

    func statView(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Game Logic

    func startGame() {
        stopTimer()
        gameOver = false
        gameStarted = true
        foundWords = []
        selectedCells = []
        highlightedCells = [:]
        wordColors = [:]
        dragStart = nil
        dragCurrent = nil
        elapsedTime = 0
        score = 0

        gridSize = difficulty.gridSize
        let count = difficulty.wordCount

        // Pick random word pool and select words
        let pool = WordSearchPuzzleData.allWordPools.randomElement()!
        let selected = Array(pool.shuffled().prefix(count))

        let built = WordSearchPuzzleData.buildGrid(words: selected, size: gridSize)
        grid = built.grid
        words = built.placed

        // Assign colors
        let shuffledColors = wordColorPalette.shuffled()
        for (i, word) in words.enumerated() {
            wordColors[word] = shuffledColors[i % shuffledColors.count]
        }

        startTimer()
    }

    func resetToStart() {
        stopTimer()
        gameStarted = false
        gameOver = false
    }

    func startTimer() {
        timerActive = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timerActive {
                elapsedTime += 1
            }
        }
    }

    func stopTimer() {
        timerActive = false
        timer?.invalidate()
        timer = nil
    }

    func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    func cellTextColor(row: Int, col: Int) -> Color {
        // Check if highlighted by found word
        for (word, cells) in highlightedCells {
            if cells.contains(where: { $0.0 == row && $0.1 == col }) {
                return (wordColors[word] ?? .white)
            }
        }
        // Check if in current selection
        if selectedCells.contains(where: { $0.0 == row && $0.1 == col }) {
            return .white
        }
        return .white.opacity(0.85)
    }

    func updateSelectedCells() {
        guard let start = dragStart, let current = dragCurrent else {
            selectedCells = []
            return
        }

        let rowDiff = current.0 - start.0
        let colDiff = current.1 - start.1

        var cells: [(Int, Int)] = []

        if rowDiff == 0 {
            // Horizontal
            let minCol = min(start.1, current.1)
            let maxCol = max(start.1, current.1)
            for c in minCol...maxCol {
                cells.append((start.0, c))
            }
        } else if colDiff == 0 {
            // Vertical
            let minRow = min(start.0, current.0)
            let maxRow = max(start.0, current.0)
            for r in minRow...maxRow {
                cells.append((r, start.1))
            }
        } else {
            // Snap to dominant axis
            if abs(rowDiff) >= abs(colDiff) {
                // Vertical snap
                let minRow = min(start.0, current.0)
                let maxRow = max(start.0, current.0)
                for r in minRow...maxRow {
                    cells.append((r, start.1))
                }
            } else {
                // Horizontal snap
                let minCol = min(start.1, current.1)
                let maxCol = max(start.1, current.1)
                for c in minCol...maxCol {
                    cells.append((start.0, c))
                }
            }
        }

        selectedCells = cells
    }

    func checkSelectedWord() {
        guard selectedCells.count >= 2 else { return }

        // Build string from selected cells (forward)
        let forwardStr = selectedCells.compactMap { (r, c) -> Character? in
            guard grid.indices.contains(r), grid[r].indices.contains(c) else { return nil }
            return grid[r][c]
        }
        let forward = String(forwardStr)
        let backward = String(forwardStr.reversed())

        for word in words {
            if !foundWords.contains(word) && (forward == word || backward == word) {
                foundWords.insert(word)
                highlightedCells[word] = selectedCells

                // Check win
                if foundWords.count == words.count {
                    handleGameOver()
                }
                return
            }
        }
    }

    func handleGameOver() {
        stopTimer()
        gameOver = true

        // Compute score: base 1000 minus elapsed time penalty
        let timePenalty = min(elapsedTime * 2, 800)
        score = max(200, 1000 - timePenalty + foundWords.count * 50)

        // Append score (time in seconds) and keep last 5
        roundScores.append(elapsedTime)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }

        // Compute moving average
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        movingAverage = avg

        // Adjust difficulty based on moving average
        adjustDifficulty(averageTime: avg)
    }

    func adjustDifficulty(averageTime: Double) {
        // Only adjust after at least 2 rounds
        guard roundScores.count >= 2 else { return }

        switch difficulty {
        case .easy:
            if averageTime < 60 {
                difficulty = .medium
            }
        case .medium:
            if averageTime < 45 {
                difficulty = .hard
            } else if averageTime > 120 {
                difficulty = .easy
            }
        case .hard:
            if averageTime > 90 {
                difficulty = .medium
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WordSearchView()
}

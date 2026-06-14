import SwiftUI

// MARK: - Models

// MARK: - LCG Random Generator

struct WordSearchLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = Int(next() >> 33)
        return range.lowerBound + (n % (range.upperBound - range.lowerBound))
    }

    mutating func nextBool() -> Bool {
        return next() % 2 == 0
    }
}

// MARK: - Puzzle Generator

struct WordSearchGenerator {
    static let puzzleSets: [[String]] = [
        ["SWIFT", "APPLE", "XCODE", "BUILD", "CLASS", "STRUCT", "ENUM", "VIEW"],
        ["OCEAN", "RIVER", "MOUNT", "CLOUD", "STORM", "FROST", "PLAIN", "DELTA"],
        ["TIGER", "EAGLE", "SHARK", "RAVEN", "COBRA", "BISON", "MOOSE", "CRANE"]
    ]

    static let gridSize = 10
    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    static func generate(seedInt: Int) -> (grid: [[WordSearchCell]], placements: [WordSearchPlacement], words: [String]) {
        let setIndex = ((seedInt - 1) % puzzleSets.count + puzzleSets.count) % puzzleSets.count
        let words = puzzleSets[setIndex]

        var lcg = WordSearchLCG(seed: seedInt)
        var grid = Array(repeating: Array(repeating: WordSearchCell(), count: gridSize), count: gridSize)
        var placements: [WordSearchPlacement] = []

        for word in words {
            var placed = false
            var attempts = 0
            while !placed && attempts < 200 {
                attempts += 1
                let isHorizontal = lcg.nextBool()
                let maxRow = isHorizontal ? gridSize : gridSize - word.count
                let maxCol = isHorizontal ? gridSize - word.count : gridSize
                guard maxRow > 0 && maxCol > 0 else { continue }
                let row = lcg.nextInt(in: 0..<maxRow)
                let col = lcg.nextInt(in: 0..<maxCol)

                var canPlace = true
                let chars = Array(word)
                for i in 0..<chars.count {
                    let r = isHorizontal ? row : row + i
                    let c = isHorizontal ? col + i : col
                    let existing = grid[r][c].letter
                    if existing != " " && existing != chars[i] {
                        canPlace = false
                        break
                    }
                }

                if canPlace {
                    for i in 0..<chars.count {
                        let r = isHorizontal ? row : row + i
                        let c = isHorizontal ? col + i : col
                        grid[r][c].letter = chars[i]
                    }
                    placements.append(WordSearchPlacement(word: word, row: row, col: col, isHorizontal: isHorizontal))
                    placed = true
                }
            }
        }

        // Fill remaining cells with random letters
        for r in 0..<gridSize {
            for c in 0..<gridSize {
                if grid[r][c].letter == " " {
                    let idx = lcg.nextInt(in: 0..<alphabet.count)
                    grid[r][c].letter = alphabet[idx]
                }
            }
        }

        return (grid, placements, words)
    }
}

// MARK: - Word Colors

private let wordSearchWordColors: [Color] = [
    .red, .blue, .green, .orange, .purple, .pink, .teal, .indigo
]

// MARK: - Main View

struct WordSearchViewV3: View {
    @State var seedInt: Int = 1
    @State private var grid: [[WordSearchCell]] = []
    @State private var placements: [WordSearchPlacement] = []
    @State private var words: [String] = []
    @State private var foundWords: Set<String> = []
    @State private var selectedCells: [(row: Int, col: Int)] = []
    @State private var dragStart: (row: Int, col: Int)? = nil
    @State private var elapsed: Int = 0
    @State private var timer: Timer? = nil
    @State private var gameWon: Bool = false
    @State private var shakeWords: Set<String> = []

    private let gridSize = WordSearchGenerator.gridSize
    private let cellSize: CGFloat = 30

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 16) {
                headerView
                seedBadge
                gridView
                wordListView
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if gameWon {
                winOverlay
            }
        }
        .onAppear { startGame() }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Word Search")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text(timerString)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(foundWords.count)/\(words.count)")
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                Text("Found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button(action: restartGame) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.primary)
                    .padding(10)
                    .neumorphicCard(radius: 12)
            }
        }
        .padding(.horizontal, 4)
    }

    private var seedBadge: some View {
        HStack {
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced).bold())
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .neumorphicCard(radius: 10)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var timerString: String {
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Grid

    private var gridView: some View {
        GeometryReader { geo in
            let totalPad: CGFloat = 32 + 8
            let available = min(geo.size.width - totalPad, 340)
            let cell = available / CGFloat(gridSize)

            ZStack(alignment: .topLeading) {
                // Highlight overlays
                ForEach(0..<gridSize, id: \.self) { r in
                    ForEach(0..<gridSize, id: \.self) { c in
                        if let wordIdx = grid[r][c].foundWordIndex {
                            let hlColor: Color = wordSearchWordColors[wordIdx % wordSearchWordColors.count].opacity(0.35)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hlColor)
                                .frame(width: cell - 2, height: cell - 2)
                                .offset(x: CGFloat(c) * cell + 1, y: CGFloat(r) * cell + 1)
                        }
                    }
                }

                // Selected highlight
                ForEach(selectedCells, id: \.col) { sc in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.yellow.opacity(0.45))
                        .frame(width: cellSize - 2, height: cellSize - 2)
                        .offset(x: CGFloat(sc.col) * cell + 1, y: CGFloat(sc.row) * cell + 1)
                }

                // Letters
                ForEach(0..<gridSize, id: \.self) { r in
                    ForEach(0..<gridSize, id: \.self) { c in
                        let letter = grid.isEmpty ? " " : String(grid[r][c].letter)
                        Text(letter)
                            .font(.system(size: cell * 0.48, weight: .semibold, design: .monospaced))
                            .frame(width: cell, height: cell)
                            .foregroundColor(.primary)
                            .offset(x: CGFloat(c) * cell, y: CGFloat(r) * cell)
                    }
                }
            }
            .frame(width: available, height: available)
            .padding(4)
            .neumorphicCard(radius: 16)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, cell: cell, available: available)
                    }
                    .onEnded { _ in
                        handleDragEnded()
                    }
            )
        }
        .frame(height: 360)
    }

    private func cellPosition(row: Int, col: Int, cell: CGFloat) -> CGPoint {
        CGPoint(x: CGFloat(col) * cell + cell / 2 + 4,
                y: CGFloat(row) * cell + cell / 2 + 4)
    }

    private func cellAt(location: CGPoint, cell: CGFloat, available: CGFloat) -> (row: Int, col: Int)? {
        let col = Int(location.x / cell)
        let row = Int(location.y / cell)
        guard row >= 0 && row < gridSize && col >= 0 && col < gridSize else { return nil }
        return (row, col)
    }

    private func handleDragChanged(value: DragGesture.Value, cell: CGFloat, available: CGFloat) {
        guard !gameWon else { return }
        let startLoc = value.startLocation
        let curLoc = value.location

        guard let startCell = cellAt(location: startLoc, cell: cell, available: available),
              let curCell = cellAt(location: curLoc, cell: cell, available: available) else { return }

        if dragStart == nil {
            dragStart = startCell
        }

        guard let ds = dragStart else { return }

        // Determine direction: horizontal or vertical only
        let dr = curCell.row - ds.row
        let dc = curCell.col - ds.col

        var cells: [(row: Int, col: Int)] = []

        if abs(dr) >= abs(dc) {
            // Vertical
            let step = dr >= 0 ? 1 : -1
            var r = ds.row
            while (step > 0 ? r <= curCell.row : r >= curCell.row) {
                cells.append((r, ds.col))
                r += step
            }
        } else {
            // Horizontal
            let step = dc >= 0 ? 1 : -1
            var c = ds.col
            while (step > 0 ? c <= curCell.col : c >= curCell.col) {
                cells.append((ds.row, c))
                c += step
            }
        }

        selectedCells = cells
    }

    private func handleDragEnded() {
        defer {
            selectedCells = []
            dragStart = nil
        }
        guard !selectedCells.isEmpty && !gameWon else { return }

        let selected = selectedCells.map { grid[$0.row][$0.col].letter }
        let forwardWord = String(selected)
        let reverseWord = String(selected.reversed())

        for word in words {
            guard !foundWords.contains(word) else { continue }
            if word == forwardWord || word == reverseWord {
                markWordFound(word: word)
                return
            }
        }
    }

    private func markWordFound(word: String) {
        guard let placementIdx = placements.firstIndex(where: { $0.word == word }),
              let wordIdx = words.firstIndex(of: word) else { return }

        let placement = placements[placementIdx]
        let chars = Array(word)

        for i in 0..<chars.count {
            let r = placement.isHorizontal ? placement.row : placement.row + i
            let c = placement.isHorizontal ? placement.col + i : placement.col
            if r < gridSize && c < gridSize {
                grid[r][c].foundWordIndex = wordIdx
            }
        }

        foundWords.insert(word)

        if foundWords.count == words.count {
            gameWon = true
            stopTimer()
        }
    }

    // MARK: - Word List

    private var wordListView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(Array(words.enumerated()), id: \.offset) { idx, word in
                let found = foundWords.contains(word)
                HStack(spacing: 6) {
                    if found {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(wordSearchWordColors[idx % wordSearchWordColors.count])
                            .font(.caption)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.secondary.opacity(0.5))
                            .font(.caption)
                    }
                    Text(word)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(found ? wordSearchWordColors[idx % wordSearchWordColors.count] : .secondary)
                        .strikethrough(found)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .neumorphicCard(radius: 10)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Win Overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Puzzle Complete!")
                    .font(.title.bold())
                    .foregroundColor(.primary)

                Text(timerString)
                    .font(.largeTitle.monospacedDigit().bold())
                    .foregroundColor(.green)

                Text("SEED: #\(seedInt)")
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(.secondary)

                Button(action: restartGame) {
                    Text("Next Puzzle")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                }
            }
            .padding(32)
            .neumorphicCard(radius: 20)
            .padding(32)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        let result = WordSearchGenerator.generate(seedInt: seedInt)
        grid = result.grid
        placements = result.placements
        words = result.words
        foundWords = []
        selectedCells = []
        dragStart = nil
        gameWon = false
        elapsed = 0
        startTimer()
    }

    private func restartGame() {
        stopTimer()
        seedInt += 1
        startGame()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !gameWon {
                elapsed += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Preview

#Preview {
    WordSearchViewV3()
}

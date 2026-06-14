import SwiftUI

// MARK: - Models

struct WordSearchPuzzle {
    let grid: [[Character]]
    let words: [String]
    let placements: [WordSearchPlacement]
}

struct WordSearchPlacement {
    let word: String
    let row: Int
    let col: Int
    let isHorizontal: Bool
}

struct WordSearchFoundWord {
    let word: String
    let cells: Set<WordSearchCell>
    let color: Color
}

struct WordSearchCell: Hashable {
    let row: Int
    let col: Int
    var letter: Character = " "
    var foundWordIndex: Int? = nil

    init(row: Int = 0, col: Int = 0) {
        self.row = row
        self.col = col
    }

    func hash(into hasher: inout Hasher) { hasher.combine(row); hasher.combine(col) }
    static func == (lhs: WordSearchCell, rhs: WordSearchCell) -> Bool {
        lhs.row == rhs.row && lhs.col == rhs.col
    }
}

// MARK: - Puzzle Sets

struct WordSearchPuzzleSet {
    static let puzzles: [WordSearchPuzzle] = [puzzle1, puzzle2, puzzle3]

    static let puzzle1: WordSearchPuzzle = {
        let words = ["SWIFT", "APPLE", "CLOUD", "GRAPH", "STACK", "QUEUE", "ARRAY", "LOOPS"]
        var grid: [[Character]] = Array(repeating: Array(repeating: "A", count: 10), count: 10)
        let placements: [WordSearchPlacement] = [
            WordSearchPlacement(word: "SWIFT", row: 0, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "APPLE", row: 2, col: 3, isHorizontal: true),
            WordSearchPlacement(word: "CLOUD", row: 4, col: 5, isHorizontal: true),
            WordSearchPlacement(word: "GRAPH", row: 7, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "STACK", row: 0, col: 7, isHorizontal: false),
            WordSearchPlacement(word: "QUEUE", row: 1, col: 2, isHorizontal: false),
            WordSearchPlacement(word: "ARRAY", row: 5, col: 9, isHorizontal: false),
            WordSearchPlacement(word: "LOOPS", row: 5, col: 0, isHorizontal: false),
        ]

        let fills: [Character] = ["B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","R","T","U","V","W","X","Y","Z"]
        var rng = WordSearchRNG(seed: 42)
        for r in 0..<10 {
            for c in 0..<10 {
                grid[r][c] = fills[rng.next() % fills.count]
            }
        }
        for p in placements {
            for i in 0..<p.word.count {
                let ch = p.word[p.word.index(p.word.startIndex, offsetBy: i)]
                if p.isHorizontal {
                    if p.col + i < 10 { grid[p.row][p.col + i] = ch }
                } else {
                    if p.row + i < 10 { grid[p.row + i][p.col] = ch }
                }
            }
        }
        return WordSearchPuzzle(grid: grid, words: words, placements: placements)
    }()

    static let puzzle2: WordSearchPuzzle = {
        let words = ["TIGER", "EAGLE", "SHARK", "WHALE", "BISON", "KOALA", "PANDA", "ZEBRA"]
        var grid: [[Character]] = Array(repeating: Array(repeating: "A", count: 10), count: 10)
        let placements: [WordSearchPlacement] = [
            WordSearchPlacement(word: "TIGER", row: 0, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "EAGLE", row: 2, col: 4, isHorizontal: true),
            WordSearchPlacement(word: "SHARK", row: 4, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "WHALE", row: 6, col: 5, isHorizontal: true),
            WordSearchPlacement(word: "BISON", row: 1, col: 1, isHorizontal: false),
            WordSearchPlacement(word: "KOALA", row: 0, col: 8, isHorizontal: false),
            WordSearchPlacement(word: "PANDA", row: 4, col: 6, isHorizontal: false),
            WordSearchPlacement(word: "ZEBRA", row: 5, col: 3, isHorizontal: false),
        ]

        let fills: [Character] = ["B","C","D","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
        var rng = WordSearchRNG(seed: 77)
        for r in 0..<10 {
            for c in 0..<10 {
                grid[r][c] = fills[rng.next() % fills.count]
            }
        }
        for p in placements {
            for i in 0..<p.word.count {
                let ch = p.word[p.word.index(p.word.startIndex, offsetBy: i)]
                if p.isHorizontal {
                    if p.col + i < 10 { grid[p.row][p.col + i] = ch }
                } else {
                    if p.row + i < 10 { grid[p.row + i][p.col] = ch }
                }
            }
        }
        return WordSearchPuzzle(grid: grid, words: words, placements: placements)
    }()

    static let puzzle3: WordSearchPuzzle = {
        let words = ["PIANO", "FLUTE", "DRUMS", "VIOLA", "BANJO", "CELLO", "OBOES", "HORNS"]
        var grid: [[Character]] = Array(repeating: Array(repeating: "A", count: 10), count: 10)
        let placements: [WordSearchPlacement] = [
            WordSearchPlacement(word: "PIANO", row: 0, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "FLUTE", row: 2, col: 2, isHorizontal: true),
            WordSearchPlacement(word: "DRUMS", row: 5, col: 0, isHorizontal: true),
            WordSearchPlacement(word: "VIOLA", row: 8, col: 4, isHorizontal: true),
            WordSearchPlacement(word: "BANJO", row: 0, col: 6, isHorizontal: false),
            WordSearchPlacement(word: "CELLO", row: 2, col: 9, isHorizontal: false),
            WordSearchPlacement(word: "OBOES", row: 4, col: 4, isHorizontal: false),
            WordSearchPlacement(word: "HORNS", row: 5, col: 2, isHorizontal: false),
        ]

        let fills: [Character] = ["A","B","C","D","E","F","G","H","I","J","K","L","M","N","P","Q","R","S","T","U","V","W","X","Y","Z"]
        var rng = WordSearchRNG(seed: 123)
        for r in 0..<10 {
            for c in 0..<10 {
                grid[r][c] = fills[rng.next() % fills.count]
            }
        }
        for p in placements {
            for i in 0..<p.word.count {
                let ch = p.word[p.word.index(p.word.startIndex, offsetBy: i)]
                if p.isHorizontal {
                    if p.col + i < 10 { grid[p.row][p.col + i] = ch }
                } else {
                    if p.row + i < 10 { grid[p.row + i][p.col] = ch }
                }
            }
        }
        return WordSearchPuzzle(grid: grid, words: words, placements: placements)
    }()
}

// MARK: - Simple RNG (deterministic fill)

struct WordSearchRNG {
    var state: Int
    init(seed: Int) { state = seed }
    mutating func next() -> Int {
        state = (state &* 1664525 &+ 1013904223) & 0x7fffffff
        return abs(state)
    }
}

// MARK: - Colors

let wordSearchColors: [Color] = [
    .red, .blue, .green, .orange, .purple, .pink, .teal, .indigo
]

// MARK: - ViewModel

class WordSearchViewModel: ObservableObject {
    @Published var puzzle: WordSearchPuzzle
    @Published var foundWords: [WordSearchFoundWord] = []
    @Published var selectedCells: Set<WordSearchCell> = []
    @Published var elapsedTime: Int = 0
    @Published var gameWon: Bool = false
    @Published var puzzleIndex: Int = 0

    private var timer: Foundation.Timer?

    init() {
        puzzle = WordSearchPuzzleSet.puzzles[0]
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.gameWon else { return }
            self.elapsedTime += 1
        }
    }

    func loadPuzzle(index: Int) {
        puzzleIndex = index
        puzzle = WordSearchPuzzleSet.puzzles[index]
        foundWords = []
        selectedCells = []
        elapsedTime = 0
        gameWon = false
        startTimer()
    }

    func commitSelection() {
        guard !selectedCells.isEmpty else { return }
        let cells = selectedCells.sorted { ($0.row, $0.col) < ($1.row, $1.col) }
        let word = cells.map { String(puzzle.grid[$0.row][$0.col]) }.joined()
        let wordReversed = String(word.reversed())

        let alreadyFound = foundWords.map { $0.word }

        for candidate in [word, wordReversed] {
            if puzzle.words.contains(candidate) && !alreadyFound.contains(candidate) {
                let colorIndex = foundWords.count % wordSearchColors.count
                let found = WordSearchFoundWord(word: candidate, cells: selectedCells, color: wordSearchColors[colorIndex])
                foundWords.append(found)
                if foundWords.count == puzzle.words.count {
                    gameWon = true
                    timer?.invalidate()
                }
                break
            }
        }
        selectedCells = []
    }

    func cellInFoundWord(_ cell: WordSearchCell) -> Color? {
        for found in foundWords {
            if found.cells.contains(cell) {
                return found.color
            }
        }
        return nil
    }

    func formattedTime() -> String {
        let m = elapsedTime / 60
        let s = elapsedTime % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Main View

struct WordSearchView: View {
    @StateObject private var vm = WordSearchViewModel()
    @State private var dragStart: WordSearchCell? = nil
    @State private var dragCurrent: WordSearchCell? = nil

    var body: some View {
        GeometryReader { geo in
            let gridSize = min(geo.size.width - 32, geo.size.height * 0.55)
            let cellSize = gridSize / 10

            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Text("Word Search")
                            .font(.title2.bold())
                        Spacer()
                        Text(vm.formattedTime())
                            .font(.title3.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Found count
                    HStack {
                        Text("Found: \(vm.foundWords.count) / \(vm.puzzle.words.count)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        // Puzzle selector
                        HStack(spacing: 6) {
                            ForEach(0..<WordSearchPuzzleSet.puzzles.count, id: \.self) { idx in
                                Button {
                                    vm.loadPuzzle(index: idx)
                                } label: {
                                    Text("\(idx + 1)")
                                        .font(.caption.bold())
                                        .frame(width: 28, height: 28)
                                        .background(vm.puzzleIndex == idx ? Color.blue : Color(.systemGray4))
                                        .foregroundColor(vm.puzzleIndex == idx ? .white : .primary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Grid
                    WordSearchGridView(
                        vm: vm,
                        gridSize: gridSize,
                        cellSize: cellSize,
                        dragStart: $dragStart,
                        dragCurrent: $dragCurrent
                    )
                    .frame(width: gridSize, height: gridSize)
                    .neumorphicCard(radius: 12)
                    .padding(.horizontal)

                    // Word list
                    WordSearchWordListView(vm: vm)
                        .padding(.horizontal)

                    Spacer()
                }
                .padding(.top, 16)

                // Win overlay
                if vm.gameWon {
                    WordSearchWinOverlay(vm: vm)
                }
            }
        }
    }
}

// MARK: - Grid View

struct WordSearchGridView: View {
    @ObservedObject var vm: WordSearchViewModel
    let gridSize: CGFloat
    let cellSize: CGFloat
    @Binding var dragStart: WordSearchCell?
    @Binding var dragCurrent: WordSearchCell?

    var highlightedCells: Set<WordSearchCell> {
        guard let start = dragStart, let current = dragCurrent else { return [] }
        return cellsBetween(start: start, end: current)
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let cs = size.width / 10

                // Draw found word highlights
                for found in vm.foundWords {
                    let cells = found.cells.sorted { ($0.row * 10 + $0.col) < ($1.row * 10 + $1.col) }
                    guard !cells.isEmpty else { continue }
                    if cells.count == 1 {
                        let c = cells[0]
                        let rect = CGRect(x: CGFloat(c.col) * cs + 2, y: CGFloat(c.row) * cs + 2, width: cs - 4, height: cs - 4)
                        context.fill(Path(ellipseIn: rect), with: .color(found.color.opacity(0.4)))
                    } else {
                        let first = cells.first!
                        let last = cells.last!
                        let isH = first.row == last.row
                        let x1 = CGFloat(first.col) * cs + cs / 2
                        let y1 = CGFloat(first.row) * cs + cs / 2
                        let x2 = CGFloat(last.col) * cs + cs / 2
                        let y2 = CGFloat(last.row) * cs + cs / 2
                        let thickness = cs * 0.75

                        var path = Path()
                        if isH {
                            path.addRoundedRect(in: CGRect(x: x1 - thickness/2, y: y1 - thickness/2, width: x2 - x1 + thickness, height: thickness), cornerSize: CGSize(width: thickness/2, height: thickness/2))
                        } else {
                            path.addRoundedRect(in: CGRect(x: x1 - thickness/2, y: y1 - thickness/2, width: thickness, height: y2 - y1 + thickness), cornerSize: CGSize(width: thickness/2, height: thickness/2))
                        }
                        context.fill(path, with: .color(found.color.opacity(0.35)))
                    }
                }

                // Draw current selection highlight
                if !highlightedCells.isEmpty {
                    let cells = highlightedCells.sorted { ($0.row * 10 + $0.col) < ($1.row * 10 + $1.col) }
                    let first = cells.first!
                    let last = cells.last!
                    let isH = first.row == last.row
                    let x1 = CGFloat(first.col) * cs + cs / 2
                    let y1 = CGFloat(first.row) * cs + cs / 2
                    let x2 = CGFloat(last.col) * cs + cs / 2
                    let y2 = CGFloat(last.row) * cs + cs / 2
                    let thickness = cs * 0.75

                    var path = Path()
                    if cells.count == 1 {
                        path.addEllipse(in: CGRect(x: x1 - thickness/2, y: y1 - thickness/2, width: thickness, height: thickness))
                    } else if isH {
                        path.addRoundedRect(in: CGRect(x: x1 - thickness/2, y: y1 - thickness/2, width: x2 - x1 + thickness, height: thickness), cornerSize: CGSize(width: thickness/2, height: thickness/2))
                    } else {
                        path.addRoundedRect(in: CGRect(x: x1 - thickness/2, y: y1 - thickness/2, width: thickness, height: y2 - y1 + thickness), cornerSize: CGSize(width: thickness/2, height: thickness/2))
                    }
                    context.fill(path, with: .color(Color.yellow.opacity(0.4)))
                }
            }

            // Letter cells
            VStack(spacing: 0) {
                ForEach(0..<10, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<10, id: \.self) { col in
                            let cell = WordSearchCell(row: row, col: col)
                            let isHighlighted = highlightedCells.contains(cell)
                            let foundColor = vm.cellInFoundWord(cell)

                            Text(String(vm.puzzle.grid[row][col]))
                                .font(.system(size: cellSize * 0.42, weight: .semibold, design: .monospaced))
                                .frame(width: cellSize, height: cellSize)
                                .foregroundColor(foundColor != nil ? foundColor! : (isHighlighted ? .orange : .primary))
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let col = Int(value.location.x / cellSize)
                    let row = Int(value.location.y / cellSize)
                    guard row >= 0, row < 10, col >= 0, col < 10 else { return }
                    let cell = WordSearchCell(row: row, col: col)
                    if dragStart == nil {
                        dragStart = cell
                    }
                    dragCurrent = cell
                }
                .onEnded { _ in
                    vm.selectedCells = highlightedCells
                    vm.commitSelection()
                    dragStart = nil
                    dragCurrent = nil
                }
        )
    }

    func cellsBetween(start: WordSearchCell, end: WordSearchCell) -> Set<WordSearchCell> {
        var cells = Set<WordSearchCell>()
        let dr = end.row - start.row
        let dc = end.col - start.col

        // Only horizontal or vertical
        if abs(dr) >= abs(dc) {
            // Vertical
            let step = dr == 0 ? 0 : (dr > 0 ? 1 : -1)
            var r = start.row
            while true {
                cells.insert(WordSearchCell(row: r, col: start.col))
                if r == end.row { break }
                r += step
            }
        } else {
            // Horizontal
            let step = dc == 0 ? 0 : (dc > 0 ? 1 : -1)
            var c = start.col
            while true {
                cells.insert(WordSearchCell(row: start.row, col: c))
                if c == end.col { break }
                c += step
            }
        }
        return cells
    }
}

// MARK: - Word List View

struct WordSearchWordListView: View {
    @ObservedObject var vm: WordSearchViewModel

    var foundWordNames: Set<String> {
        Set(vm.foundWords.map { $0.word })
    }

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(vm.puzzle.words, id: \.self) { word in
                let isFound = foundWordNames.contains(word)
                let color = vm.foundWords.first(where: { $0.word == word })?.color ?? .clear

                Text(word)
                    .font(.caption.bold())
                    .foregroundColor(isFound ? .white : .primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(isFound ? color : Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .strikethrough(isFound, color: .white)
            }
        }
        .padding()
        .neumorphicCard(radius: 12)
    }
}

// MARK: - Win Overlay

struct WordSearchWinOverlay: View {
    @ObservedObject var vm: WordSearchViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Puzzle Complete!")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Time: \(vm.formattedTime())")
                    .font(.title2)
                    .foregroundColor(.yellow)
                HStack(spacing: 16) {
                    ForEach(0..<WordSearchPuzzleSet.puzzles.count, id: \.self) { idx in
                        Button {
                            vm.loadPuzzle(index: idx)
                        } label: {
                            Text("Puzzle \(idx + 1)")
                                .font(.headline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .foregroundColor(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
            .padding(32)
            .background(Color(.systemGray).opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

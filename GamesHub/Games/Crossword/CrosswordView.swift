import SwiftUI

// MARK: - Private Models

private enum CrosswordDirection {
    case across, down
}

private struct CrosswordClue: Identifiable {
    let id = UUID()
    let number: Int
    let direction: CrosswordDirection
    let text: String
    let startRow: Int
    let startCol: Int
    let length: Int
}

private struct CrosswordPuzzleData {
    let title: String
    let solution: [[Character]]
    let clues: [CrosswordClue]
}

// MARK: - Puzzle Definitions

private func makePuzzles() -> [CrosswordPuzzleData] {
    // Puzzle 1: 7x7 grid
    // Across: 1-SWIFT(row0,col0), 6-APPLE(row1,col0 shifted), 7-XCODE(row2...)
    // We'll design a fully valid intersecting puzzle

    // Layout:
    // Row 0: S W I F T . .
    // Row 1: T . H . R A P
    // Row 2: A . L . A P P
    // Row 3: C O D E . P L
    // Row 4: K . E . F R E
    // Row 5: . A R R A Y .
    // Row 6: . . . . M . .

    let sol1: [[Character]] = [
        ["S","W","I","F","T",".","."],
        ["T",".","H",".","R","A","P"],
        ["A",".","L",".","A","P","P"],
        ["C","O","D","E",".","P","L"],
        ["K",".","E",".","F","R","E"],
        [".","A","R","R","A","Y","."],
        [".",".",".",".","M",".","."]
    ]

    let clues1: [CrosswordClue] = [
        CrosswordClue(number: 1, direction: .across, text: "Apple's programming language", startRow: 0, startCol: 0, length: 5),
        CrosswordClue(number: 6, direction: .across, text: "Code editor hidden letters: _A_", startRow: 3, startCol: 1, length: 4),
        CrosswordClue(number: 7, direction: .across, text: "Collection of elements", startRow: 5, startCol: 1, length: 5),
        CrosswordClue(number: 1, direction: .down, text: "Pile of plates metaphor in CS", startRow: 0, startCol: 0, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Loop keyword in Swift", startRow: 0, startCol: 2, length: 5),
        CrosswordClue(number: 3, direction: .down, text: "View layout container", startRow: 0, startCol: 4, length: 5),
        CrosswordClue(number: 4, direction: .down, text: "Fruit company", startRow: 1, startCol: 5, length: 4),
        CrosswordClue(number: 5, direction: .down, text: "SwiftUI view modifier target", startRow: 1, startCol: 6, length: 4),
        CrosswordClue(number: 8, direction: .down, text: "Map function result", startRow: 4, startCol: 4, length: 3)
    ]

    // Puzzle 2
    // Row 0: . C L O U D .
    // Row 1: X C O D E . .
    // Row 2: . D . . B . .
    // Row 3: . E . . U . .
    // Row 4: V I E W G . .
    // Row 5: . . . . S . .
    // Row 6: . . . . . . .

    let sol2: [[Character]] = [
        [".","C","L","O","U","D","."],
        ["X","C","O","D","E",".","."],
        [".","D",".",".", "B",".","."],
        [".","E",".",".", "U",".","."],
        ["V","I","E","W","G",".","."],
        [".",".",".",".","S",".","."],
        [".",".",".",".",".",".","." ]
    ]

    let clues2: [CrosswordClue] = [
        CrosswordClue(number: 1, direction: .across, text: "Remote storage service", startRow: 0, startCol: 1, length: 5),
        CrosswordClue(number: 3, direction: .across, text: "Apple's IDE", startRow: 1, startCol: 0, length: 5),
        CrosswordClue(number: 5, direction: .across, text: "SwiftUI fundamental building block", startRow: 4, startCol: 0, length: 4),
        CrosswordClue(number: 1, direction: .down, text: "Dark version of Xcode", startRow: 0, startCol: 1, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Binary digit pair", startRow: 1, startCol: 0, length: 1),
        CrosswordClue(number: 4, direction: .down, text: "Software defect", startRow: 0, startCol: 4, length: 5)
    ]

    // Puzzle 3
    // Row 0: B I N D . . .
    // Row 1: R . . A . . .
    // Row 2: A . . T . . .
    // Row 3: N O D E S . .
    // Row 4: C . . . . . .
    // Row 5: H U E . . . .
    // Row 6: . . . . . . .

    let sol3: [[Character]] = [
        ["B","I","N","D",".",".","." ],
        ["R",".",".","A",".",".","." ],
        ["A",".",".","T",".",".","." ],
        ["N","O","D","E","S",".","."],
        ["C",".",".",".",".",".","." ],
        ["H","U","E",".",".",".","."],
        [".",".",".",".",".",".","." ]
    ]

    let clues3: [CrosswordClue] = [
        CrosswordClue(number: 1, direction: .across, text: "SwiftUI data connection keyword", startRow: 0, startCol: 0, length: 4),
        CrosswordClue(number: 4, direction: .across, text: "Graph elements", startRow: 3, startCol: 0, length: 5),
        CrosswordClue(number: 5, direction: .across, text: "Color property", startRow: 5, startCol: 0, length: 3),
        CrosswordClue(number: 1, direction: .down, text: "SwiftUI tree component", startRow: 0, startCol: 0, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Metadata tag", startRow: 0, startCol: 3, length: 4),
        CrosswordClue(number: 3, direction: .down, text: "Organiser node", startRow: 3, startCol: 2, length: 1)
    ]

    return [
        CrosswordPuzzleData(title: "Swift & iOS", solution: sol1, clues: clues1),
        CrosswordPuzzleData(title: "Xcode World", solution: sol2, clues: clues2),
        CrosswordPuzzleData(title: "Data & Bind", solution: sol3, clues: clues3)
    ]
}

// MARK: - ViewModel

private class CrosswordViewModel: ObservableObject {
    let puzzles: [CrosswordPuzzleData]
    @Published var currentPuzzleIndex: Int = 0
    @Published var userGrid: [[Character?]]
    @Published var selectedCell: (row: Int, col: Int)? = nil
    @Published var direction: CrosswordDirection = .across
    @Published var cellStates: [[CellState]] // none, correct, wrong
    @Published var solved: Bool = false
    @Published var showMessage: String = ""

    enum CellState { case none, correct, wrong }

    init() {
        self.puzzles = makePuzzles()
        let size = 7
        self.userGrid = Array(repeating: Array(repeating: nil, count: size), count: size)
        self.cellStates = Array(repeating: Array(repeating: .none, count: size), count: size)
    }

    var currentPuzzle: CrosswordPuzzleData { puzzles[currentPuzzleIndex] }

    func isBlack(row: Int, col: Int) -> Bool {
        currentPuzzle.solution[row][col] == "."
    }

    func cellNumber(row: Int, col: Int) -> Int? {
        for clue in currentPuzzle.clues {
            if clue.startRow == row && clue.startCol == col {
                return clue.number
            }
        }
        return nil
    }

    func selectCell(row: Int, col: Int) {
        guard !isBlack(row: row, col: col) else { return }
        if let sel = selectedCell, sel.row == row, sel.col == col {
            direction = direction == .across ? .down : .across
        } else {
            selectedCell = (row, col)
        }
    }

    func currentWordCells() -> [(Int, Int)] {
        guard let sel = selectedCell else { return [] }
        var cells: [(Int, Int)] = []
        if direction == .across {
            // find start
            var startCol = sel.col
            while startCol > 0 && !isBlack(row: sel.row, col: startCol - 1) { startCol -= 1 }
            var c = startCol
            while c < 7 && !isBlack(row: sel.row, col: c) {
                cells.append((sel.row, c))
                c += 1
            }
        } else {
            var startRow = sel.row
            while startRow > 0 && !isBlack(row: startRow - 1, col: sel.col) { startRow -= 1 }
            var r = startRow
            while r < 7 && !isBlack(row: r, col: sel.col) {
                cells.append((r, sel.col))
                r += 1
            }
        }
        return cells
    }

    func isInCurrentWord(row: Int, col: Int) -> Bool {
        currentWordCells().contains { $0.0 == row && $0.1 == col }
    }

    func typeCharacter(_ char: Character) {
        guard let sel = selectedCell else { return }
        userGrid[sel.row][sel.col] = char
        cellStates[sel.row][sel.col] = .none
        advanceCursor()
    }

    func deleteCharacter() {
        guard let sel = selectedCell else { return }
        if userGrid[sel.row][sel.col] != nil {
            userGrid[sel.row][sel.col] = nil
            cellStates[sel.row][sel.col] = .none
        } else {
            retreatCursor()
            if let sel2 = selectedCell {
                userGrid[sel2.row][sel2.col] = nil
                cellStates[sel2.row][sel2.col] = .none
            }
        }
    }

    private func advanceCursor() {
        guard let sel = selectedCell else { return }
        if direction == .across {
            var c = sel.col + 1
            while c < 7 {
                if !isBlack(row: sel.row, col: c) { selectedCell = (sel.row, c); return }
                c += 1
            }
        } else {
            var r = sel.row + 1
            while r < 7 {
                if !isBlack(row: r, col: sel.col) { selectedCell = (r, sel.col); return }
                r += 1
            }
        }
    }

    private func retreatCursor() {
        guard let sel = selectedCell else { return }
        if direction == .across {
            var c = sel.col - 1
            while c >= 0 {
                if !isBlack(row: sel.row, col: c) { selectedCell = (sel.row, c); return }
                c -= 1
            }
        } else {
            var r = sel.row - 1
            while r >= 0 {
                if !isBlack(row: r, col: sel.col) { selectedCell = (r, sel.col); return }
                r -= 1
            }
        }
    }

    func checkAnswers() {
        let sol = currentPuzzle.solution
        var allCorrect = true
        for r in 0..<7 {
            for c in 0..<7 {
                if sol[r][c] == "." { continue }
                if let ch = userGrid[r][c] {
                    if ch == sol[r][c] {
                        cellStates[r][c] = .correct
                    } else {
                        cellStates[r][c] = .wrong
                        allCorrect = false
                    }
                } else {
                    allCorrect = false
                }
            }
        }
        if allCorrect {
            solved = true
            showMessage = "Puzzle Solved!"
        } else {
            showMessage = "Keep trying!"
        }
    }

    func solvePuzzle() {
        let sol = currentPuzzle.solution
        for r in 0..<7 {
            for c in 0..<7 {
                if sol[r][c] != "." {
                    userGrid[r][c] = sol[r][c]
                    cellStates[r][c] = .correct
                }
            }
        }
        solved = true
        showMessage = "Puzzle Solved!"
    }

    func loadPuzzle(_ index: Int) {
        currentPuzzleIndex = index
        let size = 7
        userGrid = Array(repeating: Array(repeating: nil, count: size), count: size)
        cellStates = Array(repeating: Array(repeating: .none, count: size), count: size)
        selectedCell = nil
        direction = .across
        solved = false
        showMessage = ""
    }

    func activeClue() -> CrosswordClue? {
        guard let sel = selectedCell else { return nil }
        let wordCells = currentWordCells()
        guard let first = wordCells.first else { return nil }
        return currentPuzzle.clues.first { $0.direction == direction && $0.startRow == first.0 && $0.startCol == first.1 }
    }
}

// MARK: - Main View

struct CrosswordView: View {
    @StateObject private var vm = CrosswordViewModel()
    private let cellSize: CGFloat = 42
    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    puzzleSelector
                    gridView
                    if let clue = vm.activeClue() {
                        activeClueView(clue)
                    }
                    keyboard
                    actionButtons
                    if !vm.showMessage.isEmpty {
                        Text(vm.showMessage)
                            .font(.headline)
                            .foregroundColor(vm.solved ? .green : .orange)
                            .padding(.bottom, 4)
                    }
                    clueList
                }
                .padding()
            }
            .navigationTitle("Crossword")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemBackground))
        }
    }

    // MARK: Puzzle Selector
    private var puzzleSelector: some View {
        HStack(spacing: 8) {
            ForEach(0..<vm.puzzles.count, id: \.self) { i in
                Button(action: { vm.loadPuzzle(i) }) {
                    Text("Puzzle \(i + 1)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(vm.currentPuzzleIndex == i ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(vm.currentPuzzleIndex == i ? .white : .primary)
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: Grid
    private var gridView: some View {
        VStack(spacing: 1) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<7, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .background(Color(.systemGray3))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let isBlack = vm.isBlack(row: row, col: col)
        let isSelected = vm.selectedCell.map { $0.row == row && $0.col == col } ?? false
        let inWord = vm.isInCurrentWord(row: row, col: col)
        let state = vm.cellStates[row][col]
        let letter = vm.userGrid[row][col]
        let number = vm.cellNumber(row: row, col: col)

        ZStack(alignment: .topLeading) {
            if isBlack {
                Color.black
                    .frame(width: cellSize, height: cellSize)
            } else {
                backgroundColor(isSelected: isSelected, inWord: inWord, state: state)
                    .frame(width: cellSize, height: cellSize)
                    .onTapGesture { vm.selectCell(row: row, col: col) }

                if let n = number {
                    Text("\(n)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(2)
                }

                if let ch = letter {
                    Text(String(ch))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(letterColor(state: state))
                        .frame(width: cellSize, height: cellSize, alignment: .center)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func backgroundColor(isSelected: Bool, inWord: Bool, state: CrosswordViewModel.CellState) -> Color {
        if isSelected { return Color.blue.opacity(0.8) }
        if inWord { return Color.blue.opacity(0.25) }
        switch state {
        case .correct: return Color.green.opacity(0.2)
        case .wrong: return Color.red.opacity(0.2)
        case .none: return Color(.systemBackground)
        }
    }

    private func letterColor(state: CrosswordViewModel.CellState) -> Color {
        switch state {
        case .correct: return .green
        case .wrong: return .red
        case .none: return .primary
        }
    }

    // MARK: Active Clue
    private func activeClueView(_ clue: CrosswordClue) -> some View {
        HStack {
            Text("\(clue.number)\(clue.direction == .across ? "A" : "D"):")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.accentColor)
            Text(clue.text)
                .font(.subheadline)
            Spacer()
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    // MARK: Keyboard
    private var keyboard: some View {
        VStack(spacing: 6) {
            let rows = [Array(letters[0..<9]), Array(letters[9..<18]), Array(letters[18..<26])]
            ForEach(0..<rows.count, id: \.self) { ri in
                HStack(spacing: 4) {
                    ForEach(rows[ri], id: \.self) { ch in
                        Button(action: { vm.typeCharacter(ch) }) {
                            Text(String(ch))
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 30, height: 36)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                    if ri == 2 {
                        Button(action: { vm.deleteCharacter() }) {
                            Image(systemName: "delete.left")
                                .font(.system(size: 14))
                                .frame(width: 44, height: 36)
                                .background(Color(.systemGray4))
                                .foregroundColor(.primary)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }

    // MARK: Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { vm.checkAnswers() }) {
                Label("Check", systemImage: "checkmark.circle")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            Button(action: { vm.solvePuzzle() }) {
                Label("Solve", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: Clue List
    private var clueList: some View {
        HStack(alignment: .top, spacing: 16) {
            clueSection(title: "Across", clues: vm.currentPuzzle.clues.filter { $0.direction == .across })
            clueSection(title: "Down", clues: vm.currentPuzzle.clues.filter { $0.direction == .down })
        }
    }

    private func clueSection(title: String, clues: [CrosswordClue]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .foregroundColor(.accentColor)
            ForEach(clues) { clue in
                Button(action: {
                    vm.selectedCell = (clue.startRow, clue.startCol)
                    vm.direction = clue.direction
                }) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(clue.number).")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(clue.text)
                            .font(.caption)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

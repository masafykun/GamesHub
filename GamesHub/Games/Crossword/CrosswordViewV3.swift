import SwiftUI

// MARK: - Private Models (V3)

private enum CrosswordV3Direction {
    case across, down
}

private struct CrosswordV3Clue: Identifiable {
    let id = UUID()
    let number: Int
    let direction: CrosswordV3Direction
    let text: String
    let startRow: Int
    let startCol: Int
    let length: Int
}

private struct CrosswordV3PuzzleData {
    let title: String
    let solution: [[Character]]
    let clues: [CrosswordV3Clue]
}

// MARK: - Neumorphic Style Helpers

private struct NeuShadow: ViewModifier {
    var isPressed: Bool = false
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(isPressed ? 0.0 : 0.18), radius: isPressed ? 0 : 8, x: isPressed ? 0 : 4, y: isPressed ? 0 : 4)
            .shadow(color: .white.opacity(isPressed ? 0.0 : 0.7), radius: isPressed ? 0 : 8, x: isPressed ? 0 : -4, y: isPressed ? 0 : -4)
    }
}

private extension View {
    func neuShadow(isPressed: Bool = false) -> some View {
        self.modifier(NeuShadow(isPressed: isPressed))
    }
}

// MARK: - Puzzle Definitions

private func makeV3Puzzles() -> [CrosswordV3PuzzleData] {
    let sol1: [[Character]] = [
        ["S","W","I","F","T",".","."],
        ["T",".","H",".","R","A","P"],
        ["A",".","L",".","A","P","P"],
        ["C","O","D","E",".","P","L"],
        ["K",".","E",".","F","R","E"],
        [".","A","R","R","A","Y","."],
        [".",".",".",".","M",".","."]
    ]
    let clues1: [CrosswordV3Clue] = [
        CrosswordV3Clue(number: 1, direction: .across, text: "Apple's programming language", startRow: 0, startCol: 0, length: 5),
        CrosswordV3Clue(number: 6, direction: .across, text: "CODE edit (4 letters)", startRow: 3, startCol: 1, length: 4),
        CrosswordV3Clue(number: 7, direction: .across, text: "Ordered collection type", startRow: 5, startCol: 1, length: 5),
        CrosswordV3Clue(number: 1, direction: .down, text: "Data structure: LIFO pile", startRow: 0, startCol: 0, length: 5),
        CrosswordV3Clue(number: 2, direction: .down, text: "Swift loop keyword", startRow: 0, startCol: 2, length: 5),
        CrosswordV3Clue(number: 3, direction: .down, text: "SwiftUI layout frame", startRow: 0, startCol: 4, length: 5),
        CrosswordV3Clue(number: 4, direction: .down, text: "Big tech fruit brand", startRow: 1, startCol: 5, length: 4),
        CrosswordV3Clue(number: 5, direction: .down, text: "View app target", startRow: 1, startCol: 6, length: 4),
        CrosswordV3Clue(number: 8, direction: .down, text: "Functional map output", startRow: 4, startCol: 4, length: 3)
    ]

    let sol2: [[Character]] = [
        [".","C","L","O","U","D","."],
        ["X","C","O","D","E",".","."],
        [".","D",".",".", "B",".","."],
        [".","E",".",".", "U",".","."],
        ["V","I","E","W","G",".","."],
        [".",".",".",".","S",".","."],
        [".",".",".",".",".",".","." ]
    ]
    let clues2: [CrosswordV3Clue] = [
        CrosswordV3Clue(number: 1, direction: .across, text: "Internet storage service", startRow: 0, startCol: 1, length: 5),
        CrosswordV3Clue(number: 3, direction: .across, text: "Apple's IDE", startRow: 1, startCol: 0, length: 5),
        CrosswordV3Clue(number: 5, direction: .across, text: "SwiftUI base protocol", startRow: 4, startCol: 0, length: 4),
        CrosswordV3Clue(number: 1, direction: .down, text: "Dark Xcode theme name", startRow: 0, startCol: 1, length: 5),
        CrosswordV3Clue(number: 2, direction: .down, text: "Binary letter X value", startRow: 1, startCol: 0, length: 1),
        CrosswordV3Clue(number: 4, direction: .down, text: "Software glitch", startRow: 0, startCol: 4, length: 5)
    ]

    let sol3: [[Character]] = [
        ["B","I","N","D",".",".","." ],
        ["R",".",".","A",".",".","." ],
        ["A",".",".","T",".",".","." ],
        ["N","O","D","E","S",".","."],
        ["C",".",".",".",".",".","." ],
        ["H","U","E",".",".",".","."],
        [".",".",".",".",".",".","." ]
    ]
    let clues3: [CrosswordV3Clue] = [
        CrosswordV3Clue(number: 1, direction: .across, text: "Data link in SwiftUI", startRow: 0, startCol: 0, length: 4),
        CrosswordV3Clue(number: 4, direction: .across, text: "Network graph elements", startRow: 3, startCol: 0, length: 5),
        CrosswordV3Clue(number: 5, direction: .across, text: "Color's tint value", startRow: 5, startCol: 0, length: 3),
        CrosswordV3Clue(number: 1, direction: .down, text: "SwiftUI tree branch", startRow: 0, startCol: 0, length: 5),
        CrosswordV3Clue(number: 2, direction: .down, text: "Type annotation token", startRow: 0, startCol: 3, length: 4),
        CrosswordV3Clue(number: 3, direction: .down, text: "Circular junction point", startRow: 3, startCol: 2, length: 1)
    ]

    return [
        CrosswordV3PuzzleData(title: "Swift & iOS", solution: sol1, clues: clues1),
        CrosswordV3PuzzleData(title: "Xcode World", solution: sol2, clues: clues2),
        CrosswordV3PuzzleData(title: "Data & Bind", solution: sol3, clues: clues3)
    ]
}

// MARK: - ViewModel

private class CrosswordV3ViewModel: ObservableObject {
    let puzzles: [CrosswordV3PuzzleData]
    @Published var currentPuzzleIndex: Int = 0
    @Published var userGrid: [[Character?]]
    @Published var selectedCell: (row: Int, col: Int)? = nil
    @Published var direction: CrosswordV3Direction = .across
    @Published var cellStates: [[V3CellState]]
    @Published var solved: Bool = false
    @Published var showMessage: String = ""

    enum V3CellState { case none, correct, wrong }

    init() {
        self.puzzles = makeV3Puzzles()
        let size = 7
        self.userGrid = Array(repeating: Array(repeating: nil, count: size), count: size)
        self.cellStates = Array(repeating: Array(repeating: .none, count: size), count: size)
    }

    var currentPuzzle: CrosswordV3PuzzleData { puzzles[currentPuzzleIndex] }

    func isBlack(row: Int, col: Int) -> Bool {
        currentPuzzle.solution[row][col] == "."
    }

    func cellNumber(row: Int, col: Int) -> Int? {
        for clue in currentPuzzle.clues {
            if clue.startRow == row && clue.startCol == col { return clue.number }
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
            var startCol = sel.col
            while startCol > 0 && !isBlack(row: sel.row, col: startCol - 1) { startCol -= 1 }
            var c = startCol
            while c < 7 && !isBlack(row: sel.row, col: c) { cells.append((sel.row, c)); c += 1 }
        } else {
            var startRow = sel.row
            while startRow > 0 && !isBlack(row: startRow - 1, col: sel.col) { startRow -= 1 }
            var r = startRow
            while r < 7 && !isBlack(row: r, col: sel.col) { cells.append((r, sel.col)); r += 1 }
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
            while c < 7 { if !isBlack(row: sel.row, col: c) { selectedCell = (sel.row, c); return }; c += 1 }
        } else {
            var r = sel.row + 1
            while r < 7 { if !isBlack(row: r, col: sel.col) { selectedCell = (r, sel.col); return }; r += 1 }
        }
    }

    private func retreatCursor() {
        guard let sel = selectedCell else { return }
        if direction == .across {
            var c = sel.col - 1
            while c >= 0 { if !isBlack(row: sel.row, col: c) { selectedCell = (sel.row, c); return }; c -= 1 }
        } else {
            var r = sel.row - 1
            while r >= 0 { if !isBlack(row: r, col: sel.col) { selectedCell = (r, sel.col); return }; r -= 1 }
        }
    }

    func checkAnswers() {
        let sol = currentPuzzle.solution
        var allCorrect = true
        for r in 0..<7 {
            for c in 0..<7 {
                if sol[r][c] == "." { continue }
                if let ch = userGrid[r][c] {
                    cellStates[r][c] = ch == sol[r][c] ? .correct : .wrong
                    if ch != sol[r][c] { allCorrect = false }
                } else { allCorrect = false }
            }
        }
        solved = allCorrect
        showMessage = allCorrect ? "Puzzle Solved!" : "Keep trying!"
    }

    func solvePuzzle() {
        let sol = currentPuzzle.solution
        for r in 0..<7 {
            for c in 0..<7 {
                if sol[r][c] != "." { userGrid[r][c] = sol[r][c]; cellStates[r][c] = .correct }
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

    func activeClue() -> CrosswordV3Clue? {
        guard let sel = selectedCell else { return nil }
        let wordCells = currentWordCells()
        guard let first = wordCells.first else { return nil }
        return currentPuzzle.clues.first { $0.direction == direction && $0.startRow == first.0 && $0.startCol == first.1 }
    }
}

// MARK: - Neumorphic View

struct CrosswordViewV3: View {
    @StateObject private var vm = CrosswordV3ViewModel()
    private let cellSize: CGFloat = 42
    private let bgColor = Color(.systemGray6)
    private let accentColor = Color(red: 0.3, green: 0.5, blue: 0.9)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    puzzleSelector
                    gridNeuCard
                    if let clue = vm.activeClue() { activeClueNeuCard(clue) }
                    keyboardNeuCard
                    actionButtonsRow
                    if !vm.showMessage.isEmpty { messageView }
                    clueListNeu
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }

    // MARK: Header
    private var headerView: some View {
        Text("Crossword")
            .font(.system(size: 26, weight: .bold, design: .rounded))
            .foregroundColor(Color(.label))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    // MARK: Puzzle selector
    private var puzzleSelector: some View {
        HStack(spacing: 10) {
            ForEach(0..<vm.puzzles.count, id: \.self) { i in
                Button(action: { vm.loadPuzzle(i) }) {
                    Text("Puzzle \(i+1)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(
                            vm.currentPuzzleIndex == i
                                ? accentColor.opacity(0.15)
                                : bgColor
                        )
                        .foregroundColor(vm.currentPuzzleIndex == i ? accentColor : Color(.secondaryLabel))
                        .cornerRadius(10)
                        .neuShadow(isPressed: vm.currentPuzzleIndex == i)
                }
            }
            Spacer()
        }
    }

    // MARK: Grid neumorphic card
    private var gridNeuCard: some View {
        VStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { col in
                        neuCell(row: row, col: col)
                    }
                }
            }
        }
        .padding(14)
        .background(bgColor)
        .cornerRadius(20)
        .neuShadow()
    }

    @ViewBuilder
    private func neuCell(row: Int, col: Int) -> some View {
        let isBlack = vm.isBlack(row: row, col: col)
        let isSelected = vm.selectedCell.map { $0.row == row && $0.col == col } ?? false
        let inWord = vm.isInCurrentWord(row: row, col: col)
        let state = vm.cellStates[row][col]
        let letter = vm.userGrid[row][col]
        let number = vm.cellNumber(row: row, col: col)

        ZStack(alignment: .topLeading) {
            if isBlack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray3))
                    .frame(width: cellSize, height: cellSize)
                    .shadow(color: .black.opacity(0.22), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.4), radius: 2, x: -1, y: -1)
            } else {
                neuCellBg(isSelected: isSelected, inWord: inWord, state: state)
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(4)
                    .onTapGesture { vm.selectCell(row: row, col: col) }

                if let n = number {
                    Text("\(n)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(.secondaryLabel))
                        .padding(2)
                }
                if let ch = letter {
                    Text(String(ch))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(neuLetterColor(state))
                        .frame(width: cellSize, height: cellSize, alignment: .center)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    @ViewBuilder
    private func neuCellBg(isSelected: Bool, inWord: Bool, state: CrosswordV3ViewModel.V3CellState) -> some View {
        if isSelected {
            // Inset effect for selected (pressed look)
            ZStack {
                accentColor.opacity(0.18)
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.6), radius: 3, x: -2, y: -2)
                RoundedRectangle(cornerRadius: 4)
                    .stroke(accentColor.opacity(0.5), lineWidth: 1.5)
            }
        } else if inWord {
            accentColor.opacity(0.1)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        } else {
            switch state {
            case .correct:
                Color.green.opacity(0.15)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.green.opacity(0.4), lineWidth: 1))
            case .wrong:
                Color.red.opacity(0.12)
                    .cornerRadius(4)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.4), lineWidth: 1))
            case .none:
                bgColor
                    .cornerRadius(4)
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 3, x: -2, y: -2)
            }
        }
    }

    private func neuLetterColor(_ state: CrosswordV3ViewModel.V3CellState) -> Color {
        switch state {
        case .correct: return Color(red: 0.1, green: 0.6, blue: 0.2)
        case .wrong: return Color(red: 0.8, green: 0.15, blue: 0.15)
        case .none: return Color(.label)
        }
    }

    // MARK: Active clue card
    private func activeClueNeuCard(_ clue: CrosswordV3Clue) -> some View {
        HStack(spacing: 8) {
            Text("\(clue.number)\(clue.direction == .across ? "A" : "D"):")
                .font(.subheadline.weight(.bold))
                .foregroundColor(accentColor)
            Text(clue.text)
                .font(.subheadline)
                .foregroundColor(Color(.label))
            Spacer()
        }
        .padding(14)
        .background(bgColor)
        .cornerRadius(14)
        .neuShadow()
    }

    // MARK: Keyboard neumorphic card
    private var keyboardNeuCard: some View {
        let rows = [Array(letters[0..<9]), Array(letters[9..<18]), Array(letters[18..<26])]
        return VStack(spacing: 8) {
            ForEach(0..<rows.count, id: \.self) { ri in
                HStack(spacing: 5) {
                    ForEach(rows[ri], id: \.self) { ch in
                        Button(action: { vm.typeCharacter(ch) }) {
                            Text(String(ch))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 28, height: 34)
                                .background(bgColor)
                                .foregroundColor(Color(.label))
                                .cornerRadius(6)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                        }
                    }
                    if ri == 2 {
                        Button(action: { vm.deleteCharacter() }) {
                            Image(systemName: "delete.left")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 40, height: 34)
                                .background(bgColor)
                                .foregroundColor(Color(.label))
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(bgColor)
        .cornerRadius(18)
        .neuShadow()
    }

    // MARK: Action buttons
    private var actionButtonsRow: some View {
        HStack(spacing: 14) {
            neuActionButton(title: "Check", icon: "checkmark.circle.fill", color: accentColor) {
                vm.checkAnswers()
            }
            neuActionButton(title: "Solve", icon: "lightbulb.fill", color: Color(red: 0.9, green: 0.55, blue: 0.1)) {
                vm.solvePuzzle()
            }
        }
    }

    private func neuActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(color)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(bgColor)
            .cornerRadius(14)
            .neuShadow()
        }
    }

    // MARK: Message
    private var messageView: some View {
        Text(vm.showMessage)
            .font(.headline.weight(.bold))
            .foregroundColor(vm.solved ? Color(red: 0.1, green: 0.6, blue: 0.2) : Color(red: 0.8, green: 0.45, blue: 0.0))
            .padding(.vertical, 2)
    }

    // MARK: Clue list neumorphic
    private var clueListNeu: some View {
        HStack(alignment: .top, spacing: 14) {
            neuClueSection(title: "Across", clues: vm.currentPuzzle.clues.filter { $0.direction == .across })
            neuClueSection(title: "Down", clues: vm.currentPuzzle.clues.filter { $0.direction == .down })
        }
    }

    private func neuClueSection(title: String, clues: [CrosswordV3Clue]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(accentColor)
            ForEach(clues) { clue in
                Button(action: {
                    vm.selectedCell = (clue.startRow, clue.startCol)
                    vm.direction = clue.direction
                }) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(clue.number).")
                            .font(.caption.weight(.bold))
                            .foregroundColor(Color(.secondaryLabel))
                            .frame(width: 18, alignment: .trailing)
                        Text(clue.text)
                            .font(.caption)
                            .foregroundColor(Color(.label))
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(bgColor)
        .cornerRadius(14)
        .neuShadow()
    }

    // Expose letters
    private var letters: [Character] { Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ") }
}

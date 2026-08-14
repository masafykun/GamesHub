import SwiftUI

// MARK: - Private Models ()

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
        CrosswordClue(number: 6, direction: .across, text: "Code + Edit (abbr)", startRow: 3, startCol: 1, length: 4),
        CrosswordClue(number: 7, direction: .across, text: "Collection of ordered elements", startRow: 5, startCol: 1, length: 5),
        CrosswordClue(number: 1, direction: .down, text: "Pile metaphor in CS", startRow: 0, startCol: 0, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Loop keyword in Swift", startRow: 0, startCol: 2, length: 5),
        CrosswordClue(number: 3, direction: .down, text: "View layout container", startRow: 0, startCol: 4, length: 5),
        CrosswordClue(number: 4, direction: .down, text: "Fruit company", startRow: 1, startCol: 5, length: 4),
        CrosswordClue(number: 5, direction: .down, text: "SwiftUI modifier target", startRow: 1, startCol: 6, length: 4),
        CrosswordClue(number: 8, direction: .down, text: "Map function result", startRow: 4, startCol: 4, length: 3)
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
    let clues2: [CrosswordClue] = [
        CrosswordClue(number: 1, direction: .across, text: "Remote storage service", startRow: 0, startCol: 1, length: 5),
        CrosswordClue(number: 3, direction: .across, text: "Apple's IDE", startRow: 1, startCol: 0, length: 5),
        CrosswordClue(number: 5, direction: .across, text: "SwiftUI building block", startRow: 4, startCol: 0, length: 4),
        CrosswordClue(number: 1, direction: .down, text: "Dark theme for Xcode", startRow: 0, startCol: 1, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Binary digit pair", startRow: 1, startCol: 0, length: 1),
        CrosswordClue(number: 4, direction: .down, text: "Software defect", startRow: 0, startCol: 4, length: 5)
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
    let clues3: [CrosswordClue] = [
        CrosswordClue(number: 1, direction: .across, text: "SwiftUI data connection", startRow: 0, startCol: 0, length: 4),
        CrosswordClue(number: 4, direction: .across, text: "Graph elements", startRow: 3, startCol: 0, length: 5),
        CrosswordClue(number: 5, direction: .across, text: "Color tint property", startRow: 5, startCol: 0, length: 3),
        CrosswordClue(number: 1, direction: .down, text: "SwiftUI tree component", startRow: 0, startCol: 0, length: 5),
        CrosswordClue(number: 2, direction: .down, text: "Metadata annotation", startRow: 0, startCol: 3, length: 4),
        CrosswordClue(number: 3, direction: .down, text: "Graph connection node", startRow: 3, startCol: 2, length: 1)
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
    @Published var cellStates: [[CellState]]
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

    func activeClue() -> CrosswordClue? {
        guard let sel = selectedCell else { return nil }
        let wordCells = currentWordCells()
        guard let first = wordCells.first else { return nil }
        return currentPuzzle.clues.first { $0.direction == direction && $0.startRow == first.0 && $0.startCol == first.1 }
    }
}

// MARK: - Glassmorphism View

struct CrosswordView: View {
    @StateObject private var vm = CrosswordViewModel()
    private let cellSize: CGFloat = 42
    private let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")

    // Glassmorphism accent color
    private let accentGlow = Color(red: 0.4, green: 0.6, blue: 1.0)
    private let wordHighlight = Color(red: 0.3, green: 0.5, blue: 1.0)

    var body: some View {
        ZStack {
            // Deep gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.18),
                    Color(red: 0.10, green: 0.05, blue: 0.22),
                    Color(red: 0.05, green: 0.10, blue: 0.20)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient glow orbs
            glowOrbs

            ScrollView {
                VStack(spacing: 18) {
                    headerView
                    puzzleSelector
                    gridGlassCard
                    if let clue = vm.activeClue() { activeClueCard(clue) }
                    keyboardCard
                    actionButtonsRow
                    if !vm.showMessage.isEmpty { messageView }
                    clueListCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: Glow orbs background decoration
    private var glowOrbs: some View {
        ZStack {
            Circle()
                .fill(accentGlow.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            Circle()
                .fill(Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 80)
                .offset(x: 120, y: 300)
        }
    }

    // MARK: Header
    private var headerView: some View {
        Text("Crossword")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(colors: [.white, accentGlow], startPoint: .leading, endPoint: .trailing)
            )
            .shadow(color: accentGlow.opacity(0.5), radius: 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Puzzle selector
    private var puzzleSelector: some View {
        HStack(spacing: 10) {
            ForEach(0..<vm.puzzles.count, id: \.self) { i in
                Button(action: { vm.loadPuzzle(i) }) {
                    Text("Puzzle \(i+1)")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            vm.currentPuzzleIndex == i
                                ? accentGlow.opacity(0.35)
                                : Color.white.opacity(0.08)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    vm.currentPuzzleIndex == i ? accentGlow : Color.white.opacity(0.15),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: vm.currentPuzzleIndex == i ? accentGlow.opacity(0.4) : .clear, radius: 10)
                }
            }
            Spacer()
        }
    }

    // MARK: Grid glass card
    private var gridGlassCard: some View {
        VStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<7, id: \.self) { col in
                        glassCell(row: row, col: col)
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: accentGlow.opacity(0.3), radius: 20, x: 0, y: 0)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func glassCell(row: Int, col: Int) -> some View {
        let isBlack = vm.isBlack(row: row, col: col)
        let isSelected = vm.selectedCell.map { $0.row == row && $0.col == col } ?? false
        let inWord = vm.isInCurrentWord(row: row, col: col)
        let state = vm.cellStates[row][col]
        let letter = vm.userGrid[row][col]
        let number = vm.cellNumber(row: row, col: col)

        ZStack(alignment: .topLeading) {
            if isBlack {
                Color.black.opacity(0.8)
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(4)
            } else {
                glassCellBg(isSelected: isSelected, inWord: inWord, state: state)
                    .frame(width: cellSize, height: cellSize)
                    .cornerRadius(4)
                    .onTapGesture { vm.selectCell(row: row, col: col) }

                if let n = number {
                    Text("\(n)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(2)
                }
                if let ch = letter {
                    Text(String(ch))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(glassLetterColor(state))
                        .frame(width: cellSize, height: cellSize, alignment: .center)
                }
            }
        }
        .frame(width: cellSize, height: cellSize)
    }

    private func glassCellBg(isSelected: Bool, inWord: Bool, state: CrosswordViewModel.CellState) -> some View {
        Group {
            if isSelected {
                accentGlow.opacity(0.7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    )
            } else if inWord {
                accentGlow.opacity(0.25)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(accentGlow.opacity(0.4), lineWidth: 1)
                    )
            } else {
                switch state {
                case .correct:
                    Color.green.opacity(0.3)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.green.opacity(0.5), lineWidth: 1))
                case .wrong:
                    Color.red.opacity(0.3)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.5), lineWidth: 1))
                case .none:
                    Color.white.opacity(0.12)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                }
            }
        }
    }

    private func glassLetterColor(_ state: CrosswordViewModel.CellState) -> Color {
        switch state {
        case .correct: return Color(red: 0.4, green: 1.0, blue: 0.6)
        case .wrong: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .none: return .white
        }
    }

    // MARK: Active clue card
    private func activeClueCard(_ clue: CrosswordClue) -> some View {
        HStack(spacing: 8) {
            Text("\(clue.number)\(clue.direction == .across ? "A" : "D"):")
                .font(.subheadline.weight(.bold))
                .foregroundColor(accentGlow)
            Text(clue.text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .shadow(color: accentGlow.opacity(0.2), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accentGlow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: Keyboard card
    private var keyboardCard: some View {
        let rows = [Array(letters[0..<9]), Array(letters[9..<18]), Array(letters[18..<26])]
        return VStack(spacing: 6) {
            ForEach(0..<rows.count, id: \.self) { ri in
                HStack(spacing: 4) {
                    ForEach(rows[ri], id: \.self) { ch in
                        Button(action: { vm.typeCharacter(ch) }) {
                            Text(String(ch))
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 29, height: 34)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                                )
                        }
                    }
                    if ri == 2 {
                        Button(action: { vm.deleteCharacter() }) {
                            Image(systemName: "delete.left")
                                .font(.system(size: 13))
                                .frame(width: 40, height: 34)
                                .background(Color.white.opacity(0.18))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: accentGlow.opacity(0.2), radius: 15)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Action buttons
    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            Button(action: { vm.checkAnswers() }) {
                Label("Check", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [accentGlow.opacity(0.6), Color(red: 0.3, green: 0.2, blue: 0.9).opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: accentGlow.opacity(0.4), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
            Button(action: { vm.solvePuzzle() }) {
                Label("Solve", systemImage: "lightbulb.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(colors: [Color(red: 1.0, green: 0.6, blue: 0.2).opacity(0.6), Color(red: 0.9, green: 0.3, blue: 0.5).opacity(0.6)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: Color.orange.opacity(0.4), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
        }
    }

    // MARK: Message
    private var messageView: some View {
        Text(vm.showMessage)
            .font(.headline.weight(.bold))
            .foregroundColor(vm.solved ? Color(red: 0.4, green: 1.0, blue: 0.6) : Color(red: 1.0, green: 0.8, blue: 0.3))
            .shadow(color: vm.solved ? Color.green.opacity(0.5) : Color.orange.opacity(0.5), radius: 8)
            .padding(.vertical, 4)
    }

    // MARK: Clue list card
    private var clueListCard: some View {
        HStack(alignment: .top, spacing: 12) {
            glassClueSection(title: "Across", clues: vm.currentPuzzle.clues.filter { $0.direction == .across })
            glassClueSection(title: "Down", clues: vm.currentPuzzle.clues.filter { $0.direction == .down })
        }
    }

    private func glassClueSection(title: String, clues: [CrosswordClue]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundColor(accentGlow)
                .shadow(color: accentGlow.opacity(0.4), radius: 4)
            ForEach(clues) { clue in
                Button(action: {
                    vm.selectedCell = (clue.startRow, clue.startCol)
                    vm.direction = clue.direction
                }) {
                    HStack(alignment: .top, spacing: 4) {
                        Text("\(clue.number).")
                            .font(.caption.weight(.bold))
                            .foregroundColor(accentGlow.opacity(0.8))
                            .frame(width: 18, alignment: .trailing)
                        Text(clue.text)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: accentGlow.opacity(0.15), radius: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

}

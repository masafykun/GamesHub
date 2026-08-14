import SwiftUI

// MARK: - Models

struct SudokuCell: Identifiable {
    let id: Int
    var value: Int = 0
    var isGiven: Bool = false
    var isInvalid: Bool = false
}

enum SudokuDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var preFilledCount: Int {
        switch self {
        case .easy:   return 44
        case .medium: return 36
        case .hard:   return 28
        }
    }

    var color: Color {
        switch self {
        case .easy:   return .green
        case .medium: return .orange
        case .hard:   return .red
        }
    }
}

enum SudokuPuzzleFactory {
    /// A valid base grid, then shuffled so every deal is a genuinely different board.
    private static let baseGrid: [Int] = {
        var grid = [Int](repeating: 0, count: 81)
        for r in 0..<9 {
            for c in 0..<9 {
                grid[r * 9 + c] = ((r * 3 + r / 3 + c) % 9) + 1
            }
        }
        return grid
    }()

    static func makeSolution() -> [Int] {
        var grid = baseGrid

        // Swap rows inside each band, then the bands themselves.
        for band in 0..<3 {
            let order = Array(0..<3).shuffled()
            var newRows = [[Int]]()
            for i in order {
                let r = band * 3 + i
                newRows.append(Array(grid[(r * 9)..<(r * 9 + 9)]))
            }
            for i in 0..<3 {
                let r = band * 3 + i
                grid.replaceSubrange((r * 9)..<(r * 9 + 9), with: newRows[i])
            }
        }

        let bandOrder = Array(0..<3).shuffled()
        var banded = [Int]()
        for band in bandOrder {
            banded.append(contentsOf: grid[(band * 27)..<(band * 27 + 27)])
        }
        grid = banded

        // Same treatment for columns.
        var columns: [[Int]] = (0..<9).map { c in (0..<9).map { r in grid[r * 9 + c] } }
        var newColumns = [[Int]]()
        for stack in Array(0..<3).shuffled() {
            for i in Array(0..<3).shuffled() {
                newColumns.append(columns[stack * 3 + i])
            }
        }
        columns = newColumns
        for c in 0..<9 {
            for r in 0..<9 {
                grid[r * 9 + c] = columns[c][r]
            }
        }

        // Finally relabel the digits.
        let digits = Array(1...9).shuffled()
        return grid.map { digits[$0 - 1] }
    }

    static func makePuzzle(difficulty: SudokuDifficulty) -> (cells: [SudokuCell], solution: [Int]) {
        let solution = makeSolution()
        let toRemove = 81 - difficulty.preFilledCount
        let removed = Set(Array(0..<81).shuffled().prefix(toRemove))

        let cells = solution.enumerated().map { idx, val -> SudokuCell in
            let given = !removed.contains(idx)
            return SudokuCell(id: idx, value: given ? val : 0, isGiven: given)
        }
        return (cells, solution)
    }
}

// MARK: - Main View

struct SudokuView: View {
    @State private var roundTimes: [Int] = []
    @State private var difficulty: SudokuDifficulty = .easy

    @State private var cells: [SudokuCell] = []
    @State private var solution: [Int] = []
    @State private var selectedIndex: Int? = nil

    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var mistakesCount: Int = 0
    @State private var gameWon: Bool = false
    @State private var showValidation: Bool = false

    @AppStorage("sudokuBestTime") private var bestTime: Int = 0

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient.ignoresSafeArea()

            VStack(spacing: 12) {
                headerBar
                difficultyBadge
                boardView
                numberPicker
                controlButtons
            }
            .padding(12)

            if gameWon {
                winOverlay
            }
        }
        .onAppear {
            if cells.isEmpty { startNewGame() }
        }
        .onDisappear { stopTimer() }
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.07, green: 0.07, blue: 0.15), Color(red: 0.12, green: 0.08, blue: 0.22)]
                : [Color(red: 0.85, green: 0.88, blue: 0.97), Color(red: 0.75, green: 0.80, blue: 0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SUDOKU")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(bestTime > 0 ? "Best: \(timeString(bestTime))" : "Fill every row, column and box")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption)
                    Text(timeString(elapsedSeconds))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle").font(.caption)
                    Text("Mistakes: \(mistakesCount)").font(.caption)
                }
                .foregroundColor(mistakesCount > 0 ? .red : .secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var difficultyBadge: some View {
        HStack(spacing: 8) {
            Circle().fill(difficulty.color).frame(width: 8, height: 8)
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(difficulty.color)
            Text("· \(difficulty.preFilledCount) given")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text("\(remainingCells) left")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var remainingCells: Int {
        cells.filter { $0.value == 0 }.count
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = (size - 4) / 9

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                cellView(idx: row * 9 + col, cellSize: cellSize)
                            }
                        }
                    }
                }
                .padding(2)

                boxBordersOverlay(size: size)
                    .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func cellView(idx: Int, cellSize: CGFloat) -> some View {
        if idx < cells.count {
            let cell = cells[idx]
            let isSelected = selectedIndex == idx

            ZStack {
                Rectangle()
                    .fill(cellBackground(
                        isSelected: isSelected,
                        isHighlighted: isRelatedToSelected(idx: idx),
                        isSameValue: isSameValueAsSelected(idx: idx),
                        isInvalid: cell.isInvalid
                    ))

                if cell.value != 0 {
                    Text("\(cell.value)")
                        .font(.system(size: cellSize * 0.5,
                                      weight: cell.isGiven ? .bold : .regular,
                                      design: .rounded))
                        .foregroundColor(cellTextColor(cell: cell, isSelected: isSelected))
                }

                Rectangle()
                    .stroke(Color.gray.opacity(0.25), lineWidth: 0.5)
            }
            .frame(width: cellSize, height: cellSize)
            .contentShape(Rectangle())
            .onTapGesture {
                if !gameWon {
                    selectedIndex = (selectedIndex == idx) ? nil : idx
                }
            }
        }
    }

    private func boxBordersOverlay(size: CGFloat) -> some View {
        let cellSize = (size - 4) / 9
        let offset: CGFloat = 2

        return ZStack {
            ForEach(0..<4, id: \.self) { i in
                let x = offset + CGFloat(i) * cellSize * 3
                Rectangle()
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: i == 0 || i == 3 ? 1.5 : 2.5, height: size - 4)
                    .position(x: x, y: size / 2)

                Rectangle()
                    .fill(Color.primary.opacity(0.6))
                    .frame(width: size - 4, height: i == 0 || i == 3 ? 1.5 : 2.5)
                    .position(x: size / 2, y: x)
            }
        }
    }

    private func cellBackground(isSelected: Bool, isHighlighted: Bool, isSameValue: Bool, isInvalid: Bool) -> Color {
        if isInvalid && showValidation { return Color.red.opacity(0.35) }
        if isSelected { return Color.blue.opacity(colorScheme == .dark ? 0.6 : 0.45) }
        if isSameValue { return Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.18) }
        if isHighlighted { return Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.09) }
        return Color.clear
    }

    private func cellTextColor(cell: SudokuCell, isSelected: Bool) -> Color {
        if cell.isInvalid && showValidation { return .red }
        if cell.isGiven { return .primary }
        return isSelected ? .white : Color.blue.opacity(0.9)
    }

    // MARK: - Input

    private var numberPicker: some View {
        HStack(spacing: 5) {
            ForEach(1...9, id: \.self) { n in
                Button(action: { enterNumber(n) }) {
                    VStack(spacing: 1) {
                        Text("\(n)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("\(max(0, 9 - countForNumber(n)))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(countForNumber(n) >= 9 ? AnyShapeStyle(Color.blue.opacity(0.25)) : AnyShapeStyle(.ultraThinMaterial))
                    )
                }
            }

            Button(action: eraseNumber) {
                Image(systemName: "delete.left")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: { startNewGame() }) {
                Label("New", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button(action: validateBoard) {
                Label("Check", systemImage: "checkmark.shield")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.blue.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Win

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                Text("Puzzle Solved!")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock.fill")
                        Text("Time: \(timeString(elapsedSeconds))")
                    }
                    .font(.system(size: 18, weight: .semibold))

                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(mistakesCount > 0 ? .red : .green)
                        Text("Mistakes: \(mistakesCount)")
                    }
                    .font(.system(size: 16))

                    HStack {
                        Circle().fill(nextDifficulty.color).frame(width: 8, height: 8)
                        Text("Next: \(nextDifficulty.rawValue)")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }

                Button(action: { startNewGame() }) {
                    Text("Next Puzzle")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(28)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
    }

    // MARK: - Logic

    private func startNewGame() {
        stopTimer()
        difficulty = nextDifficulty
        let puzzle = SudokuPuzzleFactory.makePuzzle(difficulty: difficulty)
        cells = puzzle.cells
        solution = puzzle.solution
        selectedIndex = nil
        elapsedSeconds = 0
        mistakesCount = 0
        gameWon = false
        showValidation = false
        startTimer()
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if !gameWon { elapsedSeconds += 1 }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func enterNumber(_ n: Int) {
        guard let idx = selectedIndex, !gameWon else { return }
        guard !cells[idx].isGiven else { return }

        cells[idx].value = n
        cells[idx].isInvalid = false
        showValidation = false

        if !isValidPlacement(idx: idx, value: n) {
            mistakesCount += 1
        }

        checkWin()
    }

    private func eraseNumber() {
        guard let idx = selectedIndex, !cells[idx].isGiven else { return }
        cells[idx].value = 0
        cells[idx].isInvalid = false
        showValidation = false
    }

    private func isValidPlacement(idx: Int, value: Int) -> Bool {
        let row = idx / 9, col = idx % 9

        for c in 0..<9 {
            let i = row * 9 + c
            if i != idx && cells[i].value == value { return false }
        }
        for r in 0..<9 {
            let i = r * 9 + col
            if i != idx && cells[i].value == value { return false }
        }
        let boxRow = (row / 3) * 3, boxCol = (col / 3) * 3
        for r in boxRow..<(boxRow + 3) {
            for c in boxCol..<(boxCol + 3) {
                let i = r * 9 + c
                if i != idx && cells[i].value == value { return false }
            }
        }
        return true
    }

    private func validateBoard() {
        showValidation = true
        var hasErrors = false

        for idx in 0..<cells.count {
            cells[idx].isInvalid = false
            guard cells[idx].value != 0 else { continue }
            if !isValidPlacement(idx: idx, value: cells[idx].value) {
                cells[idx].isInvalid = true
                hasErrors = true
            }
        }

        if !hasErrors && cells.allSatisfy({ $0.value != 0 }) {
            handleWin()
        }
    }

    private func checkWin() {
        guard cells.allSatisfy({ $0.value != 0 }) else { return }
        for idx in 0..<cells.count where !isValidPlacement(idx: idx, value: cells[idx].value) {
            return
        }
        handleWin()
    }

    private func handleWin() {
        gameWon = true
        stopTimer()
        if bestTime == 0 || elapsedSeconds < bestTime { bestTime = elapsedSeconds }
        roundTimes.append(elapsedSeconds)
        if roundTimes.count > 5 {
            roundTimes.removeFirst(roundTimes.count - 5)
        }
    }

    // MARK: - Adaptive difficulty

    private var movingAverage: Int {
        guard !roundTimes.isEmpty else { return 0 }
        return roundTimes.reduce(0, +) / roundTimes.count
    }

    /// Solve fast and the next board hands you fewer digits.
    private var nextDifficulty: SudokuDifficulty {
        guard roundTimes.count >= 1 else { return difficulty }
        let avg = movingAverage
        switch difficulty {
        case .easy:   return avg < 150 ? .medium : .easy
        case .medium:
            if avg < 200 { return .hard }
            if avg > 420 { return .easy }
            return .medium
        case .hard:   return avg > 600 ? .medium : .hard
        }
    }

    // MARK: - Helpers

    private func isRelatedToSelected(idx: Int) -> Bool {
        guard let sel = selectedIndex, sel != idx else { return false }
        let selRow = sel / 9, selCol = sel % 9
        let row = idx / 9, col = idx % 9
        return row == selRow || col == selCol || (row / 3 == selRow / 3 && col / 3 == selCol / 3)
    }

    private func isSameValueAsSelected(idx: Int) -> Bool {
        guard let sel = selectedIndex, sel != idx else { return false }
        let selVal = cells[sel].value
        guard selVal != 0 else { return false }
        return cells[idx].value == selVal
    }

    private func countForNumber(_ n: Int) -> Int {
        cells.filter { $0.value == n }.count
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#Preview {
    SudokuView()
        .preferredColorScheme(.dark)
}

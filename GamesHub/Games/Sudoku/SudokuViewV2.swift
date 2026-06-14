import SwiftUI

// MARK: - Models

enum SudokuDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var preFilledCount: Int {
        switch self {
        case .easy:   return 45
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

// MARK: - Puzzle Data

struct SudokuPuzzleData {
    // Full solution + holes punched based on difficulty
    static let solutions: [[Int]] = [
        // Puzzle 0
        [5,3,4,6,7,8,9,1,2,
         6,7,2,1,9,5,3,4,8,
         1,9,8,3,4,2,5,6,7,
         8,5,9,7,6,1,4,2,3,
         4,2,6,8,5,3,7,9,1,
         7,1,3,9,2,4,8,5,6,
         9,6,1,5,3,7,2,8,4,
         2,8,7,4,1,9,6,3,5,
         3,4,5,2,8,6,1,7,9],
        // Puzzle 1
        [1,2,3,4,5,6,7,8,9,
         4,5,6,7,8,9,1,2,3,
         7,8,9,1,2,3,4,5,6,
         2,1,4,3,6,5,8,9,7,
         3,6,5,8,9,7,2,1,4,
         8,9,7,2,1,4,3,6,5,
         5,3,1,6,4,2,9,7,8,
         6,4,2,9,7,8,5,3,1,
         9,7,8,5,3,1,6,4,2],
        // Puzzle 2
        [8,2,7,1,5,4,3,9,6,
         9,6,5,3,2,7,1,4,8,
         3,4,1,6,8,9,7,5,2,
         5,9,3,4,6,8,2,7,1,
         4,7,2,5,1,3,6,8,9,
         6,1,8,9,7,2,4,3,5,
         7,8,6,2,3,5,9,1,4,
         1,5,4,7,9,6,8,2,3,
         2,3,9,8,4,1,5,6,7]
    ]

    static func makePuzzle(solutionIndex: Int, difficulty: SudokuDifficulty) -> [SudokuCell] {
        let sol = solutions[solutionIndex]
        let totalCells = 81
        let toRemove = totalCells - difficulty.preFilledCount

        var indices = Array(0..<totalCells).shuffled()
        let removedSet = Set(indices.prefix(toRemove))

        return sol.enumerated().map { idx, val in
            let preFilled = !removedSet.contains(idx)
            return SudokuCell(id: idx, value: preFilled ? val : 0, isGiven: preFilled)
        }
    }
}

// MARK: - Main View

struct SudokuViewV2: View {
    // Adaptive difficulty
    @State var roundScores: [Int] = []
    @State private var difficulty: SudokuDifficulty = .easy

    // Board state
    @State private var cells: [SudokuCell] = []
    @State private var solutionIndex: Int = 0
    @State private var selectedIndex: Int? = nil

    // Game state
    @State private var elapsedSeconds: Int = 0
    @State private var timer: Timer? = nil
    @State private var isRunning: Bool = false
    @State private var mistakesCount: Int = 0
    @State private var gameWon: Bool = false
    @State private var showValidation: Bool = false

    // UI
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 16) {
                headerBar
                difficultyBadge
                boardView
                numberPicker
                controlButtons
            }
            .padding()

            if gameWon {
                winOverlay
            }
        }
        .onAppear {
            startNewGame()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // MARK: - Background

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
                Text("Adaptive Difficulty")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(timeString(elapsedSeconds))
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                }
                .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "xmark.circle")
                        .font(.caption)
                    Text("Mistakes: \(mistakesCount)")
                        .font(.caption)
                }
                .foregroundColor(mistakesCount > 0 ? .red : .secondary)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Difficulty Badge

    private var difficultyBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(difficulty.color)
                .frame(width: 8, height: 8)
            Text(difficulty.rawValue)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(difficulty.color)
            if !roundScores.isEmpty {
                Text("• Avg: \(movingAverage)s")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("Puzzle \(solutionIndex + 1) of 3")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Board

    private var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = (size - 4) / 9

            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)

                // Cells grid
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                let idx = row * 9 + col
                                cellView(idx: idx, row: row, col: col, cellSize: cellSize)
                            }
                        }
                    }
                }
                .padding(2)

                // Box borders overlay
                boxBordersOverlay(size: size)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cellView(idx: Int, row: Int, col: Int, cellSize: CGFloat) -> some View {
        let cell = cells[idx]
        let isSelected = selectedIndex == idx
        let isHighlighted = isRelatedToSelected(idx: idx)
        let isSameValue = isSameValueAsSelected(idx: idx)

        return ZStack {
            // Cell background
            Rectangle()
                .fill(cellBackground(isSelected: isSelected,
                                     isHighlighted: isHighlighted,
                                     isSameValue: isSameValue,
                                     isInvalid: cell.isInvalid))
                .frame(width: cellSize, height: cellSize)

            // Cell value
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.5, weight: cell.isGiven ? .bold : .regular, design: .rounded))
                    .foregroundColor(cellTextColor(cell: cell, isSelected: isSelected))
            }

            // Thin cell dividers
            Rectangle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                .frame(width: cellSize, height: cellSize)
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture {
            if !gameWon {
                selectedIndex = (selectedIndex == idx) ? nil : idx
            }
        }
    }

    private func boxBordersOverlay(size: CGFloat) -> some View {
        let cellSize = (size - 4) / 9
        let offset: CGFloat = 2

        return ZStack {
            // 3x3 box thick borders
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
        if isInvalid && showValidation {
            return Color.red.opacity(0.35)
        }
        if isSelected {
            return Color.blue.opacity(colorScheme == .dark ? 0.6 : 0.45)
        }
        if isSameValue {
            return Color.blue.opacity(colorScheme == .dark ? 0.25 : 0.18)
        }
        if isHighlighted {
            return Color.blue.opacity(colorScheme == .dark ? 0.12 : 0.09)
        }
        return Color.clear
    }

    private func cellTextColor(cell: SudokuCell, isSelected: Bool) -> Color {
        if cell.isInvalid && showValidation {
            return .red
        }
        if cell.isGiven {
            return .primary
        }
        return isSelected ? .white : Color.blue.opacity(0.9)
    }

    // MARK: - Number Picker

    private var numberPicker: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { n in
                Button(action: { enterNumber(n) }) {
                    Text("\(n)")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(numberButtonBackground(n))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Erase button
            Button(action: { eraseNumber() }) {
                Image(systemName: "delete.left")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal, 4)
    }

    private func numberButtonBackground(_ n: Int) -> some View {
        ZStack {
            if selectedCountForNumber(n) > 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.2))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Control Buttons

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button(action: restartGame) {
                Label("Restart", systemImage: "arrow.counterclockwise")
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
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Win Overlay

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { }

            VStack(spacing: 20) {
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
                        Circle()
                            .fill(difficulty.color)
                            .frame(width: 8, height: 8)
                        Text("Next: \(nextDifficulty.rawValue)")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }

                if roundScores.count > 1 {
                    Text("Recent avg: \(movingAverage)s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Button(action: restartGame) {
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
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(32)
        }
    }

    // MARK: - Game Logic

    private func startNewGame() {
        stopTimer()
        solutionIndex = Int.random(in: 0..<SudokuPuzzleData.solutions.count)
        cells = SudokuPuzzleData.makePuzzle(solutionIndex: solutionIndex, difficulty: difficulty)
        selectedIndex = nil
        elapsedSeconds = 0
        mistakesCount = 0
        gameWon = false
        showValidation = false
        startTimer()
    }

    private func restartGame() {
        // Record score if game was ongoing (not first start)
        if elapsedSeconds > 5 && !gameWon {
            appendScore(elapsedSeconds)
            adjustDifficulty()
        }
        difficulty = nextDifficulty
        startNewGame()
    }

    private func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if isRunning && !gameWon {
                elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    private func enterNumber(_ n: Int) {
        guard let idx = selectedIndex else { return }
        guard !cells[idx].isGiven else { return }
        guard !gameWon else { return }

        let oldValue = cells[idx].value
        cells[idx].value = n
        cells[idx].value = n

        // Check if placement is a mistake
        if !isValidPlacement(idx: idx, value: n) {
            mistakesCount += 1
        }

        showValidation = false
        cells[idx].isInvalid = false

        checkWin()
    }

    private func eraseNumber() {
        guard let idx = selectedIndex else { return }
        guard !cells[idx].isGiven else { return }
        cells[idx].value = 0
        cells[idx].value = 0
        cells[idx].isInvalid = false
        showValidation = false
    }

    private func isValidPlacement(idx: Int, value: Int) -> Bool {
        let row = idx / 9
        let col = idx % 9

        // Check row
        for c in 0..<9 {
            let i = row * 9 + c
            if i != idx && cells[i].value == value { return false }
        }

        // Check col
        for r in 0..<9 {
            let i = r * 9 + col
            if i != idx && cells[i].value == value { return false }
        }

        // Check 3x3 box
        let boxRow = (row / 3) * 3
        let boxCol = (col / 3) * 3
        for r in boxRow..<(boxRow+3) {
            for c in boxCol..<(boxCol+3) {
                let i = r * 9 + c
                if i != idx && cells[i].value == value { return false }
            }
        }

        return true
    }

    private func validateBoard() {
        showValidation = true
        var hasErrors = false

        for idx in 0..<81 {
            cells[idx].isInvalid = false
            guard cells[idx].value != 0 else { continue }
            if !isValidPlacement(idx: idx, value: cells[idx].value) {
                cells[idx].isInvalid = true
                hasErrors = true
            }
        }

        if !hasErrors {
            let allFilled = cells.allSatisfy { $0.value != 0 }
            if allFilled {
                handleWin()
            }
        }
    }

    private func checkWin() {
        let allFilled = cells.allSatisfy { $0.value != 0 }
        guard allFilled else { return }

        // Quick validity check
        for idx in 0..<81 {
            if !isValidPlacement(idx: idx, value: cells[idx].value) {
                return
            }
        }

        handleWin()
    }

    private func handleWin() {
        gameWon = true
        stopTimer()
        appendScore(elapsedSeconds)
        adjustDifficulty()
    }

    // MARK: - Adaptive Difficulty

    private func appendScore(_ score: Int) {
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores.removeFirst(roundScores.count - 5)
        }
    }

    private var movingAverage: Int {
        guard !roundScores.isEmpty else { return 0 }
        return roundScores.reduce(0, +) / roundScores.count
    }

    private var nextDifficulty: SudokuDifficulty {
        guard roundScores.count >= 2 else { return difficulty }

        let avg = movingAverage
        // Fast solver (<90s): increase difficulty
        // Slow solver (>240s): decrease difficulty
        switch difficulty {
        case .easy:
            return avg < 90 ? .medium : .easy
        case .medium:
            if avg < 120 { return .hard }
            if avg > 240 { return .easy }
            return .medium
        case .hard:
            return avg > 300 ? .medium : .hard
        }
    }

    private func adjustDifficulty() {
        difficulty = nextDifficulty
    }

    // MARK: - Selection Helpers

    private func isRelatedToSelected(idx: Int) -> Bool {
        guard let sel = selectedIndex, sel != idx else { return false }
        let selRow = sel / 9, selCol = sel % 9
        let row = idx / 9, col = idx % 9
        let sameRow = row == selRow
        let sameCol = col == selCol
        let sameBox = (row / 3 == selRow / 3) && (col / 3 == selCol / 3)
        return sameRow || sameCol || sameBox
    }

    private func isSameValueAsSelected(idx: Int) -> Bool {
        guard let sel = selectedIndex, sel != idx else { return false }
        let selVal = cells[sel].value
        guard selVal != 0 else { return false }
        return cells[idx].value == selVal
    }

    private func selectedCountForNumber(_ n: Int) -> Int {
        cells.filter { $0.value == n }.count
    }

    // MARK: - Utility

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview {
    SudokuViewV2()
        .preferredColorScheme(.dark)
}

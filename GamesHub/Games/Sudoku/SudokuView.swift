import SwiftUI

// MARK: - Models

struct SudokuPuzzle {
    let grid: [[Int]]    // 0 = empty
    let solution: [[Int]]
}

struct SudokuCell: Identifiable {
    let id: Int
    var value: Int       // 0 = empty
    var isGiven: Bool
    var isInvalid: Bool = false
}

// MARK: - Game State

class SudokuGameState: ObservableObject {
    @Published var cells: [SudokuCell] = []
    @Published var selectedIndex: Int? = nil
    @Published var mistakes: Int = 0
    @Published var elapsedSeconds: Int = 0
    @Published var isComplete: Bool = false
    @Published var showValidationResult: Bool = false
    @Published var validationPassed: Bool = false

    private var solution: [[Int]] = []
    private var timer: Timer?
    private var currentPuzzleIndex: Int = 0

    static let puzzles: [SudokuPuzzle] = [
        // Puzzle 1
        SudokuPuzzle(
            grid: [
                [5,3,0,0,7,0,0,0,0],
                [6,0,0,1,9,5,0,0,0],
                [0,9,8,0,0,0,0,6,0],
                [8,0,0,0,6,0,0,0,3],
                [4,0,0,8,0,3,0,0,1],
                [7,0,0,0,2,0,0,0,6],
                [0,6,0,0,0,0,2,8,0],
                [0,0,0,4,1,9,0,0,5],
                [0,0,0,0,8,0,0,7,9]
            ],
            solution: [
                [5,3,4,6,7,8,9,1,2],
                [6,7,2,1,9,5,3,4,8],
                [1,9,8,3,4,2,5,6,7],
                [8,5,9,7,6,1,4,2,3],
                [4,2,6,8,5,3,7,9,1],
                [7,1,3,9,2,4,8,5,6],
                [9,6,1,5,3,7,2,8,4],
                [2,8,7,4,1,9,6,3,5],
                [3,4,5,2,8,6,1,7,9]
            ]
        ),
        // Puzzle 2
        SudokuPuzzle(
            grid: [
                [0,0,0,2,6,0,7,0,1],
                [6,8,0,0,7,0,0,9,0],
                [1,9,0,0,0,4,5,0,0],
                [8,2,0,1,0,0,0,4,0],
                [0,0,4,6,0,2,9,0,0],
                [0,5,0,0,0,3,0,2,8],
                [0,0,9,3,0,0,0,7,4],
                [0,4,0,0,5,0,0,3,6],
                [7,0,3,0,1,8,0,0,0]
            ],
            solution: [
                [4,3,5,2,6,9,7,8,1],
                [6,8,2,5,7,1,4,9,3],
                [1,9,7,8,3,4,5,6,2],
                [8,2,6,1,9,5,3,4,7],
                [3,7,4,6,8,2,9,1,5],
                [9,5,1,7,4,3,6,2,8],
                [5,1,9,3,2,6,8,7,4],
                [2,4,8,9,5,7,1,3,6],
                [7,6,3,4,1,8,2,5,9]
            ]
        ),
        // Puzzle 3
        SudokuPuzzle(
            grid: [
                [0,2,0,6,0,8,0,0,0],
                [5,8,0,0,0,9,7,0,0],
                [0,0,0,0,4,0,0,0,0],
                [3,7,0,0,0,0,5,0,0],
                [6,0,0,0,0,0,0,0,4],
                [0,0,8,0,0,0,0,1,3],
                [0,0,0,0,2,0,0,0,0],
                [0,0,9,8,0,0,0,3,6],
                [0,0,0,3,0,6,0,9,0]
            ],
            solution: [
                [1,2,3,6,7,8,9,4,5],
                [5,8,4,2,3,9,7,6,1],
                [9,6,7,1,4,5,3,2,8],
                [3,7,2,4,6,1,5,8,9],
                [6,9,1,5,8,3,2,7,4],
                [4,5,8,7,9,2,6,1,3],
                [8,3,6,9,2,4,1,5,7],
                [2,1,9,8,5,7,4,3,6],
                [7,4,5,3,1,6,8,9,2]
            ]
        )
    ]

    init() {
        loadPuzzle(index: 0)
        startTimer()
    }

    func loadPuzzle(index: Int) {
        currentPuzzleIndex = index
        let puzzle = SudokuGameState.puzzles[index]
        solution = puzzle.solution
        cells = []
        for row in 0..<9 {
            for col in 0..<9 {
                let val = puzzle.grid[row][col]
                let id = row * 9 + col
                cells.append(SudokuCell(id: id, value: val, isGiven: val != 0))
            }
        }
        selectedIndex = nil
        mistakes = 0
        elapsedSeconds = 0
        isComplete = false
        showValidationResult = false
        validationPassed = false
    }

    func restart() {
        stopTimer()
        let nextIndex = Int.random(in: 0..<SudokuGameState.puzzles.count)
        loadPuzzle(index: nextIndex)
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isComplete else { return }
            self.elapsedSeconds += 1
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func selectCell(index: Int) {
        let cell = cells[index]
        if !cell.isGiven {
            selectedIndex = index
        }
    }

    func enterNumber(_ number: Int) {
        guard let idx = selectedIndex, !cells[idx].isGiven else { return }
        let oldValue = cells[idx].value
        cells[idx].value = number
        cells[idx].isInvalid = false

        // Track mistakes: if user places a number that doesn't match solution
        let row = idx / 9
        let col = idx % 9
        if number != 0 && number != solution[row][col] {
            if oldValue != number {
                mistakes += 1
            }
        }

        validateBoard()
    }

    func clearCell() {
        guard let idx = selectedIndex, !cells[idx].isGiven else { return }
        cells[idx].value = 0
        cells[idx].isInvalid = false
        validateBoard()
    }

    func validateBoard() {
        // Mark invalid cells
        for i in 0..<81 {
            cells[i].isInvalid = false
        }
        for i in 0..<81 {
            guard cells[i].value != 0 else { continue }
            let row = i / 9
            let col = i % 9
            let val = cells[i].value
            var conflict = false
            // Check row
            for c in 0..<9 {
                let j = row * 9 + c
                if j != i && cells[j].value == val {
                    conflict = true
                    cells[j].isInvalid = true
                }
            }
            // Check col
            for r in 0..<9 {
                let j = r * 9 + col
                if j != i && cells[j].value == val {
                    conflict = true
                    cells[j].isInvalid = true
                }
            }
            // Check 3x3 box
            let boxRow = (row / 3) * 3
            let boxCol = (col / 3) * 3
            for dr in 0..<3 {
                for dc in 0..<3 {
                    let j = (boxRow + dr) * 9 + (boxCol + dc)
                    if j != i && cells[j].value == val {
                        conflict = true
                        cells[j].isInvalid = true
                    }
                }
            }
            if conflict {
                cells[i].isInvalid = true
            }
        }
    }

    func checkBoard() {
        validateBoard()
        // Check if all cells are filled and none are invalid
        let allFilled = cells.allSatisfy { $0.value != 0 }
        let noInvalid = cells.allSatisfy { !$0.isInvalid }
        if allFilled && noInvalid {
            validationPassed = true
            isComplete = true
            stopTimer()
        } else {
            validationPassed = false
        }
        showValidationResult = true
    }

    var formattedTime: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    deinit {
        timer?.invalidate()
    }
}

// MARK: - Main View

struct SudokuView: View {
    @StateObject private var gameState = SudokuGameState()

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                SudokuHeaderView(
                    time: gameState.formattedTime,
                    mistakes: gameState.mistakes
                )

                // Grid
                SudokuGridView(gameState: gameState)

                // Number picker
                SudokuNumberPickerView(gameState: gameState)

                // Action buttons
                SudokuActionButtonsView(gameState: gameState)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Completion overlay
            if gameState.showValidationResult {
                SudokuResultOverlayView(
                    passed: gameState.validationPassed,
                    time: gameState.formattedTime,
                    onDismiss: { gameState.showValidationResult = false },
                    onRestart: { gameState.restart() }
                )
            }
        }
    }
}

// MARK: - Header

struct SudokuHeaderView: View {
    let time: String
    let mistakes: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SUDOKU")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.primary)
            }
            Spacer()
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text(time)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                    Text("TIME")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                VStack(spacing: 2) {
                    Text("\(mistakes)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(mistakes > 0 ? .red : .primary)
                    Text("MISTAKES")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Grid

struct SudokuGridView: View {
    @ObservedObject var gameState: SudokuGameState

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / 9

            ZStack {
                // Cells
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                let idx = row * 9 + col
                                SudokuCellView(
                                    cell: gameState.cells[idx],
                                    isSelected: gameState.selectedIndex == idx,
                                    isHighlighted: isHighlighted(index: idx),
                                    isSameNumber: isSameNumber(index: idx),
                                    cellSize: cellSize
                                )
                                .onTapGesture {
                                    gameState.selectCell(index: idx)
                                }
                            }
                        }
                    }
                }
                .background(Color(.systemGray5))

                // Grid lines overlay
                SudokuGridLinesView(size: size, cellSize: cellSize)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color(.systemGray3), radius: 4, x: 2, y: 2)
            .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    func isHighlighted(index: Int) -> Bool {
        guard let sel = gameState.selectedIndex else { return false }
        if sel == index { return false }
        let selRow = sel / 9
        let selCol = sel % 9
        let curRow = index / 9
        let curCol = index % 9
        if selRow == curRow || selCol == curCol { return true }
        let selBoxRow = selRow / 3
        let selBoxCol = selCol / 3
        let curBoxRow = curRow / 3
        let curBoxCol = curCol / 3
        return selBoxRow == curBoxRow && selBoxCol == curBoxCol
    }

    func isSameNumber(index: Int) -> Bool {
        guard let sel = gameState.selectedIndex,
              sel != index else { return false }
        let selVal = gameState.cells[sel].value
        let curVal = gameState.cells[index].value
        return selVal != 0 && selVal == curVal
    }
}

struct SudokuCellView: View {
    let cell: SudokuCell
    let isSelected: Bool
    let isHighlighted: Bool
    let isSameNumber: Bool
    let cellSize: CGFloat

    var backgroundColor: Color {
        if isSelected {
            return Color.blue.opacity(0.35)
        } else if cell.isInvalid {
            return Color.red.opacity(0.15)
        } else if isSameNumber {
            return Color.blue.opacity(0.18)
        } else if isHighlighted {
            return Color.blue.opacity(0.08)
        } else {
            return Color(.systemGray6)
        }
    }

    var textColor: Color {
        if cell.isInvalid {
            return .red
        } else if cell.isGiven {
            return .primary
        } else {
            return .blue
        }
    }

    var body: some View {
        ZStack {
            backgroundColor
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.52, weight: cell.isGiven ? .bold : .semibold))
                    .foregroundColor(textColor)
            }
        }
        .frame(width: cellSize, height: cellSize)
    }
}

struct SudokuGridLinesView: View {
    let size: CGFloat
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, _ in
            // Thin lines for cell boundaries
            for i in 1..<9 {
                let x = cellSize * CGFloat(i)
                let y = cellSize * CGFloat(i)

                var thinPath = Path()
                thinPath.move(to: CGPoint(x: x, y: 0))
                thinPath.addLine(to: CGPoint(x: x, y: size))
                context.stroke(thinPath, with: .color(Color(.systemGray3)), lineWidth: 0.5)

                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: size, y: y))
                context.stroke(hPath, with: .color(Color(.systemGray3)), lineWidth: 0.5)
            }

            // Thick lines for 3x3 box boundaries
            for i in [3, 6] {
                let x = cellSize * CGFloat(i)
                let y = cellSize * CGFloat(i)

                var thickVPath = Path()
                thickVPath.move(to: CGPoint(x: x, y: 0))
                thickVPath.addLine(to: CGPoint(x: x, y: size))
                context.stroke(thickVPath, with: .color(Color(.systemGray)), lineWidth: 2.0)

                var thickHPath = Path()
                thickHPath.move(to: CGPoint(x: 0, y: y))
                thickHPath.addLine(to: CGPoint(x: size, y: y))
                context.stroke(thickHPath, with: .color(Color(.systemGray)), lineWidth: 2.0)
            }

            // Border
            var borderPath = Path(CGRect(x: 0, y: 0, width: size, height: size))
            context.stroke(borderPath, with: .color(Color(.systemGray)), lineWidth: 2.0)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }
}

// MARK: - Number Picker

struct SudokuNumberPickerView: View {
    @ObservedObject var gameState: SudokuGameState

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { number in
                Button(action: {
                    gameState.enterNumber(number)
                }) {
                    Text("\(number)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                        .shadow(color: Color(.systemGray4), radius: 3, x: 2, y: 2)
                }
                .disabled(gameState.selectedIndex == nil)
                .opacity(gameState.selectedIndex == nil ? 0.5 : 1.0)
            }

            // Clear button
            Button(action: {
                gameState.clearCell()
            }) {
                Image(systemName: "delete.left")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(width: 40, height: 48)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                    .shadow(color: Color(.systemGray4), radius: 3, x: 2, y: 2)
            }
            .disabled(gameState.selectedIndex == nil)
            .opacity(gameState.selectedIndex == nil ? 0.5 : 1.0)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Action Buttons

struct SudokuActionButtonsView: View {
    @ObservedObject var gameState: SudokuGameState

    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                gameState.restart()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Restart")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .white.opacity(0.8), radius: 4, x: -3, y: -3)
                .shadow(color: Color(.systemGray4), radius: 4, x: 3, y: 3)
            }

            Button(action: {
                gameState.checkBoard()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Check")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.blue)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.blue.opacity(0.4), radius: 4, x: 0, y: 4)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Result Overlay

struct SudokuResultOverlayView: View {
    let passed: Bool
    let time: String
    let onDismiss: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                Text(passed ? "Puzzle Solved!" : "Keep Going!")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(passed ? .green : .orange)

                if passed {
                    VStack(spacing: 6) {
                        Text("Time: \(time)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Congratulations!")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Some cells have errors or are empty.\nFix them and try again!")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    if passed {
                        Button(action: onRestart) {
                            Text("New Puzzle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 130, height: 44)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button(action: onDismiss) {
                            Text("Continue")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 130, height: 44)
                                .background(Color.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button(action: onRestart) {
                            Text("New Puzzle")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 130, height: 44)
                                .background(Color(.systemGray5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
            .padding(28)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
            .padding(.horizontal, 32)
        }
    }
}

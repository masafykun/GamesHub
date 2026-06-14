import SwiftUI

// MARK: - Models

// MARK: - Puzzle Bank (3 hardcoded puzzles)

private let sudokuPuzzleBank: [SudokuPuzzle] = [
    // Puzzle 0
    SudokuPuzzle(
        grid: [
            [5,3,0, 0,7,0, 0,0,0],
            [6,0,0, 1,9,5, 0,0,0],
            [0,9,8, 0,0,0, 0,6,0],
            [8,0,0, 0,6,0, 0,0,3],
            [4,0,0, 8,0,3, 0,0,1],
            [7,0,0, 0,2,0, 0,0,6],
            [0,6,0, 0,0,0, 2,8,0],
            [0,0,0, 4,1,9, 0,0,5],
            [0,0,0, 0,8,0, 0,7,9]
        ],
        solution: [
            [5,3,4, 6,7,8, 9,1,2],
            [6,7,2, 1,9,5, 3,4,8],
            [1,9,8, 3,4,2, 5,6,7],
            [8,5,9, 7,6,1, 4,2,3],
            [4,2,6, 8,5,3, 7,9,1],
            [7,1,3, 9,2,4, 8,5,6],
            [9,6,1, 5,3,7, 2,8,4],
            [2,8,7, 4,1,9, 6,3,5],
            [3,4,5, 2,8,6, 1,7,9]
        ]
    ),
    // Puzzle 1
    SudokuPuzzle(
        grid: [
            [0,0,0, 2,6,0, 7,0,1],
            [6,8,0, 0,7,0, 0,9,0],
            [1,9,0, 0,0,4, 5,0,0],
            [8,2,0, 1,0,0, 0,4,0],
            [0,0,4, 6,0,2, 9,0,0],
            [0,5,0, 0,0,3, 0,2,8],
            [0,0,9, 3,0,0, 0,7,4],
            [0,4,0, 0,5,0, 0,3,6],
            [7,0,3, 0,1,8, 0,0,0]
        ],
        solution: [
            [4,3,5, 2,6,9, 7,8,1],
            [6,8,2, 5,7,1, 4,9,3],
            [1,9,7, 8,3,4, 5,6,2],
            [8,2,6, 1,9,5, 3,4,7],
            [3,7,4, 6,8,2, 9,1,5],
            [9,5,1, 7,4,3, 6,2,8],
            [5,1,9, 3,2,6, 8,7,4],
            [2,4,8, 9,5,7, 1,3,6],
            [7,6,3, 4,1,8, 2,5,9]
        ]
    ),
    // Puzzle 2
    SudokuPuzzle(
        grid: [
            [0,0,0, 6,0,0, 4,0,0],
            [7,0,0, 0,0,3, 6,0,0],
            [0,0,0, 0,9,1, 0,8,0],
            [0,0,0, 0,0,0, 0,0,0],
            [0,5,0, 1,8,0, 0,0,3],
            [0,0,0, 3,0,6, 0,4,5],
            [0,4,0, 2,0,0, 0,6,0],
            [9,0,3, 0,0,0, 0,0,0],
            [0,2,0, 0,0,0, 1,0,0]
        ],
        solution: [
            [5,8,1, 6,7,2, 4,3,9],
            [7,9,4, 8,5,3, 6,1,2],
            [3,6,2, 4,9,1, 5,8,7],
            [4,3,8, 5,2,7, 9,6,1],
            [2,5,6, 1,8,4, 7,9,3],
            [1,7,9, 3,6,6, 8,4,5],
            [8,4,5, 2,1,9, 3,6,7],
            [9,1,3, 7,4,6, 2,5,8],
            [6,2,7, 9,3,5, 1,7,4]
        ]
    )
]

// MARK: - LCG Random Helper

private struct SudokuLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(bitPattern: Int64(seed))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        let n = UInt64(range.count)
        return range.lowerBound + Int(next() % n)
    }
}

// MARK: - Main View

struct SudokuViewV3: View {
    // Seed management
    @State var seedInt: Int = 1

    // Board state: 81 cells
    @State private var cells: [SudokuCell] = []
    @State private var solution: [Int] = []

    // Interaction
    @State private var selectedIndex: Int? = nil
    @State private var mistakesCount: Int = 0

    // Timer
    @State private var elapsedSeconds: Int = 0
    @State private var timerActive: Bool = false
    @State private var timer: Foundation.Timer? = nil

    // Completion
    @State private var showingWin: Bool = false

    // Number picker selection
    @State private var hoveredNumber: Int? = nil

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            VStack(spacing: 16) {
                headerView
                seedView
                boardView
                numberPickerView
                controlsView
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if showingWin {
                winOverlay
            }
        }
        .onAppear {
            startGame()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SUDOKU")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text("Mistakes: \(mistakesCount)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(mistakesCount > 0 ? .red : .secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString(elapsedSeconds))
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                Text("TIME")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .neumorphicCard()
    }

    private var seedView: some View {
        Text("SEED: #\(seedInt)")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(.blue)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .neumorphicCard()
    }

    private var boardView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let cellSize = size / 9
            ZStack(alignment: .topLeading) {
                // Cells grid
                ForEach(0..<81, id: \.self) { idx in
                    let row = idx / 9
                    let col = idx % 9
                    let cell = cells[idx]
                    cellView(cell: cell, idx: idx, cellSize: cellSize)
                        .position(
                            x: CGFloat(col) * cellSize + cellSize / 2,
                            y: CGFloat(row) * cellSize + cellSize / 2
                        )
                }
                // Grid lines
                Canvas { context, canvasSize in
                    let cSize = canvasSize.width / 9
                    // thin lines
                    for i in 1..<9 {
                        let isThick = (i % 3 == 0)
                        let lineWidth: CGFloat = isThick ? 2.5 : 0.8
                        let color = isThick
                            ? Color(.systemGray2)
                            : Color(.systemGray4)
                        // vertical
                        let vPath = Path { p in
                            p.move(to: CGPoint(x: CGFloat(i) * cSize, y: 0))
                            p.addLine(to: CGPoint(x: CGFloat(i) * cSize, y: canvasSize.height))
                        }
                        context.stroke(vPath, with: .color(color), lineWidth: lineWidth)
                        // horizontal
                        let hPath = Path { p in
                            p.move(to: CGPoint(x: 0, y: CGFloat(i) * cSize))
                            p.addLine(to: CGPoint(x: canvasSize.width, y: CGFloat(i) * cSize))
                        }
                        context.stroke(hPath, with: .color(color), lineWidth: lineWidth)
                    }
                    // outer border
                    let border = Path(CGRect(origin: .zero, size: canvasSize))
                    context.stroke(border, with: .color(Color(.systemGray2)), lineWidth: 2.5)
                }
                .allowsHitTesting(false)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding(4)
        .neumorphicCard(radius: 12)
    }

    @ViewBuilder
    private func cellView(cell: SudokuCell, idx: Int, cellSize: CGFloat) -> some View {
        let isSelected = selectedIndex == idx
        let row = idx / 9
        let col = idx % 9
        let isSameBox = selectedIndex.map { si in
            (si / 9) / 3 == row / 3 && (si % 9) / 3 == col / 3
        } ?? false
        let isSameRowCol = selectedIndex.map { si in
            si / 9 == row || si % 9 == col
        } ?? false
        let isSameValue = selectedIndex.map { si in
            let selVal = cells[si].value
            return selVal != 0 && selVal == cell.value
        } ?? false

        let bgColor: Color = {
            if isSelected { return Color.blue.opacity(0.25) }
            if isSameValue { return Color.blue.opacity(0.12) }
            if isSameRowCol || isSameBox { return Color(.systemGray5) }
            return Color(.systemGray6)
        }()

        ZStack {
            bgColor
            if cell.value != 0 {
                Text("\(cell.value)")
                    .font(.system(size: cellSize * 0.48, weight: cell.isGiven ? .bold : .medium, design: .rounded))
                    .foregroundColor(
                        cell.isInvalid ? .red :
                        cell.isGiven ? .primary :
                        Color.blue
                    )
            }
        }
        .frame(width: cellSize - 1, height: cellSize - 1)
        .contentShape(Rectangle())
        .onTapGesture {
            handleCellTap(idx: idx)
        }
    }

    private var numberPickerView: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { num in
                Button(action: { enterNumber(num) }) {
                    Text("\(num)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .neumorphicCard(radius: 10)
            }
            // Erase button
            Button(action: { eraseSelected() }) {
                Image(systemName: "delete.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .neumorphicCard(radius: 10)
        }
        .padding(.horizontal, 4)
    }

    private var controlsView: some View {
        HStack(spacing: 12) {
            Button(action: checkBoard) {
                Label("Check", systemImage: "checkmark.circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .neumorphicCard(radius: 12)

            Button(action: restartGame) {
                Label("Restart", systemImage: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .neumorphicCard(radius: 12)
        }
    }

    private var winOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 20) {
                Text("Solved!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(timeString(elapsedSeconds))
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                Text("Mistakes: \(mistakesCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(mistakesCount > 0 ? .red : .green)
                Button(action: restartGame) {
                    Text("Play Again")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(32)
            .neumorphicCard(radius: 20)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        stopTimer()
        showingWin = false
        selectedIndex = nil
        mistakesCount = 0
        elapsedSeconds = 0

        // Use LCG to pick puzzle and determine revealed cells
        var lcg = SudokuLCG(seed: seedInt)

        // Pick puzzle from bank
        let puzzleIdx = Int(lcg.next() % UInt64(sudokuPuzzleBank.count))
        let puzzle = sudokuPuzzleBank[puzzleIdx]
        solution = puzzle.solution.flatMap { $0 }

        // Determine which cells to reveal using seed
        // Start with the puzzle grid, then use LCG to optionally reveal/hide cells
        var revealed = puzzle.grid.flatMap { $0 }

        // Use LCG to shuffle which non-zero clue cells remain visible
        // Keep roughly 25-35 cells shown (vary by seed)
        let targetRevealed = 25 + Int(lcg.next() % 11) // 25-35

        // Collect indices where clue is non-zero
        var clueIndices = (0..<81).filter { revealed[$0] != 0 }
        // Shuffle clue indices using LCG Fisher-Yates
        for i in stride(from: clueIndices.count - 1, through: 1, by: -1) {
            let j = lcg.nextInt(in: 0..<(i + 1))
            clueIndices.swapAt(i, j)
        }

        // Hide extra cells beyond targetRevealed
        let toHide = max(0, clueIndices.count - targetRevealed)
        for k in 0..<toHide {
            revealed[clueIndices[k]] = 0
        }

        // Build cells array
        cells = (0..<81).map { idx in
            SudokuCell(
                id: idx,
                value: revealed[idx],
                isGiven: revealed[idx] != 0,
                isInvalid: false
            )
        }

        validateAll()
        startTimer()
    }

    private func restartGame() {
        seedInt += 1
        startGame()
    }

    private func handleCellTap(idx: Int) {
        if selectedIndex == idx {
            selectedIndex = nil
        } else {
            selectedIndex = idx
        }
    }

    private func enterNumber(_ num: Int) {
        guard let idx = selectedIndex else { return }
        guard !cells[idx].isGiven else { return }

        let prev = cells[idx].value
        cells[idx].value = num
        validateAll()

        // Count mistake: placed a wrong number
        if cells[idx].isInvalid || num != solution[idx] {
            if prev != num {
                mistakesCount += 1
            }
        }

        // Check win
        if isBoardComplete() {
            stopTimer()
            showingWin = true
        }
    }

    private func eraseSelected() {
        guard let idx = selectedIndex else { return }
        guard !cells[idx].isGiven else { return }
        cells[idx].value = 0
        validateAll()
    }

    private func checkBoard() {
        validateAll()
        // Count additional mistakes for any filled wrong cell
        for idx in 0..<81 {
            if !cells[idx].isGiven && cells[idx].value != 0 && cells[idx].value != solution[idx] {
                // Already counted, just highlight
            }
        }
        if isBoardComplete() {
            stopTimer()
            showingWin = true
        }
    }

    private func validateAll() {
        for idx in 0..<81 {
            cells[idx].isInvalid = false
        }
        for idx in 0..<81 {
            let val = cells[idx].value
            if val == 0 { continue }
            let row = idx / 9
            let col = idx % 9
            var conflict = false
            // Check row
            for c in 0..<9 {
                let other = row * 9 + c
                if other != idx && cells[other].value == val {
                    conflict = true
                    break
                }
            }
            // Check col
            if !conflict {
                for r in 0..<9 {
                    let other = r * 9 + col
                    if other != idx && cells[other].value == val {
                        conflict = true
                        break
                    }
                }
            }
            // Check 3x3 box
            if !conflict {
                let boxRow = (row / 3) * 3
                let boxCol = (col / 3) * 3
                outer: for r in boxRow..<(boxRow + 3) {
                    for c in boxCol..<(boxCol + 3) {
                        let other = r * 9 + c
                        if other != idx && cells[other].value == val {
                            conflict = true
                            break outer
                        }
                    }
                }
            }
            if conflict {
                cells[idx].isInvalid = true
            }
        }
    }

    private func isBoardComplete() -> Bool {
        for idx in 0..<81 {
            if cells[idx].value == 0 || cells[idx].isInvalid { return false }
            if cells[idx].value != solution[idx] { return false }
        }
        return true
    }

    // MARK: - Timer

    private func startTimer() {
        timerActive = true
        timer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.timerActive {
                self.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timerActive = false
        timer?.invalidate()
        timer = nil
    }

    private func timeString(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Preview

#Preview {
    SudokuViewV3()
}

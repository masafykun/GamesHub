import SwiftUI

// MARK: - Models

enum PiCrPhase { case start, playing, solved }

struct PiCrPuzzle {
    let name: String
    let solution: [[Bool]]  // 8x8
    let rowClues: [[Int]]
    let colClues: [[Int]]
}

enum PiCrCellState { case empty, filled, marked }

// MARK: - Preset Puzzles

private let piCrPuzzles: [PiCrPuzzle] = {
    // Heart
    let heart: [[Bool]] = [
        [false,true,true,false,false,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,true,true,false,false],
        [false,false,false,true,true,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]
    // Smiley
    let smiley: [[Bool]] = [
        [false,false,true,true,true,true,false,false],
        [false,true,false,false,false,false,true,false],
        [true,false,true,false,false,true,false,true],
        [true,false,false,false,false,false,false,true],
        [true,false,true,false,false,true,false,true],
        [true,false,false,true,true,false,false,true],
        [false,true,false,false,false,false,true,false],
        [false,false,true,true,true,true,false,false]
    ]
    // House
    let house: [[Bool]] = [
        [false,false,false,true,true,false,false,false],
        [false,false,true,true,true,true,false,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,false,false,false,false,true,true],
        [true,true,false,false,false,false,true,true],
        [true,true,false,false,false,false,true,true]
    ]

    func clues(from grid: [[Bool]]) -> (rows: [[Int]], cols: [[Int]]) {
        var rows: [[Int]] = []
        for r in 0..<8 {
            var runs: [Int] = []
            var count = 0
            for c in 0..<8 {
                if grid[r][c] { count += 1 }
                else if count > 0 { runs.append(count); count = 0 }
            }
            if count > 0 { runs.append(count) }
            rows.append(runs.isEmpty ? [0] : runs)
        }
        var cols: [[Int]] = []
        for c in 0..<8 {
            var runs: [Int] = []
            var count = 0
            for r in 0..<8 {
                if grid[r][c] { count += 1 }
                else if count > 0 { runs.append(count); count = 0 }
            }
            if count > 0 { runs.append(count) }
            cols.append(runs.isEmpty ? [0] : runs)
        }
        return (rows, cols)
    }

    let hClues = clues(from: heart)
    let sClues = clues(from: smiley)
    let houseClues = clues(from: house)

    return [
        PiCrPuzzle(name: "Heart", solution: heart, rowClues: hClues.rows, colClues: hClues.cols),
        PiCrPuzzle(name: "Smiley", solution: smiley, rowClues: sClues.rows, colClues: sClues.cols),
        PiCrPuzzle(name: "House", solution: house, rowClues: houseClues.rows, colClues: houseClues.cols)
    ]
}()

// MARK: - Main View

struct PicCrossView: View {
    @State private var phase: PiCrPhase = .start
    @State private var puzzleIndex: Int = 0
    @State private var grid: [[PiCrCellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var mistakes: Int = 0

    private var puzzle: PiCrPuzzle { piCrPuzzles[puzzleIndex] }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .solved: solvedScreen
            }
        }
    }

    // MARK: Start Screen
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("PicCross").font(.largeTitle.bold())
            Text("Solve nonogram puzzles!").foregroundColor(.secondary)
            VStack(spacing: 12) {
                ForEach(piCrPuzzles.indices, id: \.self) { i in
                    Button(piCrPuzzles[i].name) {
                        puzzleIndex = i
                        resetGrid()
                        phase = .playing
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
            }
        }
    }

    // MARK: Game Screen
    var gameScreen: some View {
        VStack(spacing: 8) {
            Text(puzzle.name).font(.title2.bold()).padding(.top)
            Text("Mistakes: \(mistakes)").foregroundColor(.red).font(.subheadline)
            HStack(alignment: .bottom, spacing: 2) {
                // Row clues column
                VStack(spacing: 2) {
                    Color.clear.frame(width: 48, height: 48)
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(puzzle.rowClues[r], id: \.self) { n in
                                Text("\(n)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(rowSatisfied(r) ? .gray : .primary)
                            }
                        }
                        .frame(width: 48, height: 36)
                    }
                }
                VStack(spacing: 2) {
                    // Column clues
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { c in
                            VStack(spacing: 1) {
                                ForEach(puzzle.colClues[c], id: \.self) { n in
                                    Text("\(n)")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundColor(colSatisfied(c) ? .gray : .primary)
                                }
                            }
                            .frame(width: 36, height: 48)
                        }
                    }
                    // Grid
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { c in
                                cellView(r: r, c: c)
                            }
                        }
                    }
                }
            }
            .padding()
            Button("Back") { phase = .start }
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
    }

    @ViewBuilder
    func cellView(r: Int, c: Int) -> some View {
        let state = grid[r][c]
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(state == .filled ? Color.indigo : Color(.secondarySystemBackground))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4), lineWidth: 1))
            if state == .marked {
                Text("✕").font(.system(size: 14, weight: .bold)).foregroundColor(.red)
            }
        }
        .frame(width: 36, height: 36)
        .onTapGesture { tapCell(r: r, c: c) }
    }

    // MARK: Solved Screen
    var solvedScreen: some View {
        VStack(spacing: 24) {
            Text("SOLVED!").font(.system(size: 48, weight: .heavy)).foregroundColor(.indigo)
            Text(puzzle.name).font(.title2)
            Text("Mistakes: \(mistakes)").foregroundColor(.red)
            Button("Play Again") { phase = .start }
                .buttonStyle(.borderedProminent).tint(.indigo)
        }
    }

    // MARK: Logic
    func tapCell(r: Int, c: Int) {
        switch grid[r][c] {
        case .empty: grid[r][c] = .filled
        case .filled: grid[r][c] = .marked
        case .marked: grid[r][c] = .empty
        }
        checkSolved()
    }

    func resetGrid() {
        grid = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        mistakes = 0
    }

    func checkSolved() {
        var correct = true
        for r in 0..<8 {
            for c in 0..<8 {
                let wantFilled = puzzle.solution[r][c]
                let isFilled = grid[r][c] == .filled
                if wantFilled != isFilled { correct = false }
            }
        }
        if correct { phase = .solved }
    }

    func rowSatisfied(_ row: Int) -> Bool {
        var runs: [Int] = []
        var count = 0
        for c in 0..<8 {
            if grid[row][c] == .filled { count += 1 }
            else if count > 0 { runs.append(count); count = 0 }
        }
        if count > 0 { runs.append(count) }
        return runs == puzzle.rowClues[row] || (runs.isEmpty && puzzle.rowClues[row] == [0])
    }

    func colSatisfied(_ col: Int) -> Bool {
        var runs: [Int] = []
        var count = 0
        for r in 0..<8 {
            if grid[r][col] == .filled { count += 1 }
            else if count > 0 { runs.append(count); count = 0 }
        }
        if count > 0 { runs.append(count) }
        return runs == puzzle.colClues[col] || (runs.isEmpty && puzzle.colClues[col] == [0])
    }
}

#Preview { PicCrossView() }

import SwiftUI

// MARK: - Models

enum NgrmCellState { case empty, filled, marked }

struct NgrmPuzzle {
    let name: String
    let grid: [[Bool]]
    var rowClues: [[Int]] { grid.map { row in cluesFrom(row) } }
    var colClues: [[Int]] {
        (0..<8).map { c in cluesFrom(grid.map { $0[c] }) }
    }
    private func cluesFrom(_ line: [Bool]) -> [Int] {
        var result: [Int] = []
        var count = 0
        for cell in line {
            if cell { count += 1 } else if count > 0 { result.append(count); count = 0 }
        }
        if count > 0 { result.append(count) }
        return result.isEmpty ? [0] : result
    }
}

enum NgrmGamePhase { case start, playing, success }

// MARK: - Puzzles

let ngrmPuzzles: [NgrmPuzzle] = [
    NgrmPuzzle(name: "Heart", grid: [
        [false,true,true,false,false,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,true,true,false,false],
        [false,false,false,true,true,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NgrmPuzzle(name: "Arrow", grid: [
        [false,false,false,true,false,false,false,false],
        [false,false,true,true,false,false,false,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,false,false,false,false],
        [false,false,false,true,false,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NgrmPuzzle(name: "House", grid: [
        [false,false,false,true,true,false,false,false],
        [false,false,true,true,true,true,false,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,false,true,true,false,true,true],
        [true,true,false,true,true,false,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true]
    ])
]

// MARK: - Main View

struct NonogramView: View {
    @State private var phase: NgrmGamePhase = .start
    @State private var puzzleIndex = 0
    @State private var cells: [[NgrmCellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var errors = 0

    var puzzle: NgrmPuzzle { ngrmPuzzles[puzzleIndex] }

    var completionPercent: Int {
        var correct = 0
        for r in 0..<8 { for c in 0..<8 {
            if puzzle.grid[r][c] && cells[r][c] == .filled { correct += 1 }
            if !puzzle.grid[r][c] && cells[r][c] != .filled { correct += 1 }
        }}
        return correct * 100 / 64
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .success: successScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Nonogram").font(.largeTitle.bold())
            Text("Fill the grid using the number clues.\nTap = fill black  •  Long-press = mark X")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            VStack(spacing: 12) {
                ForEach(0..<ngrmPuzzles.count, id: \.self) { i in
                    Button(ngrmPuzzles[i].name) {
                        puzzleIndex = i
                        cells = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
                        errors = 0
                        phase = .playing
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Menu") { phase = .start }
                Spacer()
                Text(puzzle.name).font(.headline)
                Spacer()
                Text("\(completionPercent)%").monospacedDigit()
            }.padding(.horizontal)

            HStack(spacing: 2) {
                // Row clues column
                VStack(spacing: 2) {
                    Spacer().frame(height: 40)
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(puzzle.rowClues[r], id: \.self) { n in
                                Text("\(n)").font(.caption2).frame(minWidth: 10)
                            }
                        }
                        .frame(height: 36)
                    }
                }
                // Grid + col clues
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { c in
                            VStack(spacing: 1) {
                                ForEach(puzzle.colClues[c], id: \.self) { n in
                                    Text("\(n)").font(.caption2)
                                }
                            }
                            .frame(width: 36, height: 40)
                        }
                    }
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { c in
                                NgrmCellView(state: cells[r][c])
                                    .onTapGesture { toggleFill(r: r, c: c) }
                                    .onLongPressGesture { toggleMark(r: r, c: c) }
                            }
                        }
                    }
                }
            }

            if errors > 0 {
                Text("Errors: \(errors)").foregroundStyle(.red).font(.caption)
            }

            Button("Check Solution") { checkSolution() }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
        }
        .padding()
    }

    var successScreen: some View {
        VStack(spacing: 24) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.green)
            Text(puzzle.name).font(.title2)
            Text("Errors: \(errors)").foregroundStyle(errors == 0 ? .green : .orange)
            Button("Play Again") { phase = .start }
                .buttonStyle(.borderedProminent)
        }
    }

    func toggleFill(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .filled ? .empty : .filled
        if cells[r][c] == .filled && !puzzle.grid[r][c] { errors += 1 }
        if completionPercent == 100 { phase = .success }
    }

    func toggleMark(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .marked ? .empty : .marked
    }

    func checkSolution() {
        for r in 0..<8 { for c in 0..<8 {
            if puzzle.grid[r][c] && cells[r][c] != .filled { return }
        }}
        phase = .success
    }
}

struct NgrmCellView: View {
    let state: NgrmCellState
    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(state == .filled ? Color.black : Color(.systemGray5))
            .overlay {
                if state == .marked {
                    Text("×").font(.system(size: 18, weight: .bold)).foregroundStyle(.red)
                }
            }
            .frame(width: 36, height: 36)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(.systemGray3), lineWidth: 0.5))
    }
}

#Preview { NonogramView() }

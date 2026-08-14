import SwiftUI

// MARK: - Models ()

enum NonogramCellState { case empty, filled, marked }
enum NonogramPhase { case start, playing, success }

struct NonogramPuzzle {
    let name: String
    let grid: [[Bool]]
    var rowClues: [[Int]] { grid.map { cluesFrom($0) } }
    var colClues: [[Int]] { (0..<8).map { c in cluesFrom(grid.map { $0[c] }) } }
    private func cluesFrom(_ line: [Bool]) -> [Int] {
        var res: [Int] = []; var n = 0
        for v in line { if v { n += 1 } else if n > 0 { res.append(n); n = 0 } }
        if n > 0 { res.append(n) }
        return res.isEmpty ? [0] : res
    }
}

// MARK: - Puzzles ()

private let nonogramPuzzles: [NonogramPuzzle] = [
    NonogramPuzzle(name: "Heart", grid: [
        [false,true,true,false,false,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,true,true,false,false],
        [false,false,false,true,true,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NonogramPuzzle(name: "Diamond", grid: [
        [false,false,false,true,true,false,false,false],
        [false,false,true,true,true,true,false,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,true,true,false,false],
        [false,false,false,true,true,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NonogramPuzzle(name: "Star", grid: [
        [false,false,false,true,true,false,false,false],
        [false,true,false,true,true,false,true,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [false,false,true,true,true,true,false,false],
        [false,true,false,true,true,false,true,false],
        [true,false,false,true,true,false,false,true],
        [false,false,false,false,false,false,false,false]
    ])
]

// MARK: - Adaptive Difficulty

private struct NonogramDifficultySettings {
    var mistakePenalty: Bool = false
    var timeLimit: Int? = nil
    var level: Int = 1
}

// MARK: - Main View 

struct NonogramView: View {
    @State private var phase: NonogramPhase = .start
    @State private var puzzleIndex = 0
    @State private var cells: [[NonogramCellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var errors = 0
    @State private var recentResults: [Bool] = []
    @State private var difficulty: NonogramDifficultySettings = NonogramDifficultySettings()
    @State private var timeElapsed: Int = 0
    @State private var timer: Timer? = nil

    var puzzle: NonogramPuzzle { nonogramPuzzles[puzzleIndex] }

    var completionPercent: Int {
        var correct = 0
        for r in 0..<8 { for c in 0..<8 {
            if puzzle.grid[r][c] && cells[r][c] == .filled { correct += 1 }
            if !puzzle.grid[r][c] && cells[r][c] != .filled { correct += 1 }
        }}
        return correct * 100 / 64
    }

    var difficultyLabel: String {
        switch difficulty.level {
        case 1: return "Easy"
        case 2: return "Medium"
        default: return "Hard"
        }
    }

    var glassCard: some ShapeStyle { .ultraThinMaterial }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.45, green: 0.2, blue: 0.9),
                                    Color(red: 0.1, green: 0.5, blue: 0.95)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .success: successScreen
            }
        }
    }

    // MARK: Start Screen

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Nonogram").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Difficulty: \(difficultyLabel)")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
            VStack(spacing: 12) {
                ForEach(0..<nonogramPuzzles.count, id: \.self) { i in
                    Button(nonogramPuzzles[i].name) {
                        puzzleIndex = i
                        startGame()
                    }
                    .padding(.vertical, 8).padding(.horizontal, 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4), lineWidth: 1))
                    .foregroundStyle(.white)
                }
            }
        }
        .padding(28)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: Game Screen

    var gameScreen: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Button("Menu") { stopTimer(); phase = .start }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                    Spacer()
                    VStack(spacing: 2) {
                        Text(puzzle.name).font(.headline).foregroundStyle(.white)
                        Text("\(difficultyLabel)  •  \(completionPercent)%")
                            .font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(timeString).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                }.padding(.horizontal)

                // Grid
                VStack(spacing: 2) {
                    // Column clues
                    HStack(spacing: 2) {
                        Spacer().frame(width: 60)
                        ForEach(0..<8, id: \.self) { c in
                            VStack(spacing: 1) {
                                ForEach(puzzle.colClues[c], id: \.self) { n in
                                    Text("\(n)").font(.caption2).foregroundStyle(.white)
                                }
                            }.frame(width: 36, height: 44)
                        }
                    }
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            HStack(spacing: 2) {
                                ForEach(puzzle.rowClues[r], id: \.self) { n in
                                    Text("\(n)").font(.caption2).foregroundStyle(.white)
                                }
                            }.frame(width: 60, alignment: .trailing)
                            ForEach(0..<8, id: \.self) { c in
                                NonogramCellView(state: cells[r][c])
                                    .onTapGesture { tapCell(r: r, c: c) }
                                    .onLongPressGesture { markCell(r: r, c: c) }
                            }
                        }
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

                if errors > 0 {
                    Text("Errors: \(errors)").foregroundStyle(.red.opacity(0.9))
                        .font(.subheadline)
                }

                Button("Check") { checkSolution() }
                    .padding(.vertical, 10).padding(.horizontal, 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    .foregroundStyle(.white)
            }
            .padding(.vertical)
        }
    }

    // MARK: Success Screen

    var successScreen: some View {
        VStack(spacing: 20) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.white)
            Text(puzzle.name).font(.title2).foregroundStyle(.white.opacity(0.8))
            Text("Time: \(timeString)").foregroundStyle(.white.opacity(0.8))
            Text("Errors: \(errors)").foregroundStyle(errors == 0 ? .green : .orange)
            Text("Difficulty: \(difficultyLabel)").foregroundStyle(.white.opacity(0.7))
                .font(.caption)
            Button("Play Again") { stopTimer(); phase = .start }
                .padding(.vertical, 10).padding(.horizontal, 32)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundStyle(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    var timeString: String {
        let m = timeElapsed / 60, s = timeElapsed % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: Logic

    func startGame() {
        cells = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        errors = 0
        timeElapsed = 0
        phase = .playing
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in timeElapsed += 1 }
    }

    func stopTimer() { timer?.invalidate(); timer = nil }

    func tapCell(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .filled ? .empty : .filled
        if cells[r][c] == .filled && !puzzle.grid[r][c] { errors += 1 }
        if completionPercent == 100 { finishGame(success: true) }
    }

    func markCell(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .marked ? .empty : .marked
    }

    func checkSolution() {
        for r in 0..<8 { for c in 0..<8 {
            if puzzle.grid[r][c] && cells[r][c] != .filled { return }
        }}
        finishGame(success: true)
    }

    func finishGame(success: Bool) {
        stopTimer()
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        // Adaptive difficulty: if last 5 results have >4 trues, increase difficulty
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficulty.level = min(difficulty.level + 1, 3)
            difficulty.mistakePenalty = difficulty.level >= 2
        }
        if success { phase = .success }
    }
}

// MARK: - Cell View 

struct NonogramCellView: View {
    let state: NonogramCellState
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(state == .filled ? Color.white : Color.white.opacity(0.15))
            .overlay {
                if state == .marked {
                    Text("×").font(.system(size: 18, weight: .bold)).foregroundStyle(.red.opacity(0.9))
                }
            }
            .frame(width: 36, height: 36)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.2), lineWidth: 0.5))
    }
}

#Preview { NonogramView() }

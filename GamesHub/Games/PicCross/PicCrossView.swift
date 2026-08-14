import SwiftUI

// MARK: - Models

enum PicCrossPhase { case start, playing, solved }

struct PicCrossPuzzle {
    let name: String
    let solution: [[Bool]]
    let rowClues: [[Int]]
    let colClues: [[Int]]
}

enum PicCrossCellState { case empty, filled, marked }

// MARK: - Puzzle Data

private func piCrBuildPuzzles() -> [PicCrossPuzzle] {
    func clues(from grid: [[Bool]]) -> (rows: [[Int]], cols: [[Int]]) {
        var rows: [[Int]] = []
        for r in 0..<8 {
            var runs: [Int] = []; var count = 0
            for c in 0..<8 { if grid[r][c] { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
            if count > 0 { runs.append(count) }
            rows.append(runs.isEmpty ? [0] : runs)
        }
        var cols: [[Int]] = []
        for c in 0..<8 {
            var runs: [Int] = []; var count = 0
            for r in 0..<8 { if grid[r][c] { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
            if count > 0 { runs.append(count) }
            cols.append(runs.isEmpty ? [0] : runs)
        }
        return (rows, cols)
    }

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
    let hc = clues(from: heart); let sc = clues(from: smiley); let hoc = clues(from: house)
    return [
        PicCrossPuzzle(name: "Heart", solution: heart, rowClues: hc.rows, colClues: hc.cols),
        PicCrossPuzzle(name: "Smiley", solution: smiley, rowClues: sc.rows, colClues: sc.cols),
        PicCrossPuzzle(name: "House", solution: house, rowClues: hoc.rows, colClues: hoc.cols)
    ]
}

private let piCrPuzzles: [PicCrossPuzzle] = piCrBuildPuzzles()

// MARK: - Adaptive Difficulty

private struct PicCrossDifficulty {
    var level: Int = 1  // 1=easy(show hints), 2=medium, 3=hard(time limit)
    var timeLimit: Double = 300
}

// MARK: - Main View

struct PicCrossView: View {
    @State private var phase: PicCrossPhase = .start
    @State private var puzzleIndex: Int = 0
    @State private var grid: [[PicCrossCellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var mistakes: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficulty: PicCrossDifficulty = PicCrossDifficulty()
    @State private var timeElapsed: Double = 0
    @State private var timer: Timer? = nil
    @State private var hintsRemaining: Int = 3

    private var puzzle: PicCrossPuzzle { piCrPuzzles[puzzleIndex] }
    private var difficultyLabel: String {
        switch difficulty.level { case 1: return "Easy"; case 2: return "Medium"; default: return "Hard" }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.35, green: 0.2, blue: 0.7), Color(red: 0.1, green: 0.4, blue: 0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
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
            Text("PicCross").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Difficulty: \(difficultyLabel)").foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(.ultraThinMaterial).clipShape(Capsule())
            VStack(spacing: 12) {
                ForEach(piCrPuzzles.indices, id: \.self) { i in
                    Button(piCrPuzzles[i].name) {
                        puzzleIndex = i
                        startGame()
                    }
                    .font(.headline).foregroundColor(.white)
                    .frame(width: 160, height: 48)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                }
            }
            if !recentResults.isEmpty {
                Text("Recent: \(recentResults.suffix(5).filter{$0}.count)/\(min(recentResults.count,5)) solved")
                    .font(.caption).foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: Game Screen
    var gameScreen: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(puzzle.name).font(.title2.bold()).foregroundColor(.white)
                    Text("Mistakes: \(mistakes)").font(.caption).foregroundColor(.red.opacity(0.9))
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(difficultyLabel).font(.caption).foregroundColor(.white.opacity(0.7))
                    if difficulty.level >= 3 {
                        Text(timeString(timeElapsed)).font(.caption.monospaced()).foregroundColor(timeElapsed > difficulty.timeLimit * 0.8 ? .red : .white)
                    }
                }
            }
            .padding(.horizontal).padding(.top)

            // Grid Panel
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 2) {
                    // Row clues
                    VStack(spacing: 2) {
                        Color.clear.frame(width: 44, height: 40)
                        ForEach(0..<8, id: \.self) { r in
                            HStack(spacing: 2) {
                                ForEach(puzzle.rowClues[r], id: \.self) { n in
                                    Text("\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundColor(rowSatisfied(r) ? .white.opacity(0.4) : .white)
                                }
                            }
                            .frame(width: 44, height: 34)
                        }
                    }
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { c in
                                VStack(spacing: 1) {
                                    ForEach(puzzle.colClues[c], id: \.self) { n in
                                        Text("\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(colSatisfied(c) ? .white.opacity(0.4) : .white)
                                    }
                                }
                                .frame(width: 34, height: 40)
                            }
                        }
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
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Hint button (easy mode)
            if difficulty.level == 1 && hintsRemaining > 0 {
                Button("Hint (\(hintsRemaining))") { useHint() }
                    .font(.subheadline).foregroundColor(.white)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }

            Button("Quit") { endRound(solved: false); phase = .start }
                .foregroundColor(.white.opacity(0.6)).padding(.bottom)
        }
    }

    @ViewBuilder
    func cellView(r: Int, c: Int) -> some View {
        let state = grid[r][c]
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(state == .filled ? Color.white.opacity(0.9) : Color.white.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.3), lineWidth: 1))
            if state == .marked {
                Text("✕").font(.system(size: 12, weight: .bold)).foregroundColor(.red.opacity(0.8))
            }
        }
        .frame(width: 34, height: 34)
        .onTapGesture { tapCell(r: r, c: c) }
    }

    // MARK: Solved Screen
    var solvedScreen: some View {
        VStack(spacing: 20) {
            Text("SOLVED!").font(.system(size: 48, weight: .heavy)).foregroundColor(.white)
            Text(puzzle.name).font(.title2).foregroundColor(.white.opacity(0.9))
            Text("Mistakes: \(mistakes)").foregroundColor(.red.opacity(0.9))
            if difficulty.level >= 3 {
                Text("Time: \(timeString(timeElapsed))").foregroundColor(.white.opacity(0.7))
            }
            Text("Difficulty: \(difficultyLabel)").foregroundColor(.white.opacity(0.7))
            Button("Play Again") { phase = .start }
                .font(.headline).foregroundColor(.white)
                .frame(width: 160, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: Logic
    func startGame() {
        grid = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        mistakes = 0
        hintsRemaining = difficulty.level == 1 ? 3 : 0
        timeElapsed = 0
        timer?.invalidate()
        if difficulty.level >= 3 {
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                timeElapsed += 1
                if timeElapsed >= difficulty.timeLimit { endRound(solved: false); phase = .start }
            }
        }
        phase = .playing
    }

    func endRound(solved: Bool) {
        timer?.invalidate(); timer = nil
        recentResults.append(solved)
        if recentResults.count > 10 { recentResults = Array(recentResults.suffix(10)) }
        let last5 = recentResults.suffix(5)
        if last5.count == 5 && last5.filter({ $0 }).count > 4 {
            if difficulty.level < 3 {
                difficulty.level += 1
                difficulty.timeLimit = max(60, difficulty.timeLimit * 0.8)
            }
        }
    }

    func tapCell(r: Int, c: Int) {
        switch grid[r][c] {
        case .empty: grid[r][c] = .filled
        case .filled: grid[r][c] = .marked
        case .marked: grid[r][c] = .empty
        }
        if grid[r][c] == .filled && !puzzle.solution[r][c] { mistakes += 1 }
        if checkSolved() { endRound(solved: true); phase = .solved }
    }

    func useHint() {
        guard hintsRemaining > 0 else { return }
        for r in 0..<8 {
            for c in 0..<8 where puzzle.solution[r][c] && grid[r][c] != .filled {
                grid[r][c] = .filled
                hintsRemaining -= 1
                if checkSolved() { endRound(solved: true); phase = .solved }
                return
            }
        }
    }

    func checkSolved() -> Bool {
        for r in 0..<8 { for c in 0..<8 where puzzle.solution[r][c] != (grid[r][c] == .filled) { return false } }
        return true
    }

    func rowSatisfied(_ row: Int) -> Bool {
        var runs: [Int] = []; var count = 0
        for c in 0..<8 { if grid[row][c] == .filled { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
        if count > 0 { runs.append(count) }
        return runs == puzzle.rowClues[row] || (runs.isEmpty && puzzle.rowClues[row] == [0])
    }

    func colSatisfied(_ col: Int) -> Bool {
        var runs: [Int] = []; var count = 0
        for r in 0..<8 { if grid[r][col] == .filled { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
        if count > 0 { runs.append(count) }
        return runs == puzzle.colClues[col] || (runs.isEmpty && puzzle.colClues[col] == [0])
    }

    func timeString(_ t: Double) -> String {
        let s = Int(t); return String(format: "%d:%02d", s/60, s%60)
    }
}

#Preview { PicCrossView() }

import SwiftUI

// MARK: - LCG Seeded RNG

struct PiCrLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

enum PiCrV3Phase { case start, playing, solved }
enum PiCrV3CellState { case empty, filled, marked }

struct PiCrV3Puzzle {
    let name: String
    let solution: [[Bool]]
    let rowClues: [[Int]]
    let colClues: [[Int]]
}

// MARK: - Procedural Puzzle Generator

private func piCrV3GeneratePuzzle(seed: Int) -> PiCrV3Puzzle {
    var rng = PiCrLCG(seed: seed)

    // Generate a random 8x8 binary grid with ~50% fill rate
    var grid: [[Bool]] = []
    for _ in 0..<8 {
        var row: [Bool] = []
        for _ in 0..<8 { row.append(rng.nextDouble() < 0.5) }
        grid.append(row)
    }

    // Compute clues
    var rowClues: [[Int]] = []
    for r in 0..<8 {
        var runs: [Int] = []; var count = 0
        for c in 0..<8 { if grid[r][c] { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
        if count > 0 { runs.append(count) }
        rowClues.append(runs.isEmpty ? [0] : runs)
    }
    var colClues: [[Int]] = []
    for c in 0..<8 {
        var runs: [Int] = []; var count = 0
        for r in 0..<8 { if grid[r][c] { count += 1 } else if count > 0 { runs.append(count); count = 0 } }
        if count > 0 { runs.append(count) }
        colClues.append(runs.isEmpty ? [0] : runs)
    }

    let adjectives = ["Cosmic", "Pixel", "Shadow", "Neon", "Crystal", "Vapor", "Lunar", "Solar"]
    let nouns = ["Wave", "Storm", "Drift", "Bloom", "Echo", "Pulse", "Veil", "Spark"]
    let name = adjectives[rng.nextInt(adjectives.count)] + " " + nouns[rng.nextInt(nouns.count)]

    return PiCrV3Puzzle(name: name, solution: grid, rowClues: rowClues, colClues: colClues)
}

// MARK: - Preset Base Puzzles

private func piCrV3BuildPresets() -> [PiCrV3Puzzle] {
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
    let hc = clues(from: heart); let hoc = clues(from: house)
    return [
        PiCrV3Puzzle(name: "Heart", solution: heart, rowClues: hc.rows, colClues: hc.cols),
        PiCrV3Puzzle(name: "House", solution: house, rowClues: hoc.rows, colClues: hoc.cols)
    ]
}

private let piCrV3Presets: [PiCrV3Puzzle] = piCrV3BuildPresets()

// MARK: - Main View

struct PicCrossViewV3: View {
    @State private var phase: PiCrV3Phase = .start
    @State private var grid: [[PiCrV3CellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var mistakes: Int = 0
    @State private var seedInt: Int = 1
    @State private var puzzle: PiCrV3Puzzle = piCrV3Presets[0]
    @State private var useRandom: Bool = false
    @State private var completedSeeds: [Int] = []

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
            Text("PicCross").font(.largeTitle.bold()).foregroundColor(.primary)
            Text("Nonogram Puzzles").foregroundColor(.secondary)

            VStack(spacing: 12) {
                Text("Classic Puzzles").font(.headline).foregroundColor(.secondary)
                ForEach(piCrV3Presets.indices, id: \.self) { i in
                    Button(piCrV3Presets[i].name) {
                        puzzle = piCrV3Presets[i]
                        useRandom = false
                        resetAndPlay()
                    }
                    .font(.headline).foregroundColor(.primary)
                    .frame(width: 180, height: 44)
                    .neumorphicCard(radius: 12)
                }
            }

            Divider().padding(.horizontal, 40)

            VStack(spacing: 12) {
                Text("Random Puzzle").font(.headline).foregroundColor(.secondary)
                Button("SEED: #\(seedInt)") {
                    puzzle = piCrV3GeneratePuzzle(seed: seedInt)
                    useRandom = true
                    resetAndPlay()
                }
                .font(.system(.headline, design: .monospaced)).foregroundColor(.primary)
                .frame(width: 180, height: 44)
                .neumorphicCard(radius: 12)

                HStack(spacing: 12) {
                    Button("-") { if seedInt > 1 { seedInt -= 1 } }
                        .frame(width: 44, height: 44).neumorphicCard(radius: 10)
                    Button("+") { seedInt += 1 }
                        .frame(width: 44, height: 44).neumorphicCard(radius: 10)
                }
            }

            if !completedSeeds.isEmpty {
                Text("Completed seeds: \(completedSeeds.map{"#\($0)"}.joined(separator: ", "))")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }

    // MARK: Game Screen
    var gameScreen: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(puzzle.name).font(.title3.bold())
                    Text("Mistakes: \(mistakes)").font(.caption).foregroundColor(.red)
                }
                Spacer()
                if useRandom {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, design: .monospaced)).foregroundColor(.gray)
                }
            }
            .padding(.horizontal).padding(.top)

            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 2) {
                    // Row clue labels
                    VStack(spacing: 2) {
                        Color.clear.frame(width: 46, height: 42)
                        ForEach(0..<8, id: \.self) { r in
                            HStack(spacing: 2) {
                                ForEach(puzzle.rowClues[r], id: \.self) { n in
                                    Text("\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                                        .foregroundColor(rowSatisfied(r) ? Color(.systemGray3) : .primary)
                                }
                            }
                            .frame(width: 46, height: 34)
                        }
                    }
                    VStack(spacing: 2) {
                        // Column clue labels
                        HStack(spacing: 2) {
                            ForEach(0..<8, id: \.self) { c in
                                VStack(spacing: 1) {
                                    ForEach(puzzle.colClues[c], id: \.self) { n in
                                        Text("\(n)").font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundColor(colSatisfied(c) ? Color(.systemGray3) : .primary)
                                    }
                                }
                                .frame(width: 34, height: 42)
                            }
                        }
                        // Grid cells
                        ForEach(0..<8, id: \.self) { r in
                            HStack(spacing: 2) {
                                ForEach(0..<8, id: \.self) { c in
                                    cellView(r: r, c: c)
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
            .neumorphicCard(radius: 20)
            .padding(.horizontal)

            // Seed display during play (always visible)
            if useRandom {
                HStack {
                    Spacer()
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 10, design: .monospaced)).foregroundColor(.gray)
                    Spacer()
                }
            }

            Button("Quit") { phase = .start }
                .foregroundColor(.secondary).padding(.bottom)
        }
    }

    @ViewBuilder
    func cellView(r: Int, c: Int) -> some View {
        let state = grid[r][c]
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(state == .filled ? Color(.systemGray2) : Color(.systemGray6))
                .shadow(color: state == .filled ? .black.opacity(0.15) : .white.opacity(0.8), radius: state == .filled ? 2 : 3, x: state == .filled ? 1 : -2, y: state == .filled ? 1 : -2)
                .shadow(color: state == .filled ? .white.opacity(0.1) : .black.opacity(0.15), radius: state == .filled ? 2 : 3, x: state == .filled ? -1 : 2, y: state == .filled ? -1 : 2)
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(.systemGray4).opacity(0.5), lineWidth: 0.5))
            if state == .marked {
                Text("✕").font(.system(size: 12, weight: .bold)).foregroundColor(Color(.systemGray))
            }
        }
        .frame(width: 34, height: 34)
        .onTapGesture { tapCell(r: r, c: c) }
    }

    // MARK: Solved Screen
    var solvedScreen: some View {
        VStack(spacing: 20) {
            Text("SOLVED!").font(.system(size: 44, weight: .heavy)).foregroundColor(.primary)
            Text(puzzle.name).font(.title2).foregroundColor(.secondary)
            Text("Mistakes: \(mistakes)").foregroundColor(.red)
            if useRandom {
                Text("SEED: #\(seedInt)").font(.system(size: 13, design: .monospaced)).foregroundColor(.gray)
            }
            Button("Next Puzzle") {
                if useRandom { seedInt += 1 }
                phase = .start
            }
            .font(.headline).foregroundColor(.primary)
            .frame(width: 160, height: 48)
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: Logic
    func resetAndPlay() {
        grid = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        mistakes = 0
        phase = .playing
    }

    func tapCell(r: Int, c: Int) {
        switch grid[r][c] {
        case .empty: grid[r][c] = .filled
        case .filled: grid[r][c] = .marked
        case .marked: grid[r][c] = .empty
        }
        if grid[r][c] == .filled && !puzzle.solution[r][c] { mistakes += 1 }
        if checkSolved() {
            if useRandom && !completedSeeds.contains(seedInt) { completedSeeds.append(seedInt) }
            phase = .solved
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
}

#Preview { PicCrossViewV3() }

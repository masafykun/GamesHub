import SwiftUI

// MARK: - LCG Random

struct NgrmLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models (V3)

enum NgrmV3CellState { case empty, filled, marked }
enum NgrmV3Phase { case start, playing, success }

struct NgrmV3Puzzle {
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

// MARK: - Procedural Puzzle Generation

private func ngrmGeneratePuzzle(seed: Int) -> NgrmV3Puzzle {
    var rng = NgrmLCG(seed: seed)
    // Pick a base shape index and name from pool
    let names = ["Blob", "Wave", "Cross", "Spiral", "Dots", "Zigzag", "Frame", "Lines"]
    let name = names[rng.nextInt(names.count)]
    // Generate grid using shape templates modulated by seed
    let shapeType = rng.nextInt(5)
    var grid = Array(repeating: Array(repeating: false, count: 8), count: 8)

    switch shapeType {
    case 0: // Blob: fill random cells with ~55% density
        for r in 0..<8 { for c in 0..<8 {
            grid[r][c] = rng.nextDouble() < 0.55
        }}
    case 1: // Horizontal stripes
        let stripeCount = 2 + rng.nextInt(3)
        for i in 0..<stripeCount {
            let row = rng.nextInt(8)
            let len = 3 + rng.nextInt(5)
            let start = rng.nextInt(max(1, 8 - len))
            for c in start..<min(8, start + len) { grid[row][c] = true }
        }
    case 2: // Cross / plus shape
        let cr = 2 + rng.nextInt(4); let cc = 2 + rng.nextInt(4)
        let arm = 2 + rng.nextInt(2)
        for i in max(0, cr-arm)...min(7, cr+arm) { grid[i][cc] = true }
        for j in max(0, cc-arm)...min(7, cc+arm) { grid[cr][j] = true }
    case 3: // Frame border
        let inset = rng.nextInt(2)
        for r in inset..<(8-inset) { for c in inset..<(8-inset) {
            if r == inset || r == 7-inset || c == inset || c == 7-inset { grid[r][c] = true }
        }}
    default: // Diagonal + random accents
        for i in 0..<8 { grid[i][i] = true; grid[i][7-i] = true }
        for _ in 0..<6 {
            let r = rng.nextInt(8); let c = rng.nextInt(8)
            grid[r][c] = true
        }
    }
    return NgrmV3Puzzle(name: name, grid: grid)
}

// MARK: - Preset Puzzles (fallback for seed 0)

private let v3PresetPuzzles: [NgrmV3Puzzle] = [
    NgrmV3Puzzle(name: "Heart", grid: [
        [false,true,true,false,false,true,true,false],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,true,true,false,false],
        [false,false,false,true,true,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NgrmV3Puzzle(name: "Arrow", grid: [
        [false,false,false,true,false,false,false,false],
        [false,false,true,true,false,false,false,false],
        [false,true,true,true,true,true,true,false],
        [true,true,true,true,true,true,true,true],
        [false,true,true,true,true,true,true,false],
        [false,false,true,true,false,false,false,false],
        [false,false,false,true,false,false,false,false],
        [false,false,false,false,false,false,false,false]
    ]),
    NgrmV3Puzzle(name: "House", grid: [
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

// MARK: - Main View V3

struct NonogramViewV3: View {
    @State private var phase: NgrmV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var puzzle: NgrmV3Puzzle = v3PresetPuzzles[0]
    @State private var cells: [[NgrmV3CellState]] = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
    @State private var errors = 0
    @State private var usePreset = true
    @State private var presetIndex = 0

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
            Color(.systemGray6).ignoresSafeArea()
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
            Text("Nonogram").font(.largeTitle.bold())
            Text("Neumorphic Edition").font(.subheadline).foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Text("Preset Puzzles").font(.headline)
                ForEach(0..<v3PresetPuzzles.count, id: \.self) { i in
                    Button(v3PresetPuzzles[i].name) {
                        presetIndex = i
                        usePreset = true
                        launchGame()
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 10).padding(.horizontal, 20)
                    .neumorphicCard(radius: 12)
                }
            }

            Divider()

            VStack(spacing: 12) {
                Text("Procedural").font(.headline)
                Button("Generate (SEED #\(seedInt))") {
                    usePreset = false
                    launchGame()
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 10).padding(.horizontal, 20)
                .neumorphicCard(radius: 12)
            }
        }
        .padding(28)
        .neumorphicCard(radius: 16)
        .padding()
    }

    // MARK: Game Screen

    var gameScreen: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button("Menu") { phase = .start }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .neumorphicCard(radius: 10)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(puzzle.name).font(.headline)
                        Text("\(completionPercent)%").monospacedDigit()
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Seed display
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .neumorphicCard(radius: 8)
                }.padding(.horizontal)

                // Nonogram grid
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Spacer().frame(width: 60)
                        ForEach(0..<8, id: \.self) { c in
                            VStack(spacing: 1) {
                                ForEach(puzzle.colClues[c], id: \.self) { n in
                                    Text("\(n)").font(.caption2).foregroundStyle(.primary)
                                }
                            }.frame(width: 36, height: 44)
                        }
                    }
                    ForEach(0..<8, id: \.self) { r in
                        HStack(spacing: 2) {
                            HStack(spacing: 2) {
                                ForEach(puzzle.rowClues[r], id: \.self) { n in
                                    Text("\(n)").font(.caption2)
                                }
                            }.frame(width: 60, alignment: .trailing)
                            ForEach(0..<8, id: \.self) { c in
                                NgrmV3CellView(state: cells[r][c])
                                    .onTapGesture { tapCell(r: r, c: c) }
                                    .onLongPressGesture { markCell(r: r, c: c) }
                            }
                        }
                    }
                }
                .padding(16)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)

                if errors > 0 {
                    Text("Errors: \(errors)").foregroundStyle(.red).font(.subheadline)
                }

                Button("Check Solution") { checkSolution() }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 10).padding(.horizontal, 32)
                    .neumorphicCard(radius: 14)
                    .padding(.bottom)
            }
            .padding(.vertical)
        }
    }

    // MARK: Success Screen

    var successScreen: some View {
        VStack(spacing: 20) {
            Text("Solved!").font(.largeTitle.bold()).foregroundStyle(.green)
            Text(puzzle.name).font(.title2)
            Text("Errors: \(errors)").foregroundStyle(errors == 0 ? .green : .orange)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Button("Next Puzzle") {
                seedInt += 1
                usePreset = false
                launchGame()
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 10).padding(.horizontal, 28)
            .neumorphicCard(radius: 14)
            Button("Menu") { phase = .start }
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(32)
        .neumorphicCard(radius: 16)
        .padding()
    }

    // MARK: Logic

    func launchGame() {
        cells = Array(repeating: Array(repeating: .empty, count: 8), count: 8)
        errors = 0
        if usePreset {
            puzzle = v3PresetPuzzles[presetIndex]
        } else {
            puzzle = ngrmGeneratePuzzle(seed: seedInt)
        }
        phase = .playing
    }

    func tapCell(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .filled ? .empty : .filled
        if cells[r][c] == .filled && !puzzle.grid[r][c] { errors += 1 }
        if completionPercent == 100 { phase = .success }
    }

    func markCell(r: Int, c: Int) {
        cells[r][c] = cells[r][c] == .marked ? .empty : .marked
    }

    func checkSolution() {
        for r in 0..<8 { for c in 0..<8 {
            if puzzle.grid[r][c] && cells[r][c] != .filled { return }
        }}
        phase = .success
    }
}

// MARK: - Cell View V3

struct NgrmV3CellView: View {
    let state: NgrmV3CellState
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(state == .filled ? 0 : 0.2), radius: state == .filled ? 0 : 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(state == .filled ? 0 : 0.8), radius: state == .filled ? 0 : 3, x: -2, y: -2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(state == .filled ? Color(.label) : Color.clear)
                )
            if state == .marked {
                Text("×").font(.system(size: 18, weight: .bold)).foregroundStyle(.red)
            }
        }
        .frame(width: 36, height: 36)
    }
}

#Preview { NonogramViewV3() }

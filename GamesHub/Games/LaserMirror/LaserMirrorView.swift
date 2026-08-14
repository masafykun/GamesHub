import SwiftUI

// MARK: - Models

enum LaserMirrorCellType: Int {
    case empty = 0
    case mirrorForward = 1  // /
    case mirrorBackward = 2 // \
}

struct LaserMirrorPuzzle {
    let starRow: Int
    let starCol: Int
    let preMirrors: [(row: Int, col: Int, type: LaserMirrorCellType)]
}

struct LaserMirrorPos: Hashable { let row: Int; let col: Int }

// MARK: - Laser trace

func computeLaserMirrorPath(cells: [[LaserMirrorCellType]], puzzle: LaserMirrorPuzzle) -> Set<LaserMirrorPos> {
    var visited = Set<LaserMirrorPos>()
    var row = 3; var col = 0
    var dr = 0; var dc = 1
    var steps = 0
    while col >= 0 && col < 7 && row >= 0 && row < 7 && steps < 100 {
        let pos = LaserMirrorPos(row: row, col: col)
        if visited.contains(pos) { break }
        visited.insert(pos)
        steps += 1
        let cell = cells[row][col]
        if cell == .mirrorForward { let t = -dc; dc = -dr; dr = t }
        else if cell == .mirrorBackward { let t = dc; dc = dr; dr = t }
        row += dr; col += dc
    }
    return visited
}

// MARK: - Main View

struct LaserMirrorView: View {
    @State private var phase: LaserMirrorPhase = .start
    @State private var cells = Array(repeating: Array(repeating: LaserMirrorCellType.empty, count: 7), count: 7)
    @State private var puzzleIndex = 0
    @State private var solved = false
    @State private var moveCount = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @AppStorage("laserMirrorBestMoves") private var bestMoves: Int = 0

    enum LaserMirrorPhase { case start, game, results }

    let puzzles: [LaserMirrorPuzzle] = [
        LaserMirrorPuzzle(starRow: 2, starCol: 5, preMirrors: [(1,1,.mirrorForward),(3,3,.mirrorBackward)]),
        LaserMirrorPuzzle(starRow: 5, starCol: 4, preMirrors: [(2,2,.mirrorForward),(4,1,.mirrorBackward),(1,4,.mirrorForward)]),
        LaserMirrorPuzzle(starRow: 0, starCol: 6, preMirrors: [(3,0,.mirrorForward),(0,3,.mirrorBackward)]),
        LaserMirrorPuzzle(starRow: 6, starCol: 2, preMirrors: [(1,1,.mirrorForward),(5,5,.mirrorBackward),(3,3,.mirrorForward),(4,2,.mirrorBackward)])
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.06, blue: 0.20), Color(red: 0.04, green: 0.16, blue: 0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .game: gameScreen
            case .results: resultsScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("LASER").font(.system(size: 52, weight: .black)).foregroundColor(.white)
                Text("MIRROR").font(.system(size: 52, weight: .black)).foregroundColor(.cyan)
            }
            Text("Reflect the laser to hit the star!").font(.subheadline).foregroundColor(.white.opacity(0.7))
            Button("START GAME") { startFresh() }
                .font(.headline.bold()).foregroundColor(.white).padding(.horizontal, 36).padding(.vertical, 14)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 32)
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                glassTag(label: "Puzzle \(puzzleIndex + 1)/\(puzzles.count)")
                Spacer()
                glassTag(label: "Moves: \(moveCount)")
                Spacer()
                glassTag(label: bestMoves > 0 ? "Best: \(bestMoves)" : "Aim for the star")
            }.padding(.horizontal)

            if solved {
                Text("SOLVED!").font(.system(size: 36, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .transition(.scale.combined(with: .opacity))
            }

            gridView
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .padding(.horizontal)

            if solved {
                Button(puzzleIndex + 1 < puzzles.count ? "NEXT PUZZLE" : "FINISH") {
                    recordResult(true)
                    if puzzleIndex + 1 < puzzles.count { loadPuzzle(puzzleIndex + 1) }
                    else {
                        if bestMoves == 0 || moveCount < bestMoves { bestMoves = moveCount }
                        phase = .results
                    }
                }
                .font(.headline.bold()).foregroundColor(.white).padding(.horizontal, 36).padding(.vertical, 12)
                .background(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
            }

            Button("RESTART PUZZLE") { loadPuzzle(puzzleIndex) }
                .font(.subheadline).foregroundColor(.white.opacity(0.6))
        }.padding(.vertical)
    }

    var resultsScreen: some View {
        VStack(spacing: 24) {
            Text("ALL DONE!").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            Text("Total moves: \(moveCount)").font(.title2).foregroundColor(.cyan)
            Text(bestMoves > 0 ? "Best run: \(bestMoves) moves" : "").font(.headline).foregroundColor(.white.opacity(0.7))
            Button("PLAY AGAIN") { startFresh() }
                .font(.headline.bold()).foregroundColor(.white).padding(.horizontal, 36).padding(.vertical, 14)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 32)
    }

    // MARK: - Grid

    var gridView: some View {
        let puzzle = puzzles[puzzleIndex]
        let laserPath = computeLaserMirrorPath(cells: cells, puzzle: puzzle)
        return VStack(spacing: 3) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 3) {
                    Image(systemName: row == 3 ? "dot.radiowaves.right" : "")
                        .foregroundColor(.red).font(.caption2).frame(width: 14)
                    ForEach(0..<7, id: \.self) { col in
                        cellView(row: row, col: col, puzzle: puzzle, laserPath: laserPath)
                    }
                }
            }
        }
    }

    func cellView(row: Int, col: Int, puzzle: LaserMirrorPuzzle, laserPath: Set<LaserMirrorPos>) -> some View {
        let isLocked = puzzle.preMirrors.contains { $0.row == row && $0.col == col }
        let isStar = puzzle.starRow == row && puzzle.starCol == col
        let isLit = laserPath.contains(LaserMirrorPos(row: row, col: col))
        let cell = cells[row][col]

        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isLit ? Color.red.opacity(0.3) : Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(isLit ? Color.red.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 1))
            if isStar {
                Text("★").font(.system(size: 20)).foregroundColor(isLit ? .yellow : Color.white.opacity(0.4))
            } else if cell == .mirrorForward {
                Text("/").font(.system(size: 20, weight: .bold)).foregroundColor(isLocked ? .cyan : .white)
            } else if cell == .mirrorBackward {
                Text("\\").font(.system(size: 20, weight: .bold)).foregroundColor(isLocked ? .cyan : .white)
            }
        }
        .frame(width: 42, height: 42)
        .onTapGesture { tapCell(row: row, col: col, isLocked: isLocked, isStar: isStar) }
    }

    // MARK: - Helpers

    func glassTag(label: String) -> some View {
        Text(label).font(.caption.bold()).foregroundColor(.white).padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial).clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func tapCell(row: Int, col: Int, isLocked: Bool, isStar: Bool) {
        guard !isLocked, !isStar, !solved else { return }
        let current = cells[row][col]
        cells[row][col] = current == .empty ? .mirrorForward : current == .mirrorForward ? .mirrorBackward : .empty
        moveCount += 1
        let path = computeLaserMirrorPath(cells: cells, puzzle: puzzles[puzzleIndex])
        let puzzle = puzzles[puzzleIndex]
        withAnimation { solved = path.contains(LaserMirrorPos(row: puzzle.starRow, col: puzzle.starCol)) }
    }

    func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
        }
    }

    func loadPuzzle(_ index: Int) {
        puzzleIndex = index
        solved = false
        cells = Array(repeating: Array(repeating: .empty, count: 7), count: 7)
        for m in puzzles[index].preMirrors { cells[m.row][m.col] = m.type }
    }

    func startFresh() {
        moveCount = 0
        recentResults = []
        difficultyMultiplier = 1.0
        loadPuzzle(0)
        phase = .game
    }
}

#Preview { LaserMirrorView() }

import SwiftUI

// MARK: - Models

enum LMrCellType: Int {
    case empty = 0
    case mirrorForward = 1  // /
    case mirrorBackward = 2 // \
}

struct LMrPuzzle {
    let starRow: Int
    let starCol: Int
    let preMirrors: [(row: Int, col: Int, type: LMrCellType)]
}

// MARK: - Main View

struct LaserMirrorView: View {
    @State private var phase: LMrPhase = .start
    @State private var cells = Array(repeating: Array(repeating: LMrCellType.empty, count: 7), count: 7)
    @State private var puzzleIndex = 0
    @State private var solved = false
    @State private var moveCount = 0

    enum LMrPhase { case start, game, results }

    let puzzles: [LMrPuzzle] = [
        LMrPuzzle(starRow: 2, starCol: 5, preMirrors: [(1,1,.mirrorForward),(3,3,.mirrorBackward)]),
        LMrPuzzle(starRow: 5, starCol: 4, preMirrors: [(2,2,.mirrorForward),(4,1,.mirrorBackward),(1,4,.mirrorForward)]),
        LMrPuzzle(starRow: 0, starCol: 6, preMirrors: [(3,0,.mirrorForward),(0,3,.mirrorBackward)]),
        LMrPuzzle(starRow: 6, starCol: 2, preMirrors: [(1,1,.mirrorForward),(5,5,.mirrorBackward),(3,3,.mirrorForward),(4,2,.mirrorBackward)])
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .game: gameScreen
            case .results: resultsScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("LASER\nMIRROR").font(.system(size: 44, weight: .black)).foregroundColor(.cyan).multilineTextAlignment(.center)
            Text("Reflect the laser\nto hit the star!").font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button("PLAY") { loadPuzzle(0) }
                .font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.cyan).clipShape(Capsule())
        }
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Puzzle \(puzzleIndex + 1)/\(puzzles.count)").font(.headline).foregroundColor(.gray)
                Spacer()
                Text("Moves: \(moveCount)").font(.headline).foregroundColor(.cyan)
            }.padding(.horizontal)

            if solved {
                Text("SOLVED!").font(.system(size: 32, weight: .black)).foregroundColor(.yellow)
                    .transition(.scale)
            }

            gridView

            if solved {
                Button(puzzleIndex + 1 < puzzles.count ? "NEXT PUZZLE" : "RESULTS") {
                    if puzzleIndex + 1 < puzzles.count { loadPuzzle(puzzleIndex + 1) }
                    else { phase = .results }
                }
                .font(.title3.bold()).foregroundColor(.black).padding(.horizontal, 32).padding(.vertical, 12)
                .background(Color.yellow).clipShape(Capsule())
            }

            Button("RESTART") { loadPuzzle(puzzleIndex) }
                .font(.subheadline).foregroundColor(.gray)
        }.padding()
    }

    var resultsScreen: some View {
        VStack(spacing: 24) {
            Text("ALL DONE!").font(.system(size: 40, weight: .black)).foregroundColor(.yellow)
            Text("Total moves: \(moveCount)").font(.title2).foregroundColor(.white)
            Button("PLAY AGAIN") { loadPuzzle(0); moveCount = 0 }
                .font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.cyan).clipShape(Capsule())
        }
    }

    var gridView: some View {
        let puzzle = puzzles[puzzleIndex]
        let laserPath = computeLaserPath(cells: cells, puzzle: puzzle)

        return VStack(spacing: 2) {
            ForEach(0..<7, id: \.self) { row in
                HStack(spacing: 2) {
                    if row == 3 {
                        Image(systemName: "dot.radiowaves.right").foregroundColor(.red).font(.caption)
                    } else {
                        Text(" ").font(.caption)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        cellView(row: row, col: col, puzzle: puzzle, laserPath: laserPath)
                    }
                }
            }
        }
    }

    func cellView(row: Int, col: Int, puzzle: LMrPuzzle, laserPath: Set<LMrPos>) -> some View {
        let isLocked = puzzle.preMirrors.contains { $0.row == row && $0.col == col }
        let isStar = puzzle.starRow == row && puzzle.starCol == col
        let isLit = laserPath.contains(LMrPos(row: row, col: col))
        let cell = cells[row][col]

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isLit ? Color.red.opacity(0.25) : Color.white.opacity(0.07))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.15), lineWidth: 1))
            if isStar {
                Text("★").font(.title2).foregroundColor(isLit ? .yellow : .gray)
            } else if cell == .mirrorForward {
                Text("/").font(.title2.bold()).foregroundColor(isLocked ? .cyan : .white)
            } else if cell == .mirrorBackward {
                Text("\\").font(.title2.bold()).foregroundColor(isLocked ? .cyan : .white)
            }
        }
        .frame(width: 44, height: 44)
        .onTapGesture { tapCell(row: row, col: col, isLocked: isLocked, isStar: isStar) }
    }

    func tapCell(row: Int, col: Int, isLocked: Bool, isStar: Bool) {
        guard !isLocked, !isStar, !solved else { return }
        let current = cells[row][col]
        cells[row][col] = current == .empty ? .mirrorForward : current == .mirrorForward ? .mirrorBackward : .empty
        moveCount += 1
        checkSolved()
    }

    func checkSolved() {
        let puzzle = puzzles[puzzleIndex]
        let path = computeLaserPath(cells: cells, puzzle: puzzle)
        solved = path.contains(LMrPos(row: puzzle.starRow, col: puzzle.starCol))
    }

    func loadPuzzle(_ index: Int) {
        puzzleIndex = index
        solved = false
        cells = Array(repeating: Array(repeating: .empty, count: 7), count: 7)
        for m in puzzles[index].preMirrors { cells[m.row][m.col] = m.type }
        phase = .game
    }
}

struct LMrPos: Hashable { let row: Int; let col: Int }

func computeLaserPath(cells: [[LMrCellType]], puzzle: LMrPuzzle) -> Set<LMrPos> {
    var visited = Set<LMrPos>()
    var row = 3; var col = 0
    var dr = 0; var dc = 1
    var steps = 0
    while col >= 0 && col < 7 && row >= 0 && row < 7 && steps < 100 {
        let pos = LMrPos(row: row, col: col)
        if visited.contains(pos) { break }
        visited.insert(pos)
        steps += 1
        let cell = cells[row][col]
        if cell == .mirrorForward {
            let newDr = -dc; let newDc = -dr; dr = newDr; dc = newDc
        } else if cell == .mirrorBackward {
            let newDr = dc; let newDc = dr; dr = newDr; dc = newDc
        }
        row += dr; col += dc
    }
    return visited
}

#Preview { LaserMirrorView() }

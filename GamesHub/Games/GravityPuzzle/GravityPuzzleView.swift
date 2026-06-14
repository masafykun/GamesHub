import SwiftUI

// MARK: - Models

enum GrPzDirection: CaseIterable {
    case up, down, left, right
    var arrow: String {
        switch self { case .up: return "↑"; case .down: return "↓"; case .left: return "←"; case .right: return "→" }
    }
}

struct GrPzLevel {
    let ballStart: (Int, Int)
    let starExit: (Int, Int)
    let walls: [(Int, Int)]
}

enum GrPzPhase { case start, playing, complete }

// MARK: - View

struct GravityPuzzleView: View {
    @State private var phase: GrPzPhase = .start
    @State private var currentLevel: Int = 0
    @State private var ballPos: (Int, Int) = (0, 0)
    @State private var moves: Int = 0
    @State private var gravity: GrPzDirection = .down
    @State private var levelComplete = false
    @State private var totalMoves: Int = 0

    let gridSize = 8

    let levels: [GrPzLevel] = [
        GrPzLevel(ballStart: (0,0), starExit: (7,7), walls: [(2,0),(2,1),(2,2),(5,4),(5,5),(5,6)]),
        GrPzLevel(ballStart: (0,7), starExit: (7,0), walls: [(3,3),(3,4),(3,5),(4,2),(4,3)]),
        GrPzLevel(ballStart: (3,0), starExit: (3,7), walls: [(1,2),(2,2),(4,2),(5,2),(3,4),(2,5),(4,5)]),
        GrPzLevel(ballStart: (0,3), starExit: (7,4), walls: [(2,1),(2,2),(2,3),(5,4),(5,5),(5,6),(3,6),(4,1)]),
        GrPzLevel(ballStart: (1,1), starExit: (6,6), walls: [(0,3),(1,3),(2,3),(3,3),(4,4),(5,4),(6,4),(7,4),(3,1),(3,2)])
    ]

    var currentLevelData: GrPzLevel { levels[currentLevel] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("GRAVITY\nPUZZLE").font(.system(size: 44, weight: .black, design: .rounded))
                .multilineTextAlignment(.center).foregroundColor(.white)
            Text("Slide the ball to the star!\nTap arrows to change gravity.").font(.body)
                .multilineTextAlignment(.center).foregroundColor(.gray)
            Button("START") {
                startGame()
            }
            .font(.headline).foregroundColor(.black)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.yellow).clipShape(Capsule())
        }
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(currentLevel + 1)/\(levels.count)").foregroundColor(.white).font(.headline)
                Spacer()
                Text("Moves: \(moves)").foregroundColor(.yellow).font(.headline)
            }.padding(.horizontal)

            // Grid
            VStack(spacing: 2) {
                ForEach(0..<gridSize, id: \.self) { row in
                    HStack(spacing: 2) {
                        ForEach(0..<gridSize, id: \.self) { col in
                            cellView(col: col, row: row)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color(white: 0.12))
            .cornerRadius(12)
            .padding(.horizontal)

            // Gravity arrows
            VStack(spacing: 8) {
                arrowButton(.up)
                HStack(spacing: 24) {
                    arrowButton(.left)
                    Text(gravity.arrow).font(.system(size: 28)).foregroundColor(.cyan)
                    arrowButton(.right)
                }
                arrowButton(.down)
            }
        }.padding(.vertical)
    }

    func cellView(col: Int, row: Int) -> some View {
        let isWall = currentLevelData.walls.contains(where: { $0.0 == col && $0.1 == row })
        let isBall = ballPos.0 == col && ballPos.1 == row
        let isStar = currentLevelData.starExit.0 == col && currentLevelData.starExit.1 == row
        return ZStack {
            Rectangle()
                .fill(isWall ? Color(white: 0.35) : Color(white: 0.18))
                .frame(width: 38, height: 38)
                .cornerRadius(4)
            if isBall { Circle().fill(Color.cyan).frame(width: 24, height: 24) }
            if isStar { Text("⭐").font(.system(size: 18)) }
        }
    }

    func arrowButton(_ dir: GrPzDirection) -> some View {
        Button(dir.arrow) {
            applyGravity(dir)
        }
        .font(.system(size: 28, weight: .bold))
        .foregroundColor(gravity == dir ? .yellow : .white)
        .frame(width: 52, height: 52)
        .background(Color(white: 0.2))
        .cornerRadius(10)
    }

    var completeScreen: some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 60))
            Text("COMPLETE!").font(.system(size: 36, weight: .black)).foregroundColor(.yellow)
            Text("Total Moves: \(totalMoves)").foregroundColor(.white).font(.title2)
            Button("PLAY AGAIN") { phase = .start; currentLevel = 0; totalMoves = 0 }
                .font(.headline).foregroundColor(.black)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .background(Color.yellow).clipShape(Capsule())
        }
    }

    func startGame() {
        currentLevel = 0; moves = 0; totalMoves = 0
        ballPos = currentLevelData.ballStart
        gravity = .down; phase = .playing
    }

    func applyGravity(_ dir: GrPzDirection) {
        gravity = dir
        var pos = ballPos
        while true {
            let next = nextPos(pos, dir: dir)
            guard next.0 >= 0, next.0 < gridSize, next.1 >= 0, next.1 < gridSize else { break }
            if currentLevelData.walls.contains(where: { $0.0 == next.0 && $0.1 == next.1 }) { break }
            pos = next
            if pos.0 == currentLevelData.starExit.0 && pos.1 == currentLevelData.starExit.1 { break }
        }
        ballPos = pos; moves += 1
        if ballPos.0 == currentLevelData.starExit.0 && ballPos.1 == currentLevelData.starExit.1 {
            totalMoves += moves
            if currentLevel < levels.count - 1 {
                currentLevel += 1; moves = 0
                ballPos = currentLevelData.ballStart; gravity = .down
            } else { phase = .complete }
        }
    }

    func nextPos(_ p: (Int,Int), dir: GrPzDirection) -> (Int,Int) {
        switch dir {
        case .up:    return (p.0, p.1 - 1)
        case .down:  return (p.0, p.1 + 1)
        case .left:  return (p.0 - 1, p.1)
        case .right: return (p.0 + 1, p.1)
        }
    }
}

#Preview { GravityPuzzleView() }

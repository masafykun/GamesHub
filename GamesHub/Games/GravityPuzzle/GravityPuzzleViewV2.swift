import SwiftUI

// MARK: - Models V2

enum GrPzV2Direction: CaseIterable {
    case up, down, left, right
    var arrow: String {
        switch self { case .up: return "↑"; case .down: return "↓"; case .left: return "←"; case .right: return "→" }
    }
}

struct GrPzV2Level {
    let ballStart: (Int, Int)
    let starExit: (Int, Int)
    let walls: [(Int, Int)]
}

enum GrPzV2Phase { case start, playing, complete }

// MARK: - View V2

struct GravityPuzzleViewV2: View {
    @State private var phase: GrPzV2Phase = .start
    @State private var currentLevel: Int = 0
    @State private var ballPos: (Int, Int) = (0, 0)
    @State private var moves: Int = 0
    @State private var gravity: GrPzV2Direction = .down
    @State private var totalMoves: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var ballScale: Double = 1.0

    let gridSize = 8

    let levels: [GrPzV2Level] = [
        GrPzV2Level(ballStart: (0,0), starExit: (7,7), walls: [(2,0),(2,1),(2,2),(5,4),(5,5),(5,6)]),
        GrPzV2Level(ballStart: (0,7), starExit: (7,0), walls: [(3,3),(3,4),(3,5),(4,2),(4,3)]),
        GrPzV2Level(ballStart: (3,0), starExit: (3,7), walls: [(1,2),(2,2),(4,2),(5,2),(3,4),(2,5),(4,5)]),
        GrPzV2Level(ballStart: (0,3), starExit: (7,4), walls: [(2,1),(2,2),(2,3),(5,4),(5,5),(5,6),(3,6),(4,1)]),
        GrPzV2Level(ballStart: (1,1), starExit: (6,6), walls: [(0,3),(1,3),(2,3),(3,3),(4,4),(5,4),(6,4),(7,4),(3,1),(3,2)])
    ]

    var currentLevelData: GrPzV2Level { levels[currentLevel] }

    let gradientColors: [Color] = [Color(red: 0.1, green: 0.05, blue: 0.3), Color(red: 0.05, green: 0.2, blue: 0.35)]

    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("GRAVITY\nPUZZLE").font(.system(size: 44, weight: .black, design: .rounded))
                .multilineTextAlignment(.center).foregroundColor(.white)
            Text("Slide the ball to the star!\nTap arrows to change gravity.")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0f", difficultyMultiplier * 100))%")
                    .font(.caption).foregroundColor(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.ultraThinMaterial).clipShape(Capsule())
            }
            Button("START") { startGame() }
                .font(.headline).foregroundColor(.white)
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 1))
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(currentLevel + 1)/\(levels.count)").foregroundColor(.white).font(.headline)
                    if difficultyMultiplier > 1.0 {
                        Text("Difficulty +\(String(format: "%.0f", (difficultyMultiplier - 1) * 100))%")
                            .font(.caption2).foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("Moves: \(moves)").foregroundColor(.cyan).font(.headline)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Gravity arrows
            VStack(spacing: 6) {
                arrowButton(.up)
                HStack(spacing: 20) {
                    arrowButton(.left)
                    Text(gravity.arrow).font(.system(size: 26)).foregroundColor(.cyan)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.cyan.opacity(0.5), lineWidth: 1))
                    arrowButton(.right)
                }
                arrowButton(.down)
            }
        }
        .padding(.vertical)
    }

    func cellView(col: Int, row: Int) -> some View {
        let isWall = currentLevelData.walls.contains(where: { $0.0 == col && $0.1 == row })
        let isBall = ballPos.0 == col && ballPos.1 == row
        let isStar = currentLevelData.starExit.0 == col && currentLevelData.starExit.1 == row
        return ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isWall ? Color.white.opacity(0.25) : Color.white.opacity(0.06))
                .frame(width: 36, height: 36)
            if isBall {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 22, height: 22)
                    .shadow(color: .cyan.opacity(0.6), radius: 6)
                    .scaleEffect(ballScale)
            }
            if isStar { Text("⭐").font(.system(size: 17)) }
        }
    }

    func arrowButton(_ dir: GrPzV2Direction) -> some View {
        Button(dir.arrow) { applyGravity(dir) }
            .font(.system(size: 26, weight: .bold))
            .foregroundColor(gravity == dir ? .cyan : .white)
            .frame(width: 50, height: 50)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                gravity == dir ? .cyan.opacity(0.7) : .white.opacity(0.3), lineWidth: 1))
    }

    var completeScreen: some View {
        VStack(spacing: 20) {
            Text("🎉").font(.system(size: 60))
            Text("COMPLETE!").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Total Moves: \(totalMoves)").foregroundColor(.cyan).font(.title2)
            Text("Difficulty: \(String(format: "%.0f", difficultyMultiplier * 100))%")
                .foregroundColor(.orange).font(.subheadline)
            Button("PLAY AGAIN") { phase = .start; currentLevel = 0; totalMoves = 0 }
                .font(.headline).foregroundColor(.white)
                .padding(.horizontal, 36).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.25), lineWidth: 1))
        .padding()
    }

    func startGame() {
        currentLevel = 0; moves = 0; totalMoves = 0
        ballPos = currentLevelData.ballStart
        gravity = .down; phase = .playing
    }

    func applyGravity(_ dir: GrPzV2Direction) {
        gravity = dir
        var pos = ballPos
        while true {
            let next = nextPos(pos, dir: dir)
            guard next.0 >= 0, next.0 < gridSize, next.1 >= 0, next.1 < gridSize else { break }
            if currentLevelData.walls.contains(where: { $0.0 == next.0 && $0.1 == next.1 }) { break }
            pos = next
            if pos.0 == currentLevelData.starExit.0 && pos.1 == currentLevelData.starExit.1 { break }
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { ballPos = pos }
        moves += 1
        if ballPos.0 == currentLevelData.starExit.0 && ballPos.1 == currentLevelData.starExit.1 {
            totalMoves += moves
            let effectiveMoves = Int(Double(moves) / difficultyMultiplier)
            recentResults.append(effectiveMoves <= 4)
            if recentResults.count > 5 { recentResults.removeFirst() }
            if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
            }
            if currentLevel < levels.count - 1 {
                currentLevel += 1; moves = 0
                ballPos = currentLevelData.ballStart; gravity = .down
            } else { phase = .complete }
        }
    }

    func nextPos(_ p: (Int,Int), dir: GrPzV2Direction) -> (Int,Int) {
        switch dir {
        case .up:    return (p.0, p.1 - 1)
        case .down:  return (p.0, p.1 + 1)
        case .left:  return (p.0 - 1, p.1)
        case .right: return (p.0 + 1, p.1)
        }
    }
}

#Preview { GravityPuzzleViewV2() }

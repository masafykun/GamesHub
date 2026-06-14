import SwiftUI

enum MzGamePhase { case start, playing, won, lost }
enum MzDirection { case up, down, left, right }

struct MzCell: Equatable {
    var x: Int
    var y: Int
}

struct MzMaze {
    let size: Int
    var walls: [[Set<MzDirection>]]

    init(size: Int, seed: Int = 42) {
        self.size = size
        self.walls = Array(repeating: Array(repeating: Set<MzDirection>(), count: size), count: size)
        generateMaze(seed: seed)
    }

    mutating func generateMaze(seed: Int) {
        // All walls start closed; use recursive backtracking
        var allWalls = Array(repeating: Array(repeating: Set([MzDirection.up, .down, .left, .right]), count: size), count: size)
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)
        var rng = seed

        func nextRand() -> Int {
            rng = rng &* 1664525 &+ 1013904223
            return abs(rng)
        }

        func carve(x: Int, y: Int) {
            visited[y][x] = true
            var dirs: [MzDirection] = [.up, .down, .left, .right]
            // Shuffle dirs
            for i in stride(from: dirs.count - 1, through: 1, by: -1) {
                let j = nextRand() % (i + 1)
                dirs.swapAt(i, j)
            }
            for dir in dirs {
                let nx: Int
                let ny: Int
                switch dir {
                case .up:    nx = x; ny = y - 1
                case .down:  nx = x; ny = y + 1
                case .left:  nx = x - 1; ny = y
                case .right: nx = x + 1; ny = y
                }
                guard nx >= 0, nx < size, ny >= 0, ny < size, !visited[ny][nx] else { continue }
                allWalls[y][x].remove(dir)
                let opposite: MzDirection
                switch dir {
                case .up:    opposite = .down
                case .down:  opposite = .up
                case .left:  opposite = .right
                case .right: opposite = .left
                }
                allWalls[ny][nx].remove(opposite)
                carve(x: nx, y: ny)
            }
        }

        carve(x: 0, y: 0)
        self.walls = allWalls
    }

    func canMove(from cell: MzCell, direction: MzDirection) -> Bool {
        let x = cell.x; let y = cell.y
        guard x >= 0, x < size, y >= 0, y < size else { return false }
        return !walls[y][x].contains(direction)
    }
}

struct MazeView: View {
    @State private var phase: MzGamePhase = .start
    @State private var player = MzCell(x: 0, y: 0)
    @State private var maze = MzMaze(size: 13)
    @State private var elapsed: Double = 0
    @State private var level: Int = 1
    @State private var timer: Timer? = nil
    @State private var dragStart: CGPoint? = nil

    let gridSize = 13
    let exit = MzCell(x: 12, y: 12)

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .playing: gameView
            case .won: resultView(won: true)
            case .lost: resultView(won: false)
            }
        }
    }

    var startView: some View {
        VStack(spacing: 24) {
            Text("MAZE").font(.system(size: 52, weight: .black)).foregroundColor(.primary)
            Text("Swipe to navigate\nfrom start to exit").multilineTextAlignment(.center).foregroundColor(.secondary)
            Button("Start") { startGame() }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.blue).foregroundColor(.white).clipShape(Capsule())
        }
    }

    var gameView: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Level \(level)", systemImage: "flag.fill").font(.headline)
                Spacer()
                Label(String(format: "%.1fs", elapsed), systemImage: "clock").font(.headline)
            }.padding(.horizontal)

            GeometryReader { geo in
                let cellSize = min(geo.size.width, geo.size.height) / CGFloat(gridSize)
                Canvas { ctx, size in
                    let cs = min(size.width, size.height) / CGFloat(gridSize)
                    // Draw cells and walls
                    for y in 0..<gridSize {
                        for x in 0..<gridSize {
                            let rect = CGRect(x: CGFloat(x)*cs, y: CGFloat(y)*cs, width: cs, height: cs)
                            // Floor
                            let fillColor: Color = (x == 0 && y == 0) ? .green.opacity(0.3) :
                                (x == exit.x && y == exit.y) ? .red.opacity(0.3) : .clear
                            ctx.fill(Path(rect), with: .color(fillColor))
                            // Walls
                            let cell = MzCell(x: x, y: y)
                            let ws = maze.walls[y][x]
                            ctx.stroke(Path { p in
                                if ws.contains(.up) {
                                    p.move(to: CGPoint(x: CGFloat(x)*cs, y: CGFloat(y)*cs))
                                    p.addLine(to: CGPoint(x: CGFloat(x+1)*cs, y: CGFloat(y)*cs))
                                }
                                if ws.contains(.down) {
                                    p.move(to: CGPoint(x: CGFloat(x)*cs, y: CGFloat(y+1)*cs))
                                    p.addLine(to: CGPoint(x: CGFloat(x+1)*cs, y: CGFloat(y+1)*cs))
                                }
                                if ws.contains(.left) {
                                    p.move(to: CGPoint(x: CGFloat(x)*cs, y: CGFloat(y)*cs))
                                    p.addLine(to: CGPoint(x: CGFloat(x)*cs, y: CGFloat(y+1)*cs))
                                }
                                if ws.contains(.right) {
                                    p.move(to: CGPoint(x: CGFloat(x+1)*cs, y: CGFloat(y)*cs))
                                    p.addLine(to: CGPoint(x: CGFloat(x+1)*cs, y: CGFloat(y+1)*cs))
                                }
                            }, with: .color(.primary), lineWidth: 1.5)
                            _ = cell
                        }
                    }
                    // Player
                    let pr = CGRect(
                        x: CGFloat(player.x)*cs + cs*0.15,
                        y: CGFloat(player.y)*cs + cs*0.15,
                        width: cs*0.7, height: cs*0.7
                    )
                    ctx.fill(Path(ellipseIn: pr), with: .color(.blue))
                }
                .frame(width: CGFloat(gridSize)*cellSize, height: CGFloat(gridSize)*cellSize)
                .gesture(DragGesture(minimumDistance: 10)
                    .onEnded { val in
                        handleSwipe(translation: val.translation)
                    })
            }
            .aspectRatio(1, contentMode: .fit)
            .padding()

            Text("Swipe to move").font(.caption).foregroundColor(.secondary)
        }
    }

    func resultView(won: Bool) -> some View {
        VStack(spacing: 20) {
            Text(won ? "You Escaped!" : "Times Up").font(.system(size: 36, weight: .bold))
            Text(String(format: "Time: %.1f seconds", elapsed)).foregroundColor(.secondary)
            Text("Level \(level)").font(.headline)
            HStack(spacing: 16) {
                if won && level < 3 {
                    Button("Next Level") { nextLevel() }
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(Color.green).foregroundColor(.white).clipShape(Capsule())
                }
                Button("Restart") { level = 1; startGame() }
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.blue).foregroundColor(.white).clipShape(Capsule())
            }
        }
    }

    func handleSwipe(translation: CGSize) {
        let dir: MzDirection
        if abs(translation.width) > abs(translation.height) {
            dir = translation.width > 0 ? .right : .left
        } else {
            dir = translation.height > 0 ? .down : .up
        }
        movePlayer(direction: dir)
    }

    func movePlayer(direction: MzDirection) {
        guard phase == .playing else { return }
        guard maze.canMove(from: player, direction: direction) else { return }
        switch direction {
        case .up:    player.y -= 1
        case .down:  player.y += 1
        case .left:  player.x -= 1
        case .right: player.x += 1
        }
        if player == exit { winGame() }
    }

    func startGame() {
        player = MzCell(x: 0, y: 0)
        maze = MzMaze(size: gridSize, seed: level * 997 + 42)
        elapsed = 0
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    func nextLevel() {
        level += 1
        startGame()
    }

    func winGame() {
        timer?.invalidate()
        phase = .won
    }
}

#Preview { MazeView() }

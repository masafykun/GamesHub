import SwiftUI

enum MzV3Phase { case start, playing, won }
enum MzV3Dir { case up, down, left, right }

struct MzV3Cell: Equatable {
    var x: Int; var y: Int
}

struct MzLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct MzV3Maze {
    let size: Int
    var walls: [[Set<MzV3Dir>]]

    init(size: Int, lcg: inout MzLCG) {
        self.size = size
        self.walls = Array(repeating: Array(repeating: Set<MzV3Dir>(), count: size), count: size)
        generate(lcg: &lcg)
    }

    mutating func generate(lcg: inout MzLCG) {
        var allWalls = Array(repeating: Array(repeating: Set([MzV3Dir.up, .down, .left, .right]), count: size), count: size)
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)

        // Build a stack-based iterative backtracker to avoid stack overflow
        var stack = [MzV3Cell(x: 0, y: 0)]
        visited[0][0] = true

        while !stack.isEmpty {
            let cur = stack.last!
            var neighbors: [(MzV3Dir, MzV3Cell)] = []
            let dirs: [MzV3Dir] = [.up, .down, .left, .right]
            for d in dirs {
                let nx = cur.x + (d == .left ? -1 : d == .right ? 1 : 0)
                let ny = cur.y + (d == .up ? -1 : d == .down ? 1 : 0)
                if nx >= 0, nx < size, ny >= 0, ny < size, !visited[ny][nx] {
                    neighbors.append((d, MzV3Cell(x: nx, y: ny)))
                }
            }
            if neighbors.isEmpty {
                stack.removeLast()
            } else {
                let idx = lcg.nextInt(neighbors.count)
                let (d, next) = neighbors[idx]
                let opp: MzV3Dir = d == .up ? .down : d == .down ? .up : d == .left ? .right : .left
                allWalls[cur.y][cur.x].remove(d)
                allWalls[next.y][next.x].remove(opp)
                visited[next.y][next.x] = true
                stack.append(next)
            }
        }

        self.walls = allWalls
    }

    func canMove(from cell: MzV3Cell, dir: MzV3Dir) -> Bool {
        !walls[cell.y][cell.x].contains(dir)
    }
}

struct MazeViewV3: View {
    @State private var phase: MzV3Phase = .start
    @State private var player = MzV3Cell(x: 0, y: 0)
    @State private var maze: MzV3Maze = { var l = MzLCG(seed: 1); return MzV3Maze(size: 13, lcg: &l) }()
    @State private var elapsed: Double = 0
    @State private var level: Int = 1
    @State private var gameTimer: Timer? = nil
    @State private var seedInt: Int = 1

    let gridSize = 13
    var exitCell: MzV3Cell { MzV3Cell(x: gridSize - 1, y: gridSize - 1) }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .playing: gameView
            case .won: wonView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 28) {
            Text("MAZE")
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.primary)
            Text("Swipe to navigate\nthrough the maze")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Play") { startGame() }
                .font(.headline)
                .padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 22)
                .foregroundColor(.primary)
        }
        .padding(36)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameView: some View {
        VStack(spacing: 14) {
            HStack {
                neuLabel("Level \(level)", icon: "flag.fill")
                Spacer()
                neuLabel(String(format: "%.1fs", elapsed), icon: "clock.fill")
            }
            .padding(.horizontal)

            GeometryReader { geo in
                let cs = min(geo.size.width, geo.size.height) / CGFloat(gridSize)
                Canvas { ctx, size in
                    let cellSz = min(size.width, size.height) / CGFloat(gridSize)
                    for y in 0..<gridSize {
                        for x in 0..<gridSize {
                            let rect = CGRect(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz, width: cellSz, height: cellSz)
                            if x == 0 && y == 0 {
                                ctx.fill(Path(rect), with: .color(.green.opacity(0.25)))
                            } else if x == exitCell.x && y == exitCell.y {
                                ctx.fill(Path(rect), with: .color(.orange.opacity(0.3)))
                            }
                            let ws = maze.walls[y][x]
                            // Light shadow lines (top/left = lighter, bottom/right = darker for neu effect)
                            ctx.stroke(Path { p in
                                if ws.contains(.up)    { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y)*cellSz)) }
                                if ws.contains(.down)  { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y+1)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y+1)*cellSz)) }
                                if ws.contains(.left)  { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y+1)*cellSz)) }
                                if ws.contains(.right) { p.move(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y+1)*cellSz)) }
                            }, with: .color(Color(.systemGray3)), lineWidth: 1.5)
                        }
                    }
                    let pr = CGRect(x: CGFloat(player.x)*cellSz + cellSz*0.15, y: CGFloat(player.y)*cellSz + cellSz*0.15, width: cellSz*0.7, height: cellSz*0.7)
                    ctx.fill(Path(ellipseIn: pr), with: .color(.blue))
                }
                .frame(width: CGFloat(gridSize)*cs, height: CGFloat(gridSize)*cs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .gesture(DragGesture(minimumDistance: 10).onEnded { val in swipe(val.translation) })
            }
            .aspectRatio(1, contentMode: .fit)
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            Text("SEED: #\(seedInt)")
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    var wonView: some View {
        VStack(spacing: 22) {
            Text("Escaped!").font(.system(size: 40, weight: .bold, design: .rounded))
            Text(String(format: "%.1f seconds", elapsed)).foregroundColor(.secondary)
            Text("Level \(level) — Seed #\(seedInt)").font(.caption).foregroundColor(.secondary)
            HStack(spacing: 16) {
                if level < 3 {
                    Button("Next Level") { level += 1; startGame() }
                        .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                        .neumorphicCard(radius: 20).foregroundColor(.primary)
                }
                Button("Restart") { level = 1; startGame() }
                    .font(.headline).padding(.horizontal, 24).padding(.vertical, 12)
                    .neumorphicCard(radius: 20).foregroundColor(.primary)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    func neuLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundColor(.primary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .neumorphicCard(radius: 12)
    }

    func swipe(_ translation: CGSize) {
        guard phase == .playing else { return }
        let dir: MzV3Dir
        if abs(translation.width) > abs(translation.height) {
            dir = translation.width > 0 ? .right : .left
        } else {
            dir = translation.height > 0 ? .down : .up
        }
        guard maze.canMove(from: player, dir: dir) else { return }
        switch dir {
        case .up:    player.y -= 1
        case .down:  player.y += 1
        case .left:  player.x -= 1
        case .right: player.x += 1
        }
        if player == exitCell { finishGame() }
    }

    func startGame() {
        player = MzV3Cell(x: 0, y: 0)
        var lcg = MzLCG(seed: seedInt &* 997 &+ level &* 31)
        maze = MzV3Maze(size: gridSize, lcg: &lcg)
        elapsed = 0
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    func finishGame() {
        gameTimer?.invalidate()
        seedInt += 1
        phase = .won
    }
}

#Preview { MazeViewV3() }

import SwiftUI

enum MzV2Phase { case start, playing, won }
enum MzV2Dir { case up, down, left, right }

struct MzV2Cell: Equatable {
    var x: Int; var y: Int
}

struct MzV2Maze {
    let size: Int
    var walls: [[Set<MzV2Dir>]]

    init(size: Int, seed: Int = 1) {
        self.size = size
        self.walls = Array(repeating: Array(repeating: Set<MzV2Dir>(), count: size), count: size)
        generate(seed: seed)
    }

    mutating func generate(seed: Int) {
        var allWalls = Array(repeating: Array(repeating: Set([MzV2Dir.up, .down, .left, .right]), count: size), count: size)
        var visited = Array(repeating: Array(repeating: false, count: size), count: size)
        var rng = seed

        func rand() -> Int { rng = rng &* 1664525 &+ 1013904223; return abs(rng) }

        func carve(x: Int, y: Int) {
            visited[y][x] = true
            var dirs: [MzV2Dir] = [.up, .down, .left, .right]
            for i in stride(from: dirs.count - 1, through: 1, by: -1) { dirs.swapAt(i, rand() % (i + 1)) }
            for d in dirs {
                let nx = x + (d == .left ? -1 : d == .right ? 1 : 0)
                let ny = y + (d == .up ? -1 : d == .down ? 1 : 0)
                guard nx >= 0, nx < size, ny >= 0, ny < size, !visited[ny][nx] else { continue }
                allWalls[y][x].remove(d)
                let opp: MzV2Dir = d == .up ? .down : d == .down ? .up : d == .left ? .right : .left
                allWalls[ny][nx].remove(opp)
                carve(x: nx, y: ny)
            }
        }

        carve(x: 0, y: 0)
        self.walls = allWalls
    }

    func canMove(from cell: MzV2Cell, dir: MzV2Dir) -> Bool {
        !walls[cell.y][cell.x].contains(dir)
    }
}

struct MazeViewV2: View {
    @State private var phase: MzV2Phase = .start
    @State private var player = MzV2Cell(x: 0, y: 0)
    @State private var maze = MzV2Maze(size: 13)
    @State private var elapsed: Double = 0
    @State private var level: Int = 1
    @State private var gameTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    let gridSize = 13
    var exitCell: MzV2Cell { MzV2Cell(x: gridSize - 1, y: gridSize - 1) }

    var gradientBG: LinearGradient {
        LinearGradient(colors: [Color.indigo.opacity(0.85), Color.purple.opacity(0.85)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        ZStack {
            gradientBG.ignoresSafeArea()
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
                .foregroundColor(.white)
            Text("Swipe to navigate through\nthe maze to the exit")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
                .font(.subheadline)
            Button("Play") { startGame() }
                .font(.headline).padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameView: some View {
        VStack(spacing: 14) {
            HStack {
                glassLabel("Level \(level)", icon: "flag.fill")
                Spacer()
                glassLabel(String(format: "%.1fs", elapsed), icon: "clock.fill")
            }
            .padding(.horizontal)

            GeometryReader { geo in
                let cs = min(geo.size.width, geo.size.height) / CGFloat(gridSize)
                ZStack {
                    Canvas { ctx, size in
                        let cellSz = min(size.width, size.height) / CGFloat(gridSize)
                        for y in 0..<gridSize {
                            for x in 0..<gridSize {
                                let rect = CGRect(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz, width: cellSz, height: cellSz)
                                if x == 0 && y == 0 {
                                    ctx.fill(Path(rect), with: .color(.green.opacity(0.4)))
                                } else if x == exitCell.x && y == exitCell.y {
                                    ctx.fill(Path(rect), with: .color(.yellow.opacity(0.5)))
                                }
                                let ws = maze.walls[y][x]
                                ctx.stroke(Path { p in
                                    if ws.contains(.up)    { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y)*cellSz)) }
                                    if ws.contains(.down)  { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y+1)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y+1)*cellSz)) }
                                    if ws.contains(.left)  { p.move(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x)*cellSz, y: CGFloat(y+1)*cellSz)) }
                                    if ws.contains(.right) { p.move(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y)*cellSz)); p.addLine(to: CGPoint(x: CGFloat(x+1)*cellSz, y: CGFloat(y+1)*cellSz)) }
                                }, with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                            }
                        }
                        let pr = CGRect(x: CGFloat(player.x)*cellSz + cellSz*0.15, y: CGFloat(player.y)*cellSz + cellSz*0.15, width: cellSz*0.7, height: cellSz*0.7)
                        ctx.fill(Path(ellipseIn: pr), with: .color(.cyan))
                    }
                    .frame(width: CGFloat(gridSize)*cs, height: CGFloat(gridSize)*cs)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .gesture(DragGesture(minimumDistance: 10).onEnded { val in
                    swipe(val.translation)
                })
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            if speedMultiplier > 1.0 {
                Text("Speed x\(String(format: "%.1f", speedMultiplier))")
                    .font(.caption).foregroundColor(.yellow)
            }
        }
    }

    var wonView: some View {
        VStack(spacing: 22) {
            Text("Escaped!").font(.system(size: 40, weight: .bold, design: .rounded)).foregroundColor(.white)
            Text(String(format: "%.1f seconds", elapsed)).foregroundColor(.white.opacity(0.8))
            Text("Level \(level)").foregroundColor(.white.opacity(0.7))
            HStack(spacing: 16) {
                if level < 3 {
                    Button("Next Level") { level += 1; startGame() }
                        .buttonStyle(MzGlassButtonStyle())
                }
                Button("Restart") { level = 1; recentResults = []; speedMultiplier = 1.0; startGame() }
                    .buttonStyle(MzGlassButtonStyle())
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    func glassLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func swipe(_ translation: CGSize) {
        guard phase == .playing else { return }
        let dir: MzV2Dir
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
        if player == exitCell { finishGame(won: true) }
    }

    func startGame() {
        player = MzV2Cell(x: 0, y: 0)
        maze = MzV2Maze(size: gridSize, seed: level * 1337 + 7)
        elapsed = 0
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1 * speedMultiplier
        }
    }

    func finishGame(won: Bool) {
        gameTimer?.invalidate()
        recentResults.append(won)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
        }
        phase = .won
    }
}

struct MzGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 28).padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

#Preview { MazeViewV2() }

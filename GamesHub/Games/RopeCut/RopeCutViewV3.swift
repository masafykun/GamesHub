import SwiftUI

// MARK: - LCG Seeded Random
struct RCtLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models V3
struct RCtV3Pin {
    var position: CGPoint
}

struct RCtV3Rope {
    var pinIndex: Int
    var cut: Bool = false
}

struct RCtV3LevelData {
    var pins: [RCtV3Pin]
    var ropeIndices: [Int]
    var ballStart: CGPoint
    var starPosition: CGPoint
}

enum RCtV3Phase {
    case start, playing, levelComplete, gameOver
}

struct RopeCutViewV3: View {
    @State private var phase: RCtV3Phase = .start
    @State private var currentLevel: Int = 0
    @State private var score: Int = 0
    @State private var seedInt: Int = 1

    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var ropes: [RCtV3Rope] = []
    @State private var pins: [RCtV3Pin] = []
    @State private var starPos: CGPoint = .zero
    @State private var timer: Timer? = nil

    let ballRadius: Double = 18
    let starRadius: Double = 22
    let gravity: Double = 380
    let dt: Double = 1.0 / 60.0

    func generateLevel(index: Int, geo: GeometryProxy) -> RCtV3LevelData {
        var lcg = RCtLCG(seed: seedInt &* 100 &+ index)
        let w = geo.size.width, h = geo.size.height
        let ropeCount = min(index + 1, 3)

        var genPins: [RCtV3Pin] = []
        for _ in 0..<ropeCount {
            let px = 0.15 + lcg.nextDouble() * 0.7
            let py = 0.04 + lcg.nextDouble() * 0.15
            genPins.append(RCtV3Pin(position: CGPoint(x: px * w, y: py * h)))
        }

        let bx = 0.3 + lcg.nextDouble() * 0.4
        let by = 0.3 + lcg.nextDouble() * 0.15
        let sx = 0.1 + lcg.nextDouble() * 0.8
        let sy = 0.65 + lcg.nextDouble() * 0.15

        return RCtV3LevelData(
            pins: genPins,
            ropeIndices: Array(0..<ropeCount),
            ballStart: CGPoint(x: bx * w, y: by * h),
            starPosition: CGPoint(x: sx * w, y: sy * h)
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen(geo: geo)
                case .playing:
                    gameScreen(geo: geo)
                case .levelComplete:
                    resultScreen(title: "Level \(currentLevel) Done!", subtitle: "Score: \(score)",
                                 buttonLabel: currentLevel < 5 ? "Next Level" : "Finish") {
                        if currentLevel < 5 { loadLevel(geo: geo) } else { phase = .gameOver }
                    }
                case .gameOver:
                    resultScreen(title: "All Done!", subtitle: "Final Score: \(score)",
                                 buttonLabel: "Play Again") {
                        resetGame(geo: geo)
                    }
                }
            }
        }
    }

    func startScreen(geo: GeometryProxy) -> some View {
        VStack(spacing: 28) {
            Text("Rope Cut").font(.system(size: 44, weight: .heavy)).foregroundColor(.primary)
            Text("Tap ropes to cut them\nLand on the ★ star!").multilineTextAlignment(.center).foregroundColor(.secondary).font(.body)
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button("Play") {
                currentLevel = 0; score = 0; phase = .playing
                loadLevel(geo: geo)
            }
            .padding(.horizontal, 44).padding(.vertical, 14)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
            .foregroundColor(.primary).font(.title2.bold())
            .shadow(color: .black.opacity(0.08), radius: 4, x: 2, y: 2)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Ropes
            ForEach(ropes.indices, id: \.self) { i in
                if !ropes[i].cut {
                    let pin = pins[ropes[i].pinIndex]
                    RCtV3RopeLine(start: pin.position, end: ballPos)
                        .stroke(Color.brown.opacity(0.85), lineWidth: 3)
                        .onTapGesture { cutRope(index: i) }
                }
            }
            // Pins
            ForEach(pins.indices, id: \.self) { i in
                ZStack {
                    Circle().fill(Color(.systemGray4)).frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 1)
                        .shadow(color: .white.opacity(0.8), radius: 2, x: -1, y: -1)
                }
                .position(pins[i].position)
            }
            // Star target
            Text("★").font(.system(size: 36)).foregroundColor(.yellow)
                .shadow(color: .orange.opacity(0.4), radius: 4)
                .position(starPos)
            // Ball
            Circle()
                .fill(Color.orange.opacity(0.9))
                .frame(width: CGFloat(ballRadius * 2), height: CGFloat(ballRadius * 2))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.6), radius: 2, x: -1, y: -1)
                .position(ballPos)

            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level \(currentLevel)").font(.headline.bold()).foregroundColor(.primary)
                        Text("SEED: #\(seedInt)").font(.system(.caption2, design: .monospaced)).foregroundColor(.gray)
                    }
                    .padding(12)
                    .neumorphicCard(radius: 12)
                    .padding()
                    Spacer()
                    Text("Score: \(score)").font(.headline.bold()).foregroundColor(.primary)
                        .padding(12)
                        .neumorphicCard(radius: 12)
                        .padding()
                }
                Spacer()
            }
        }
        .onAppear { setupLevel(index: currentLevel - 1, geo: geo) }
    }

    func resultScreen(title: String, subtitle: String, buttonLabel: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 22) {
            Text(title).font(.largeTitle.bold()).foregroundColor(.primary)
            Text(subtitle).font(.title2).foregroundColor(.secondary)
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button(buttonLabel, action: action)
                .padding(.horizontal, 36).padding(.vertical, 12)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.7), lineWidth: 1))
                .foregroundColor(.primary).font(.title3.bold())
                .shadow(color: .black.opacity(0.08), radius: 4, x: 2, y: 2)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    func resetGame(geo: GeometryProxy) {
        seedInt += 1
        currentLevel = 0; score = 0; phase = .playing
        loadLevel(geo: geo)
    }

    func loadLevel(geo: GeometryProxy) {
        currentLevel += 1; phase = .playing
        setupLevel(index: currentLevel - 1, geo: geo)
    }

    func setupLevel(index: Int, geo: GeometryProxy) {
        guard index < 5 else { phase = .gameOver; return }
        timer?.invalidate()
        let level = generateLevel(index: index, geo: geo)
        pins = level.pins
        ropes = level.ropeIndices.map { RCtV3Rope(pinIndex: $0) }
        ballPos = level.ballStart
        ballVel = .zero
        starPos = level.starPosition
        timer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { _ in updatePhysics(geo: geo) }
    }

    func cutRope(index: Int) {
        guard index < ropes.count else { return }
        ropes[index].cut = true
        score += 10
    }

    func updatePhysics(geo: GeometryProxy) {
        let activeRopes = ropes.filter { !$0.cut }
        if activeRopes.isEmpty {
            ballVel.y += gravity * dt
        } else {
            ballVel.y += gravity * dt
            for rope in activeRopes {
                let pin = pins[rope.pinIndex]
                let dx = ballPos.x - pin.position.x
                let dy = ballPos.y - pin.position.y
                let dist = sqrt(dx * dx + dy * dy)
                if dist > 0 {
                    let nx = dx / dist, ny = dy / dist
                    let dot = ballVel.x * nx + ballVel.y * ny
                    if dot > 0 { ballVel.x -= dot * nx; ballVel.y -= dot * ny }
                }
            }
        }
        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt
        let w = geo.size.width, h = geo.size.height
        if ballPos.x < ballRadius { ballPos.x = ballRadius; ballVel.x = abs(ballVel.x) * 0.6 }
        if ballPos.x > w - ballRadius { ballPos.x = w - ballRadius; ballVel.x = -abs(ballVel.x) * 0.6 }
        if ballPos.y > h - ballRadius { ballPos.y = h - ballRadius; ballVel.y = -abs(ballVel.y) * 0.4; ballVel.x *= 0.8 }
        let dx = ballPos.x - starPos.x, dy = ballPos.y - starPos.y
        if sqrt(dx * dx + dy * dy) < starRadius + ballRadius {
            timer?.invalidate(); score += 50; phase = .levelComplete
        }
        if ballPos.y > h + 50 { timer?.invalidate(); phase = .gameOver }
    }
}

struct RCtV3RopeLine: Shape {
    var start: CGPoint
    var end: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        return p
    }
}

#Preview { RopeCutViewV3() }

import SwiftUI

// MARK: - Models V2
struct RCtV2Pin {
    var position: CGPoint
}

struct RCtV2Rope {
    var pinIndex: Int
    var cut: Bool = false
}

struct RCtV2Level {
    var pins: [RCtV2Pin]
    var ropeIndices: [Int]
    var ballStart: CGPoint
    var starPosition: CGPoint
}

enum RCtV2Phase {
    case start, playing, levelComplete, gameOver
}

struct RopeCutViewV2: View {
    @State private var phase: RCtV2Phase = .start
    @State private var currentLevel: Int = 0
    @State private var score: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var ropes: [RCtV2Rope] = []
    @State private var pins: [RCtV2Pin] = []
    @State private var starPos: CGPoint = .zero
    @State private var timer: Timer? = nil

    let baseGravity: Double = 400
    let ballRadius: Double = 18
    let starRadius: Double = 22
    let dt: Double = 1.0 / 60.0

    var gravity: Double { baseGravity * speedMultiplier }

    var levels: [RCtV2Level] {
        [
            RCtV2Level(pins: [RCtV2Pin(position: CGPoint(x: 0.5, y: 0.05))],
                       ropeIndices: [0], ballStart: CGPoint(x: 0.5, y: 0.35),
                       starPosition: CGPoint(x: 0.5, y: 0.75)),
            RCtV2Level(pins: [RCtV2Pin(position: CGPoint(x: 0.3, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.7, y: 0.05))],
                       ropeIndices: [0, 1], ballStart: CGPoint(x: 0.5, y: 0.35),
                       starPosition: CGPoint(x: 0.2, y: 0.75)),
            RCtV2Level(pins: [RCtV2Pin(position: CGPoint(x: 0.5, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.85, y: 0.4))],
                       ropeIndices: [0, 1], ballStart: CGPoint(x: 0.6, y: 0.35),
                       starPosition: CGPoint(x: 0.15, y: 0.7)),
            RCtV2Level(pins: [RCtV2Pin(position: CGPoint(x: 0.2, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.8, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.5, y: 0.1))],
                       ropeIndices: [0, 1, 2], ballStart: CGPoint(x: 0.5, y: 0.35),
                       starPosition: CGPoint(x: 0.8, y: 0.72)),
            RCtV2Level(pins: [RCtV2Pin(position: CGPoint(x: 0.15, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.85, y: 0.05)), RCtV2Pin(position: CGPoint(x: 0.5, y: 0.08))],
                       ropeIndices: [0, 1, 2], ballStart: CGPoint(x: 0.5, y: 0.3),
                       starPosition: CGPoint(x: 0.5, y: 0.78))
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color.purple, Color.blue.opacity(0.8)],
                               startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .levelComplete:
                    overlayMessage(title: "Level \(currentLevel) Complete!",
                                   subtitle: "Score: \(score)",
                                   buttonLabel: currentLevel < 5 ? "Next Level" : "Finish") {
                        recordResult(true)
                        if currentLevel < 5 { loadLevel(geo: geo) } else { phase = .gameOver }
                    }
                case .gameOver:
                    overlayMessage(title: "You Win!",
                                   subtitle: "Final Score: \(score)",
                                   buttonLabel: "Play Again") {
                        resetGame(geo: geo)
                    }
                }
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Rope Cut").font(.system(size: 48, weight: .bold)).foregroundColor(.white)
            Text("Tap ropes to cut them\nLand on the ★ star!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.85)).font(.title3)
            if speedMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0f", (speedMultiplier - 1) * 100))% faster")
                    .font(.caption).foregroundColor(.yellow)
            }
            Button("Play") { phase = .playing }
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white).font(.title2.bold())
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Ropes
            ForEach(ropes.indices, id: \.self) { i in
                if !ropes[i].cut {
                    let pin = pins[ropes[i].pinIndex]
                    RCtV2RopeLine(start: pin.position, end: ballPos)
                        .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom), lineWidth: 3)
                        .onTapGesture { cutRope(index: i) }
                }
            }
            // Pins
            ForEach(pins.indices, id: \.self) { i in
                Circle().fill(.white.opacity(0.9)).frame(width: 14, height: 14)
                    .shadow(color: .white.opacity(0.5), radius: 4)
                    .position(pins[i].position)
            }
            // Star
            Text("★").font(.system(size: 38))
                .shadow(color: .yellow.opacity(0.8), radius: 8)
                .position(starPos)
            // Ball
            Circle()
                .fill(RadialGradient(colors: [.orange, .red], center: .topLeading, startRadius: 2, endRadius: CGFloat(ballRadius * 2)))
                .frame(width: CGFloat(ballRadius * 2), height: CGFloat(ballRadius * 2))
                .shadow(color: .orange.opacity(0.5), radius: 6)
                .position(ballPos)

            // HUD
            VStack {
                HStack {
                    Text("Level \(currentLevel)")
                        .foregroundColor(.white).font(.headline.bold()).padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
                        .padding()
                    Spacer()
                    Text("Score: \(score)")
                        .foregroundColor(.white).font(.headline.bold()).padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.3), lineWidth: 1))
                        .padding()
                }
                Spacer()
            }
        }
        .onAppear { setupLevel(index: currentLevel - 1, geo: geo) }
    }

    func overlayMessage(title: String, subtitle: String, buttonLabel: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 22) {
            Text(title).font(.largeTitle.bold()).foregroundColor(.white)
            Text(subtitle).font(.title2).foregroundColor(.white.opacity(0.85))
            Button(buttonLabel, action: action)
                .padding(.horizontal, 36).padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .foregroundColor(.white).font(.title3.bold())
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        let trueCount = recentResults.filter { $0 }.count
        if recentResults.count == 5 && trueCount > 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
        }
    }

    func resetGame(geo: GeometryProxy) {
        currentLevel = 0; score = 0; phase = .playing
        loadLevel(geo: geo)
    }

    func loadLevel(geo: GeometryProxy) {
        currentLevel += 1; phase = .playing
        setupLevel(index: currentLevel - 1, geo: geo)
    }

    func setupLevel(index: Int, geo: GeometryProxy) {
        guard index < levels.count else { phase = .gameOver; return }
        timer?.invalidate()
        let level = levels[index]
        let w = geo.size.width, h = geo.size.height
        pins = level.pins.map { RCtV2Pin(position: CGPoint(x: $0.position.x * w, y: $0.position.y * h)) }
        ropes = level.ropeIndices.map { RCtV2Rope(pinIndex: $0) }
        ballPos = CGPoint(x: level.ballStart.x * w, y: level.ballStart.y * h)
        ballVel = .zero
        starPos = CGPoint(x: level.starPosition.x * w, y: level.starPosition.y * h)
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
        if ballPos.y > h + 50 { timer?.invalidate(); recordResult(false); phase = .gameOver }
    }
}

struct RCtV2RopeLine: Shape {
    var start: CGPoint
    var end: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: start)
        p.addLine(to: end)
        return p
    }
}

#Preview { RopeCutViewV2() }

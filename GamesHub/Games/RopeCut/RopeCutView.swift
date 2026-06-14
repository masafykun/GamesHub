import SwiftUI

// MARK: - Models
struct RCtPin {
    var position: CGPoint
}

struct RCtRope {
    var pinIndex: Int
    var cut: Bool = false
}

struct RCtLevel {
    var pins: [RCtPin]
    var ropeIndices: [Int]        // which pins the ball is tied to
    var ballStart: CGPoint
    var starPosition: CGPoint
}

// MARK: - Game Phase
enum RCtPhase {
    case start, playing, levelComplete, gameOver
}

struct RopeCutView: View {
    @State private var phase: RCtPhase = .start
    @State private var currentLevel: Int = 0
    @State private var score: Int = 0

    // Physics state
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = .zero
    @State private var ropes: [RCtRope] = []
    @State private var pins: [RCtPin] = []
    @State private var starPos: CGPoint = .zero

    @State private var timer: Timer? = nil

    let gravity: Double = 400
    let ballRadius: Double = 18
    let starRadius: Double = 22
    let dt: Double = 1.0 / 60.0

    var levels: [RCtLevel] {
        [
            RCtLevel(pins: [RCtPin(position: CGPoint(x: 0.5, y: 0.05))],
                     ropeIndices: [0], ballStart: CGPoint(x: 0.5, y: 0.35),
                     starPosition: CGPoint(x: 0.5, y: 0.75)),
            RCtLevel(pins: [RCtPin(position: CGPoint(x: 0.3, y: 0.05)), RCtPin(position: CGPoint(x: 0.7, y: 0.05))],
                     ropeIndices: [0, 1], ballStart: CGPoint(x: 0.5, y: 0.35),
                     starPosition: CGPoint(x: 0.2, y: 0.75)),
            RCtLevel(pins: [RCtPin(position: CGPoint(x: 0.5, y: 0.05)), RCtPin(position: CGPoint(x: 0.85, y: 0.4))],
                     ropeIndices: [0, 1], ballStart: CGPoint(x: 0.6, y: 0.35),
                     starPosition: CGPoint(x: 0.15, y: 0.7)),
            RCtLevel(pins: [RCtPin(position: CGPoint(x: 0.2, y: 0.05)), RCtPin(position: CGPoint(x: 0.8, y: 0.05)), RCtPin(position: CGPoint(x: 0.5, y: 0.1))],
                     ropeIndices: [0, 1, 2], ballStart: CGPoint(x: 0.5, y: 0.35),
                     starPosition: CGPoint(x: 0.8, y: 0.72)),
            RCtLevel(pins: [RCtPin(position: CGPoint(x: 0.15, y: 0.05)), RCtPin(position: CGPoint(x: 0.85, y: 0.05)), RCtPin(position: CGPoint(x: 0.5, y: 0.08))],
                     ropeIndices: [0, 1, 2], ballStart: CGPoint(x: 0.5, y: 0.3),
                     starPosition: CGPoint(x: 0.5, y: 0.78))
        ]
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemIndigo).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .levelComplete:
                    messageScreen(title: "Level \(currentLevel) Complete!", subtitle: "Score: \(score)", buttonLabel: currentLevel < 5 ? "Next Level" : "Finish") {
                        if currentLevel < 5 { loadLevel(geo: geo) }
                        else { phase = .gameOver }
                    }
                case .gameOver:
                    messageScreen(title: "You Win!", subtitle: "Final Score: \(score)", buttonLabel: "Play Again") {
                        resetGame(geo: geo)
                    }
                }
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Rope Cut").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
            Text("Tap ropes to cut them\nLand the ball on the star!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
            Button("Play") { phase = .playing }
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.white).foregroundColor(.indigo)
                .clipShape(Capsule()).font(.title2.bold())
        }
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Ropes
            ForEach(ropes.indices, id: \.self) { i in
                if !ropes[i].cut {
                    let pin = pins[ropes[i].pinIndex]
                    Path { path in
                        path.move(to: pin.position)
                        path.addLine(to: ballPos)
                    }
                    .stroke(Color.yellow, lineWidth: 3)
                    .contentShape(Rectangle())
                    .onTapGesture { cutRope(index: i) }
                }
            }
            // Pins
            ForEach(pins.indices, id: \.self) { i in
                Circle().fill(Color.white).frame(width: 14, height: 14)
                    .position(pins[i].position)
            }
            // Star
            Text("★").font(.system(size: 36)).position(starPos)
            // Ball
            Circle().fill(Color.orange).frame(width: CGFloat(ballRadius * 2), height: CGFloat(ballRadius * 2))
                .position(ballPos)

            // HUD
            VStack {
                HStack {
                    Text("Level \(currentLevel)").foregroundColor(.white).font(.headline).padding()
                    Spacer()
                    Text("Score: \(score)").foregroundColor(.white).font(.headline).padding()
                }
                Spacer()
            }
        }
        .onAppear { setupLevel(index: currentLevel - 1, geo: geo) }
    }

    func messageScreen(title: String, subtitle: String, buttonLabel: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 20) {
            Text(title).font(.largeTitle.bold()).foregroundColor(.white)
            Text(subtitle).font(.title2).foregroundColor(.white.opacity(0.8))
            Button(buttonLabel, action: action)
                .padding(.horizontal, 36).padding(.vertical, 12)
                .background(.white).foregroundColor(.indigo)
                .clipShape(Capsule()).font(.title3.bold())
        }
    }

    func resetGame(geo: GeometryProxy) {
        currentLevel = 0
        score = 0
        phase = .playing
        loadLevel(geo: geo)
    }

    func loadLevel(geo: GeometryProxy) {
        currentLevel += 1
        phase = .playing
        setupLevel(index: currentLevel - 1, geo: geo)
    }

    func setupLevel(index: Int, geo: GeometryProxy) {
        guard index < levels.count else { phase = .gameOver; return }
        timer?.invalidate()
        let level = levels[index]
        let w = geo.size.width, h = geo.size.height
        pins = level.pins.map { RCtPin(position: CGPoint(x: $0.position.x * w, y: $0.position.y * h)) }
        ropes = level.ropeIndices.map { RCtRope(pinIndex: $0) }
        ballPos = CGPoint(x: level.ballStart.x * w, y: level.ballStart.y * h)
        ballVel = .zero
        starPos = CGPoint(x: level.starPosition.x * w, y: level.starPosition.y * h)

        timer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { _ in
            updatePhysics(geo: geo)
        }
    }

    func cutRope(index: Int) {
        guard index < ropes.count else { return }
        ropes[index].cut = true
        score += 10
    }

    func updatePhysics(geo: GeometryProxy) {
        let activeRopes = ropes.filter { !$0.cut }
        if activeRopes.isEmpty {
            // Free fall
            ballVel.y += gravity * dt
        } else {
            // Pendulum: constrain to rope lengths
            ballVel.y += gravity * dt
            for rope in activeRopes {
                let pin = pins[rope.pinIndex]
                let dx = ballPos.x - pin.position.x
                let dy = ballPos.y - pin.position.y
                let dist = sqrt(dx * dx + dy * dy)
                let ropeLen = dist  // constraint: keep at current length
                if dist > 0 {
                    let nx = dx / dist, ny = dy / dist
                    let dot = ballVel.x * nx + ballVel.y * ny
                    if dot > 0 {
                        ballVel.x -= dot * nx
                        ballVel.y -= dot * ny
                    }
                    let _ = ropeLen
                }
            }
        }

        ballPos.x += ballVel.x * dt
        ballPos.y += ballVel.y * dt

        // Bounds
        let w = geo.size.width, h = geo.size.height
        if ballPos.x < ballRadius { ballPos.x = ballRadius; ballVel.x = abs(ballVel.x) * 0.6 }
        if ballPos.x > w - ballRadius { ballPos.x = w - ballRadius; ballVel.x = -abs(ballVel.x) * 0.6 }
        if ballPos.y > h - ballRadius { ballPos.y = h - ballRadius; ballVel.y = -abs(ballVel.y) * 0.4; ballVel.x *= 0.8 }

        // Check star
        let dx = ballPos.x - starPos.x, dy = ballPos.y - starPos.y
        if sqrt(dx * dx + dy * dy) < starRadius + ballRadius {
            timer?.invalidate()
            score += 50
            phase = .levelComplete
        }

        // Fell off bottom
        if ballPos.y > h + 50 {
            timer?.invalidate()
            phase = .gameOver
        }
    }
}

#Preview { RopeCutView() }

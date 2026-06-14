import SwiftUI

enum FHpPhase { case start, playing, gameOver }

struct FlickHoopsView: View {
    @State private var phase: FHpPhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var timer: Timer? = nil

    // Hoop
    @State private var hoopX: CGFloat = 0.5
    @State private var hoopY: CGFloat = 0.25

    // Ball drag
    @State private var isDragging: Bool = false
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero

    // Ball flight
    @State private var isFlying: Bool = false
    @State private var ballPos: CGPoint = .zero
    @State private var flightProgress: Double = 0
    @State private var flightTimer: Timer? = nil

    // Trajectory params
    @State private var throwVelocity: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let ballBase = CGPoint(x: W * 0.5, y: H * 0.82)
            let hoopPos = CGPoint(x: W * hoopX, y: H * hoopY)

            ZStack {
                Color(.systemBackground).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen
                case .gameOver:
                    gameOverScreen
                case .playing:
                    playingScreen(geo: geo, W: W, H: H, ballBase: ballBase, hoopPos: hoopPos)
                }
            }
            .onAppear {
                ballPos = ballBase
            }
        }
    }

    @ViewBuilder
    func playingScreen(geo: GeometryProxy, W: CGFloat, H: CGFloat, ballBase: CGPoint, hoopPos: CGPoint) -> some View {
        // Timer bar
        VStack(spacing: 0) {
            HStack {
                Text("Score: \(score)")
                    .font(.title2.bold())
                Spacer()
                Text(String(format: "%.1fs", timeLeft))
                    .font(.title2.bold())
                    .foregroundColor(timeLeft < 10 ? .red : .primary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()
        }

        // Hoop
        hoopView(at: hoopPos)

        // Arc preview
        if isDragging && !isFlying {
            arcPreview(ballBase: ballBase, velocity: CGSize(
                width: dragStart.x - dragCurrent.x,
                height: dragStart.y - dragCurrent.y
            ))
        }

        // Ball
        Circle()
            .fill(Color.orange)
            .overlay(Circle().stroke(Color.brown, lineWidth: 2))
            .frame(width: 36, height: 36)
            .position(isFlying ? ballPos : ballBase)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        guard !isFlying else { return }
                        isDragging = true
                        dragStart = val.startLocation
                        dragCurrent = val.location
                    }
                    .onEnded { val in
                        guard !isFlying else { return }
                        isDragging = false
                        let vel = CGSize(
                            width: val.startLocation.x - val.location.x,
                            height: val.startLocation.y - val.location.y
                        )
                        if vel.height > 20 {
                            throwBall(from: ballBase, velocity: vel, hoopPos: hoopPos, W: W, H: H)
                        }
                    }
            )
    }

    func hoopView(at pos: CGPoint) -> some View {
        ZStack {
            // Backboard
            Rectangle()
                .fill(Color.white)
                .frame(width: 54, height: 36)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                .position(CGPoint(x: pos.x, y: pos.y - 28))
            // Rim
            Capsule()
                .fill(Color.red)
                .frame(width: 48, height: 8)
                .position(pos)
            // Net lines
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 1, height: 18)
                    .position(CGPoint(x: pos.x - 16 + CGFloat(i) * 16, y: pos.y + 13))
            }
        }
    }

    func arcPreview(ballBase: CGPoint, velocity: CGSize) -> some View {
        let steps = 12
        return Path { path in
            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let x = ballBase.x + velocity.width * t * 1.8
                let y = ballBase.y - velocity.height * t * 1.8 + 300 * t * t
                let pt = CGPoint(x: x, y: y)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
        .stroke(Color.orange.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
    }

    func throwBall(from start: CGPoint, velocity: CGSize, hoopPos: CGPoint, W: CGFloat, H: CGFloat) {
        isFlying = true
        ballPos = start
        flightProgress = 0
        let totalSteps = 30
        var step = 0
        flightTimer?.invalidate()
        flightTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
            step += 1
            let prog = Double(step) / Double(totalSteps)
            let x = start.x + velocity.width * prog * 1.8
            let y = start.y - velocity.height * prog * 1.8 + 300 * prog * prog
            ballPos = CGPoint(x: x, y: y)
            let dist = hypot(ballPos.x - hoopPos.x, ballPos.y - hoopPos.y)
            if dist < 26 && prog > 0.3 {
                score += 1
                t.invalidate()
                isFlying = false
                moveHoop(W: W, H: H)
            } else if step >= totalSteps || ballPos.y > H + 40 {
                t.invalidate()
                isFlying = false
            }
        }
    }

    func moveHoop(W: CGFloat, H: CGFloat) {
        hoopX = CGFloat.random(in: 0.15...0.85)
        hoopY = CGFloat.random(in: 0.15...0.4)
    }

    func startGame(W: CGFloat, H: CGFloat) {
        score = 0
        timeLeft = 30
        phase = .playing
        hoopX = 0.5
        hoopY = 0.25
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { t in
            timeLeft -= 0.1
            if timeLeft <= 0 {
                timeLeft = 0
                t.invalidate()
                isFlying = false
                flightTimer?.invalidate()
                phase = .gameOver
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("FlickHoops").font(.largeTitle.bold())
            Text("Drag the ball upward\nto shoot into the hoop!").multilineTextAlignment(.center).foregroundColor(.secondary)
            Text("Score as many baskets as you can in 30 seconds.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)
            GeometryReader { g in
                Button("Play") { startGame(W: g.size.width, H: g.size.height) }
                    .buttonStyle(.borderedProminent).font(.title2.bold())
                    .frame(maxWidth: .infinity)
            }.frame(height: 50)
        }
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Time's Up!").font(.largeTitle.bold())
            Text("You scored \(score) basket\(score == 1 ? "" : "s")!")
                .font(.title2).foregroundColor(.secondary)
            GeometryReader { g in
                Button("Play Again") { startGame(W: g.size.width, H: g.size.height) }
                    .buttonStyle(.borderedProminent).font(.title2.bold())
                    .frame(maxWidth: .infinity)
            }.frame(height: 50)
        }
        .padding(32)
    }
}

#Preview { FlickHoopsView() }

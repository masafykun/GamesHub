import SwiftUI

enum FHpV2Phase { case start, playing, gameOver }

struct FlickHoopsViewV2: View {
    @State private var phase: FHpV2Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var timer: Timer? = nil

    // Adaptive difficulty
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

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
    @State private var flightTimer: Timer? = nil

    var adaptiveSpeed: Double { difficultyMultiplier }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let ballBase = CGPoint(x: W * 0.5, y: H * 0.82)
            let hoopPos = CGPoint(x: W * hoopX, y: H * hoopY)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.55, green: 0.1, blue: 0.35)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen(W: W, H: H)
                case .gameOver:
                    gameOverScreen(W: W, H: H)
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
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text("\(score)")
                        .font(.title.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Text(String(format: "%.1fs", timeLeft))
                        .font(.title.bold())
                        .foregroundColor(timeLeft < 10 ? .red : .white)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if difficultyMultiplier > 1.1 {
                Text("HARD MODE")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
                    .padding(.top, 4)
            }
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
            .fill(
                RadialGradient(
                    colors: [Color.orange, Color(red: 0.85, green: 0.3, blue: 0.05)],
                    center: .topLeading,
                    startRadius: 2,
                    endRadius: 20
                )
            )
            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            .frame(width: 38, height: 38)
            .shadow(color: .orange.opacity(0.5), radius: 8)
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
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.3), lineWidth: 1))
                .frame(width: 54, height: 36)
                .position(CGPoint(x: pos.x, y: pos.y - 28))
            Capsule()
                .fill(Color.red)
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                .frame(width: 48, height: 8)
                .shadow(color: .red.opacity(0.6), radius: 6)
                .position(pos)
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1, height: 18)
                    .position(CGPoint(x: pos.x - 16 + CGFloat(i) * 16, y: pos.y + 13))
            }
        }
    }

    func arcPreview(ballBase: CGPoint, velocity: CGSize) -> some View {
        Path { path in
            for i in 0...14 {
                let t = Double(i) / 14.0
                let x = ballBase.x + velocity.width * t * 1.8
                let y = ballBase.y - velocity.height * t * 1.8 + 300 * t * t
                let pt = CGPoint(x: x, y: y)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
        }
        .stroke(
            LinearGradient(colors: [.white.opacity(0.7), .white.opacity(0.1)], startPoint: .leading, endPoint: .trailing),
            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
        )
    }

    func throwBall(from start: CGPoint, velocity: CGSize, hoopPos: CGPoint, W: CGFloat, H: CGFloat) {
        isFlying = true
        ballPos = start
        let totalSteps = max(15, Int(30.0 / adaptiveSpeed))
        var step = 0
        flightTimer?.invalidate()
        flightTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { t in
            step += 1
            let prog = Double(step) / Double(totalSteps)
            let x = start.x + velocity.width * prog * 1.8
            let y = start.y - velocity.height * prog * 1.8 + 300 * prog * prog
            ballPos = CGPoint(x: x, y: y)
            let dist = hypot(ballPos.x - hoopPos.x, ballPos.y - hoopPos.y)
            let scored = dist < 26 && prog > 0.3
            if scored {
                score += 1
                t.invalidate()
                isFlying = false
                recordResult(true)
                moveHoop(W: W, H: H)
            } else if step >= totalSteps || ballPos.y > H + 40 {
                t.invalidate()
                isFlying = false
                if step >= totalSteps { recordResult(false) }
            }
        }
    }

    func recordResult(_ made: Bool) {
        recentResults.append(made)
        if recentResults.count > 10 { recentResults.removeFirst() }
        if recentResults.count >= 5 {
            let last5 = recentResults.suffix(5)
            let made5 = last5.filter { $0 }.count
            if made5 > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.5)
            }
        }
    }

    func moveHoop(W: CGFloat, H: CGFloat) {
        let margin = difficultyMultiplier > 1.1 ? 0.1 : 0.15
        hoopX = CGFloat.random(in: margin...(1 - margin))
        hoopY = CGFloat.random(in: 0.12...0.4)
    }

    func startGame(W: CGFloat, H: CGFloat) {
        score = 0
        timeLeft = 30
        recentResults = []
        difficultyMultiplier = 1.0
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

    func startScreen(W: CGFloat, H: CGFloat) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("FlickHoops")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                Text("Drag & release to shoot!")
                    .foregroundColor(.white.opacity(0.75))
                    .font(.subheadline)
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Play Now") { startGame(W: W, H: H) }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .padding(32)
    }

    func gameOverScreen(W: CGFloat, H: CGFloat) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Game Over").font(.largeTitle.bold()).foregroundColor(.white)
                Text("\(score) basket\(score == 1 ? "" : "s") in 30 seconds")
                    .foregroundColor(.white.opacity(0.8))
                if difficultyMultiplier > 1.1 {
                    Text("Played on Hard Mode!").font(.caption.bold()).foregroundColor(.yellow)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Play Again") { startGame(W: W, H: H) }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .padding(32)
    }
}

#Preview { FlickHoopsViewV2() }

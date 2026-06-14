import SwiftUI

// MARK: - LCG Random

struct FHpLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Game State

enum FHpV3Phase { case start, playing, gameOver }

struct FHpHoopSequenceItem {
    var x: CGFloat
    var y: CGFloat
}

// MARK: - View

struct FlickHoopsViewV3: View {
    @State private var seedInt: Int = 1
    @State private var phase: FHpV3Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var timer: Timer? = nil

    // Generated hoop sequence
    @State private var hoopSequence: [FHpHoopSequenceItem] = []
    @State private var hoopIndex: Int = 0

    var hoopX: CGFloat { hoopSequence.isEmpty ? 0.5 : hoopSequence[min(hoopIndex, hoopSequence.count - 1)].x }
    var hoopY: CGFloat { hoopSequence.isEmpty ? 0.25 : hoopSequence[min(hoopIndex, hoopSequence.count - 1)].y }

    // Ball drag
    @State private var isDragging: Bool = false
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero

    // Ball flight
    @State private var isFlying: Bool = false
    @State private var ballPos: CGPoint = .zero
    @State private var flightTimer: Timer? = nil

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            let ballBase = CGPoint(x: W * 0.5, y: H * 0.82)
            let hoopPos = CGPoint(x: W * hoopX, y: H * hoopY)

            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen(W: W, H: H)
                case .gameOver:
                    gameOverScreen(W: W, H: H)
                case .playing:
                    playingScreen(W: W, H: H, ballBase: ballBase, hoopPos: hoopPos)
                }
            }
            .onAppear {
                ballPos = ballBase
            }
        }
    }

    // MARK: - Screens

    @ViewBuilder
    func playingScreen(W: CGFloat, H: CGFloat, ballBase: CGPoint, hoopPos: CGPoint) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    Text("\(score)").font(.title.bold())
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME").font(.caption.weight(.semibold)).foregroundColor(.secondary)
                    Text(String(format: "%.1fs", timeLeft))
                        .font(.title.bold())
                        .foregroundColor(timeLeft < 10 ? .red : .primary)
                }
            }
            .padding(16)
            .neumorphicCard(radius: 16)
            .padding(.horizontal, 16)
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
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.4), .clear],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: 18
                        )
                    )
            )
            .overlay(Circle().stroke(Color(white: 0.6), lineWidth: 1))
            .frame(width: 38, height: 38)
            .shadow(color: .black.opacity(0.2), radius: 6, x: 3, y: 3)
            .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
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

    func startScreen(W: CGFloat, H: CGFloat) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("FlickHoops")
                    .font(.largeTitle.bold())
                Text("Drag the ball to shoot!")
                    .foregroundColor(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(28)
            .neumorphicCard(radius: 16)

            Button("Play") { startGame(W: W, H: H) }
                .font(.title2.bold())
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .neumorphicCard(radius: 14)
        }
        .padding(32)
    }

    func gameOverScreen(W: CGFloat, H: CGFloat) -> some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Time's Up!").font(.largeTitle.bold())
                Text("\(score) basket\(score == 1 ? "" : "s")!")
                    .font(.title2).foregroundColor(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(28)
            .neumorphicCard(radius: 16)

            Button("Play Again") { startGame(W: W, H: H) }
                .font(.title2.bold())
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .neumorphicCard(radius: 14)
        }
        .padding(32)
    }

    // MARK: - Hoop Drawing

    func hoopView(at pos: CGPoint) -> some View {
        ZStack {
            // Backboard (neumorphic style)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray6))
                .frame(width: 52, height: 34)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .position(CGPoint(x: pos.x, y: pos.y - 28))

            // Rim
            Capsule()
                .fill(Color.red)
                .frame(width: 48, height: 8)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.5), radius: 2, x: -1, y: -1)
                .position(pos)

            // Net
            ForEach(0..<3, id: \.self) { i in
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
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
        .stroke(Color.orange.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
    }

    // MARK: - Game Logic

    func generateHoopSequence(seed: Int, count: Int = 40) -> [FHpHoopSequenceItem] {
        var rng = FHpLCG(seed: seed)
        return (0..<count).map { _ in
            let x = CGFloat(rng.nextDouble()) * 0.7 + 0.15
            let y = CGFloat(rng.nextDouble()) * 0.28 + 0.12
            return FHpHoopSequenceItem(x: x, y: y)
        }
    }

    func throwBall(from start: CGPoint, velocity: CGSize, hoopPos: CGPoint, W: CGFloat, H: CGFloat) {
        isFlying = true
        ballPos = start
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
                hoopIndex = min(hoopIndex + 1, hoopSequence.count - 1)
            } else if step >= totalSteps || ballPos.y > H + 40 {
                t.invalidate()
                isFlying = false
                hoopIndex = min(hoopIndex + 1, hoopSequence.count - 1)
            }
        }
    }

    func startGame(W: CGFloat, H: CGFloat) {
        seedInt += 1
        score = 0
        timeLeft = 30
        hoopIndex = 0
        hoopSequence = generateHoopSequence(seed: seedInt)
        phase = .playing
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
}

#Preview { FlickHoopsViewV3() }

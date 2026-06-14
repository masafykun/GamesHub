import SwiftUI

// MARK: - LCG Seeded RNG

struct GPLCG {
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

enum GPV3Phase { case start, playing, result }

struct GPV3Hole {
    var ballPos: CGPoint
    var holePos: CGPoint
    var bumpers: [CGPoint]
}

// MARK: - Main View V3 (Neumorphism + Seeded Generation)

struct GolfPuttViewV3: View {
    @State private var phase: GPV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var currentHole: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var strokesThisHole: Int = 0
    @State private var holes: [GPV3Hole] = []

    @State private var ballPos: CGPoint = .zero
    @State private var ballVelocity: CGVector = .zero
    @State private var isBallMoving: Bool = false
    @State private var holed: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragOrigin: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero

    let ballRadius: CGFloat = 12
    let holeRadius: CGFloat = 17
    let bumperRadius: CGFloat = 14
    let friction: CGFloat = 0.975
    let maxPower: CGFloat = 115

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
        .onAppear { generateHoles() }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Golf Putt").font(.system(size: 44, weight: .bold)).foregroundColor(.primary)
            Text("3 holes · Par 2 each").foregroundColor(.secondary)
            Text("Drag from ball to putt.\nBumpers add a challenge!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .font(.subheadline)

            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)

            Button("Tee Off") { startGame() }
                .buttonStyle(GPV3ButtonStyle())
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    var resultScreen: some View {
        VStack(spacing: 22) {
            Text("Round Complete!").font(.title.bold()).foregroundColor(.primary)
            let par = (holes.isEmpty ? 3 : holes.count) * 2
            let diff = totalStrokes - par
            VStack(spacing: 8) {
                Text("Strokes: \(totalStrokes)").font(.title2.bold())
                Text("Par \(par)  \(diff >= 0 ? "+" : "")\(diff)")
                    .foregroundColor(diff <= 0 ? .green : .secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding()
            .neumorphicCard(radius: 14)

            Button("Play Again") { startGame() }
                .buttonStyle(GPV3ButtonStyle())
            Button("Menu") { phase = .start }
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(24)
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            // HUD
            HStack {
                Text("Hole \(currentHole + 1)/\(holes.isEmpty ? 3 : holes.count)").bold().foregroundColor(.primary)
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                Text("Strokes: \(totalStrokes + strokesThisHole)").bold().foregroundColor(.primary)
            }
            .padding()
            .background(Color(.systemGray5))
            .neumorphicCard(radius: 0)

            GeometryReader { geo in
                ZStack {
                    // Green surface
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(red: 0.22, green: 0.58, blue: 0.28))
                        .padding(14)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 4, y: 4)
                        .shadow(color: Color.white.opacity(0.7), radius: 8, x: -4, y: -4)

                    if !holes.isEmpty {
                        let hole = holes[currentHole]
                        let hc = scaledPt(hole.holePos, geo.size)

                        // Bumpers
                        ForEach(0..<hole.bumpers.count, id: \.self) { i in
                            let bp = scaledPt(hole.bumpers[i], geo.size)
                            Circle()
                                .fill(Color(red: 0.85, green: 0.3, blue: 0.2))
                                .frame(width: bumperRadius * 2, height: bumperRadius * 2)
                                .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.4), radius: 3, x: -2, y: -2)
                                .position(bp)
                        }

                        // Cup
                        Circle()
                            .fill(Color.black)
                            .frame(width: holeRadius * 2, height: holeRadius * 2)
                            .shadow(color: .black.opacity(0.5), radius: 5, x: 2, y: 2)
                            .position(hc)

                        // Flag
                        Path { p in
                            p.move(to: hc)
                            p.addLine(to: CGPoint(x: hc.x, y: hc.y - 38))
                            p.addLine(to: CGPoint(x: hc.x + 18, y: hc.y - 28))
                            p.addLine(to: CGPoint(x: hc.x, y: hc.y - 18))
                        }.stroke(Color.white, lineWidth: 2)
                    }

                    // Aim
                    if isDragging {
                        let dx = dragOrigin.x - dragCurrent.x
                        let dy = dragOrigin.y - dragCurrent.y
                        let dist = sqrt(dx * dx + dy * dy)
                        let power = min(dist / maxPower, 1.0)
                        if dist > 4 {
                            Path { p in
                                p.move(to: ballPos)
                                p.addLine(to: CGPoint(x: ballPos.x + dx * 0.55, y: ballPos.y + dy * 0.55))
                            }
                            .stroke(Color.yellow.opacity(0.9), style: StrokeStyle(lineWidth: 2.5, dash: [7, 5]))
                        }

                        VStack {
                            Spacer()
                            HStack(spacing: 10) {
                                Text("PWR").font(.caption2.bold()).foregroundColor(.white.opacity(0.8))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.3)).frame(width: 140, height: 10)
                                    Capsule()
                                        .fill(power > 0.75 ? Color.red : Color.yellow)
                                        .frame(width: 140 * power, height: 10)
                                        .shadow(color: (power > 0.75 ? Color.red : Color.yellow).opacity(0.6), radius: 4)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }

                    // Ball
                    Circle()
                        .fill(Color.white)
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: .black.opacity(0.35), radius: 5, x: 3, y: 3)
                        .shadow(color: .white.opacity(0.9), radius: 3, x: -2, y: -2)
                        .position(ballPos)

                    Color.clear.contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    guard !isBallMoving, !holed else { return }
                                    if !isDragging {
                                        let d = hypot(v.startLocation.x - ballPos.x, v.startLocation.y - ballPos.y)
                                        if d < 50 { isDragging = true; dragOrigin = v.startLocation }
                                    }
                                    dragCurrent = v.location
                                }
                                .onEnded { v in
                                    if isDragging {
                                        isDragging = false
                                        putt(from: v.startLocation, to: v.location, in: geo.size)
                                    }
                                }
                        )
                }
                .onAppear { setupHole(in: geo.size) }
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in tickPhysics() }
    }

    // MARK: - Logic

    func scaledPt(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    func generateHoles() {
        var rng = GPLCG(seed: seedInt)
        var generated: [GPV3Hole] = []
        let configs: [(CGPoint, CGPoint)] = [
            (CGPoint(x: 0.5, y: 0.82), CGPoint(x: 0.5, y: 0.18)),
            (CGPoint(x: 0.18, y: 0.78), CGPoint(x: 0.78, y: 0.22)),
            (CGPoint(x: 0.75, y: 0.8), CGPoint(x: 0.25, y: 0.2))
        ]
        for (bp, hp) in configs {
            let numBumpers = rng.nextInt(3) + 1
            var bumpers: [CGPoint] = []
            for _ in 0..<numBumpers {
                let bx = 0.2 + rng.nextDouble() * 0.6
                let by = 0.3 + rng.nextDouble() * 0.45
                bumpers.append(CGPoint(x: bx, y: by))
            }
            generated.append(GPV3Hole(ballPos: bp, holePos: hp, bumpers: bumpers))
        }
        holes = generated
    }

    func setupHole(in size: CGSize) {
        guard !holes.isEmpty else { return }
        ballPos = scaledPt(holes[currentHole].ballPos, size)
        strokesThisHole = 0
        holed = false
        ballVelocity = .zero
        isBallMoving = false
    }

    func putt(from: CGPoint, to: CGPoint, in size: CGSize) {
        guard !isBallMoving, !holed else { return }
        let dx = from.x - to.x
        let dy = from.y - to.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 4 else { return }
        let power = min(dist / maxPower, 1.0) * 12
        ballVelocity = CGVector(dx: dx / dist * power, dy: dy / dist * power)
        isBallMoving = true
        strokesThisHole += 1
    }

    func tickPhysics() {
        guard isBallMoving, !holes.isEmpty else { return }
        ballPos.x += ballVelocity.dx
        ballPos.y += ballVelocity.dy
        ballVelocity.dx *= friction
        ballVelocity.dy *= friction

        let bounds = UIScreen.main.bounds
        let hole = holes[currentHole]
        let hc = scaledPt(hole.holePos, bounds.size)

        // Check holed
        let hdx = ballPos.x - hc.x
        let hdy = ballPos.y - hc.y
        if sqrt(hdx * hdx + hdy * hdy) < holeRadius {
            holed = true
            isBallMoving = false
            totalStrokes += strokesThisHole
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { advanceHole() }
            return
        }

        // Bumper collisions
        for bumper in hole.bumpers {
            let bc = scaledPt(bumper, bounds.size)
            let bdx = ballPos.x - bc.x
            let bdy = ballPos.y - bc.y
            let dist = sqrt(bdx * bdx + bdy * bdy)
            let minDist = bumperRadius + ballRadius
            if dist < minDist && dist > 0 {
                let nx = bdx / dist
                let ny = bdy / dist
                ballPos.x = bc.x + nx * minDist
                ballPos.y = bc.y + ny * minDist
                let dot = ballVelocity.dx * nx + ballVelocity.dy * ny
                ballVelocity.dx -= 2 * dot * nx
                ballVelocity.dy -= 2 * dot * ny
                ballVelocity.dx *= 0.85
                ballVelocity.dy *= 0.85
            }
        }

        // Wall bounce
        let pad: CGFloat = ballRadius + 18
        let topPad: CGFloat = pad + 56
        if ballPos.x < pad { ballPos.x = pad; ballVelocity.dx = abs(ballVelocity.dx) }
        if ballPos.x > bounds.width - pad { ballPos.x = bounds.width - pad; ballVelocity.dx = -abs(ballVelocity.dx) }
        if ballPos.y < topPad { ballPos.y = topPad; ballVelocity.dy = abs(ballVelocity.dy) }
        if ballPos.y > bounds.height - pad { ballPos.y = bounds.height - pad; ballVelocity.dy = -abs(ballVelocity.dy) }

        if sqrt(ballVelocity.dx * ballVelocity.dx + ballVelocity.dy * ballVelocity.dy) < 0.15 {
            isBallMoving = false; ballVelocity = .zero
        }
    }

    func advanceHole() {
        if currentHole + 1 < holes.count {
            currentHole += 1
            let s = UIScreen.main.bounds.size
            ballPos = scaledPt(holes[currentHole].ballPos, s)
            strokesThisHole = 0
            holed = false
        } else {
            phase = .result
        }
    }

    func startGame() {
        seedInt += 1
        currentHole = 0
        totalStrokes = 0
        strokesThisHole = 0
        holed = false
        isBallMoving = false
        ballVelocity = .zero
        generateHoles()
        phase = .playing
    }
}

// MARK: - Button Style V3

struct GPV3ButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 38)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .foregroundColor(.primary)
            .clipShape(Capsule())
            .bold()
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.05 : 0.18), radius: configuration.isPressed ? 2 : 6, x: configuration.isPressed ? 1 : 4, y: configuration.isPressed ? 1 : 4)
            .shadow(color: Color.white.opacity(configuration.isPressed ? 0.5 : 0.85), radius: configuration.isPressed ? 2 : 6, x: configuration.isPressed ? -1 : -4, y: configuration.isPressed ? -1 : -4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

#Preview { GolfPuttViewV3() }

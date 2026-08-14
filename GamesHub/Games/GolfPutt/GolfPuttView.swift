import SwiftUI

// MARK: - Models 

enum GolfPuttPhase { case start, playing, result }

struct GolfPuttHole {
    var ballPos: CGPoint
    var holePos: CGPoint
}

// MARK: - Main View  (Glassmorphism + Adaptive Difficulty)

struct GolfPuttView: View {
    @State private var phase: GolfPuttPhase = .start
    @State private var currentHole: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var strokesThisHole: Int = 0
    @State private var holes: [GolfPuttHole] = GolfPuttHoleGen.holes()

    @State private var ballPos: CGPoint = .zero
    @State private var ballVelocity: CGVector = .zero
    @State private var isBallMoving: Bool = false
    @State private var holed: Bool = false
    @State private var isDragging: Bool = false
    @State private var dragOrigin: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero

    // Adaptive difficulty
    @State private var canvasSize: CGSize = UIScreen.main.bounds.size
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    let ballRadius: CGFloat = 12
    let holeRadius: CGFloat = 16
    let baseFriction: CGFloat = 0.97
    let maxPower: CGFloat = 110

    var friction: CGFloat { CGFloat(baseFriction * (difficultyMultiplier > 1.2 ? 0.96 : 1.0)) }
    var effectiveHoleRadius: CGFloat { holeRadius / CGFloat(difficultyMultiplier > 1.2 ? 1.3 : 1.0) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.3, blue: 0.6), Color(red: 0.05, green: 0.15, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("Golf Putt").font(.system(size: 48, weight: .bold)).foregroundColor(.white)
            Text("3 holes · Par 2 each").foregroundColor(.white.opacity(0.7))
            Text("Drag from ball to aim & power\nRelease to putt")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.6))
                .font(.subheadline)
            if difficultyMultiplier > 1.2 {
                Label("Hard Mode Active", systemImage: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.caption.bold())
            }
            Button("Tee Off") { startGame() }
                .buttonStyle(GolfPuttButtonStyle())
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var resultScreen: some View {
        VStack(spacing: 20) {
            Text("Round Complete!").font(.title.bold()).foregroundColor(.white)
            let par = holes.count * 2
            let diff = totalStrokes - par
            VStack(spacing: 8) {
                Text("Strokes: \(totalStrokes)").font(.title2.bold()).foregroundColor(.white)
                Text("Par \(par)  \(diff >= 0 ? "+" : "")\(diff)")
                    .foregroundColor(diff <= 0 ? .yellow : .white.opacity(0.6))
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Play Again") { startGame() }
                .buttonStyle(GolfPuttButtonStyle())
            Button("Menu") { phase = .start }
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 4)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(24)
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            // HUD
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(currentHole + 1)/\(holes.count)").foregroundColor(.white).bold()
                    if difficultyMultiplier > 1.2 {
                        Text("HARD").font(.caption2.bold()).foregroundColor(.orange)
                    }
                }
                Spacer()
                Text("Strokes: \(totalStrokes + strokesThisHole)").foregroundColor(.white).bold()
            }
            .padding()
            .background(.ultraThinMaterial)
            .overlay(Rectangle().frame(height: 1).foregroundColor(.white.opacity(0.2)), alignment: .bottom)

            GeometryReader { geo in
                ZStack {
                    // Green
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [Color(red: 0.15, green: 0.55, blue: 0.25), Color(red: 0.1, green: 0.42, blue: 0.18)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .padding(12)
                        .shadow(color: .black.opacity(0.3), radius: 10)

                    let hc = scaledPt(holes[currentHole].holePos, geo.size)

                    // Cup
                    Circle()
                        .fill(Color.black)
                        .frame(width: effectiveHoleRadius * 2, height: effectiveHoleRadius * 2)
                        .position(hc)

                    // Flag
                    Path { p in
                        p.move(to: hc)
                        p.addLine(to: CGPoint(x: hc.x, y: hc.y - 38))
                        p.addLine(to: CGPoint(x: hc.x + 18, y: hc.y - 29))
                        p.addLine(to: CGPoint(x: hc.x, y: hc.y - 20))
                    }.stroke(Color.white, lineWidth: 2)

                    // Aim line
                    if isDragging {
                        let dx = dragOrigin.x - dragCurrent.x
                        let dy = dragOrigin.y - dragCurrent.y
                        let dist = sqrt(dx * dx + dy * dy)
                        let power = min(dist / maxPower, 1.0)
                        if dist > 4 {
                            Path { p in
                                p.move(to: ballPos)
                                p.addLine(to: CGPoint(x: ballPos.x + dx * 0.5, y: ballPos.y + dy * 0.5))
                            }
                            .stroke(Color.yellow.opacity(0.85), style: StrokeStyle(lineWidth: 2.5, dash: [8, 5]))

                            // Power indicator dot
                            Circle()
                                .fill(power > 0.7 ? Color.red : Color.yellow)
                                .frame(width: 10, height: 10)
                                .position(CGPoint(x: ballPos.x + dx * 0.5, y: ballPos.y + dy * 0.5))
                        }

                        // Power bar
                        VStack {
                            Spacer()
                            HStack(spacing: 10) {
                                Text("PWR").font(.caption2.bold()).foregroundColor(.white.opacity(0.7))
                                ZStack(alignment: .leading) {
                                    Capsule().fill(.white.opacity(0.2)).frame(width: 140, height: 10)
                                    Capsule().fill(power > 0.7 ? Color.red : Color.yellow)
                                        .frame(width: 140 * power, height: 10)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        }
                    }

                    // Ball
                    Circle()
                        .fill(.white)
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: .black.opacity(0.4), radius: 4, x: 2, y: 2)
                        .position(ballPos)

                    Color.clear.contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    guard !isBallMoving, !holed else { return }
                                    if !isDragging {
                                        let d = hypot(v.startLocation.x - ballPos.x, v.startLocation.y - ballPos.y)
                                        if d < 48 { isDragging = true; dragOrigin = v.startLocation }
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
                .onAppear {
                    canvasSize = geo.size
                    setupHole(in: geo.size)
                }
                .onChange(of: geo.size) { _, newSize in canvasSize = newSize }
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in tickPhysics() }
    }

    // MARK: - Logic

    func scaledPt(_ p: CGPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    func setupHole(in size: CGSize) {
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
        let power = min(dist / maxPower, 1.0) * 12 * CGFloat(difficultyMultiplier)
        ballVelocity = CGVector(dx: dx / dist * power, dy: dy / dist * power)
        isBallMoving = true
        strokesThisHole += 1
    }

    func tickPhysics() {
        guard isBallMoving else { return }
        ballPos.x += ballVelocity.dx
        ballPos.y += ballVelocity.dy
        ballVelocity.dx *= friction
        ballVelocity.dy *= friction

        // The board is the green area reported by the layout — using the whole
        // screen here put the physical cup below the drawn one.
        let bounds = CGRect(origin: .zero, size: canvasSize)
        let hc = scaledPt(holes[currentHole].holePos, canvasSize)
        let dx = ballPos.x - hc.x
        let dy = ballPos.y - hc.y
        if sqrt(dx * dx + dy * dy) < effectiveHoleRadius {
            holed = true
            isBallMoving = false
            let underPar = strokesThisHole <= 2
            recentResults.append(underPar)
            if recentResults.count > 5 { recentResults.removeFirst() }
            if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.0)
            }
            totalStrokes += strokesThisHole
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { advanceHole() }
            return
        }

        let pad: CGFloat = ballRadius + 16
        if ballPos.x < pad { ballPos.x = pad; ballVelocity.dx = abs(ballVelocity.dx) }
        if ballPos.x > bounds.width - pad { ballPos.x = bounds.width - pad; ballVelocity.dx = -abs(ballVelocity.dx) }
        if ballPos.y < pad { ballPos.y = pad; ballVelocity.dy = abs(ballVelocity.dy) }
        if ballPos.y > bounds.height - pad { ballPos.y = bounds.height - pad; ballVelocity.dy = -abs(ballVelocity.dy) }

        if sqrt(ballVelocity.dx * ballVelocity.dx + ballVelocity.dy * ballVelocity.dy) < 0.15 {
            isBallMoving = false; ballVelocity = .zero
        }
    }

    func advanceHole() {
        if currentHole + 1 < holes.count {
            currentHole += 1
            ballPos = scaledPt(holes[currentHole].ballPos, canvasSize)
            strokesThisHole = 0
            holed = false
        } else {
            phase = .result
        }
    }

    func startGame() {
        holes = GolfPuttHoleGen.holes()
        currentHole = 0
        totalStrokes = 0
        strokesThisHole = 0
        holed = false
        isBallMoving = false
        ballVelocity = .zero
        phase = .playing
    }
}

// MARK: - Hole Generator 

struct GolfPuttHoleGen {
    static func holes() -> [GolfPuttHole] {
        [
            GolfPuttHole(ballPos: CGPoint(x: 0.5, y: 0.8), holePos: CGPoint(x: 0.5, y: 0.18)),
            GolfPuttHole(ballPos: CGPoint(x: 0.2, y: 0.78), holePos: CGPoint(x: 0.78, y: 0.22)),
            GolfPuttHole(ballPos: CGPoint(x: 0.78, y: 0.78), holePos: CGPoint(x: 0.22, y: 0.22))
        ]
    }
}

// MARK: - Button Style 

struct GolfPuttButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            .foregroundColor(.white)
            .bold()
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview { GolfPuttView() }

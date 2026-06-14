import SwiftUI

// MARK: - Models

enum GPGamePhase { case start, playing, result }

struct GPHole {
    var ballPos: CGPoint
    var holePos: CGPoint
    var par: Int = 2
}

// MARK: - Main View

struct GolfPuttView: View {
    @State private var phase: GPGamePhase = .start
    @State private var currentHole: Int = 0
    @State private var totalStrokes: Int = 0
    @State private var strokesThisHole: Int = 0
    @State private var holes: [GPHole] = GPHoleGenerator.generateHoles()

    @State private var ballPos: CGPoint = .zero
    @State private var isDragging: Bool = false
    @State private var dragStart: CGPoint = .zero
    @State private var dragCurrent: CGPoint = .zero
    @State private var ballVelocity: CGVector = .zero
    @State private var isBallMoving: Bool = false
    @State private var holed: Bool = false

    let ballRadius: CGFloat = 12
    let holeRadius: CGFloat = 16
    let maxPower: CGFloat = 120
    let friction: CGFloat = 0.97

    var timer: Timer? { nil }

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.55, blue: 0.27).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .result: resultScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Golf Putt").font(.system(size: 44, weight: .bold)).foregroundColor(.white)
            Text("3 holes · Par 2 each").foregroundColor(.white.opacity(0.8))
            Text("Drag from ball to aim & set power\nRelease to putt").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7)).font(.subheadline)
            Button("Play") {
                resetGame()
                phase = .playing
            }
            .buttonStyle(GPButtonStyle())
        }
        .padding()
    }

    var resultScreen: some View {
        VStack(spacing: 20) {
            Text("Round Complete!").font(.title.bold()).foregroundColor(.white)
            let par = holes.count * 2
            let diff = totalStrokes - par
            Text("Total Strokes: \(totalStrokes)").font(.title2).foregroundColor(.white)
            Text("Par: \(par)  (\(diff >= 0 ? "+" : "")\(diff))").foregroundColor(diff <= 0 ? .yellow : .white.opacity(0.7))
            Button("Play Again") {
                resetGame()
                phase = .playing
            }
            .buttonStyle(GPButtonStyle())
            Button("Menu") { phase = .start }
                .foregroundColor(.white.opacity(0.7))
        }
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hole \(currentHole + 1)/\(holes.count)").foregroundColor(.white).bold()
                Spacer()
                Text("Strokes: \(totalStrokes + strokesThisHole)").foregroundColor(.white).bold()
            }
            .padding()
            .background(Color.black.opacity(0.3))

            GeometryReader { geo in
                ZStack {
                    // Green surface
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(red: 0.2, green: 0.6, blue: 0.3))
                        .padding(8)

                    // Hole (cup)
                    let holeCenter = scaledPoint(holes[currentHole].holePos, in: geo.size)
                    Circle()
                        .fill(Color.black)
                        .frame(width: holeRadius * 2, height: holeRadius * 2)
                        .position(holeCenter)

                    // Flag
                    Path { p in
                        p.move(to: holeCenter)
                        p.addLine(to: CGPoint(x: holeCenter.x, y: holeCenter.y - 36))
                        p.addLine(to: CGPoint(x: holeCenter.x + 16, y: holeCenter.y - 28))
                        p.addLine(to: CGPoint(x: holeCenter.x, y: holeCenter.y - 20))
                    }
                    .stroke(Color.white, lineWidth: 2)

                    // Aim arrow
                    if isDragging {
                        let from = ballPos
                        let to = dragStart
                        let dir = CGVector(dx: to.x - from.x, dy: to.y - from.y)
                        let dist = sqrt(dir.dx * dir.dx + dir.dy * dir.dy)
                        let power = min(dist / maxPower, 1.0)
                        // Power bar
                        VStack {
                            Spacer()
                            HStack {
                                Text("Power").foregroundColor(.white).font(.caption)
                                GeometryReader { _ in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.4)).frame(height: 10)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.yellow).frame(width: 160 * power, height: 10)
                                    }
                                }
                                .frame(width: 160, height: 10)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 12)
                        }

                        if dist > 4 {
                            Path { p in
                                p.move(to: from)
                                p.addLine(to: CGPoint(x: from.x - dir.dx * 0.6, y: from.y - dir.dy * 0.6))
                            }
                            .stroke(Color.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                        }
                    }

                    // Ball
                    Circle()
                        .fill(Color.white)
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(radius: 3)
                        .position(ballPos)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { val in
                                    if !isBallMoving && !holed {
                                        if !isDragging {
                                            let touch = val.startLocation
                                            let bp = ballPos
                                            let d = hypot(touch.x - bp.x, touch.y - bp.y)
                                            if d < 44 { isDragging = true; dragStart = val.startLocation }
                                        }
                                        dragCurrent = val.location
                                    }
                                }
                                .onEnded { val in
                                    if isDragging {
                                        isDragging = false
                                        putt(from: val.startLocation, to: val.location, in: geo.size)
                                    }
                                }
                        )
                }
                .onAppear { setupHole(in: geo.size) }
            }
        }
        .onReceive(
            Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()
        ) { _ in tickPhysics() }
    }

    // MARK: - Helpers

    func scaledPoint(_ p: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: p.x * size.width, y: p.y * size.height)
    }

    func setupHole(in size: CGSize) {
        ballPos = scaledPoint(holes[currentHole].ballPos, in: size)
        strokesThisHole = 0
        holed = false
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
        guard isBallMoving else { return }
        ballPos.x += ballVelocity.dx
        ballPos.y += ballVelocity.dy
        ballVelocity.dx *= friction
        ballVelocity.dy *= friction

        // Check holed
        let hp = scaledPoint(holes[currentHole].holePos, in: UIScreen.main.bounds.size)
        let dx = ballPos.x - hp.x
        let dy = ballPos.y - hp.y
        if sqrt(dx * dx + dy * dy) < holeRadius {
            holed = true
            isBallMoving = false
            totalStrokes += strokesThisHole
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { advanceHole() }
            return
        }

        // Bounds
        let bounds = UIScreen.main.bounds
        if ballPos.x < ballRadius { ballPos.x = ballRadius; ballVelocity.dx = abs(ballVelocity.dx) }
        if ballPos.x > bounds.width - ballRadius { ballPos.x = bounds.width - ballRadius; ballVelocity.dx = -abs(ballVelocity.dx) }
        if ballPos.y < ballRadius + 60 { ballPos.y = ballRadius + 60; ballVelocity.dy = abs(ballVelocity.dy) }
        if ballPos.y > bounds.height - ballRadius { ballPos.y = bounds.height - ballRadius; ballVelocity.dy = -abs(ballVelocity.dy) }

        let speed = sqrt(ballVelocity.dx * ballVelocity.dx + ballVelocity.dy * ballVelocity.dy)
        if speed < 0.15 { isBallMoving = false; ballVelocity = .zero }
    }

    func advanceHole() {
        if currentHole + 1 < holes.count {
            currentHole += 1
            let bounds = UIScreen.main.bounds
            ballPos = scaledPoint(holes[currentHole].ballPos, in: bounds.size)
            strokesThisHole = 0
            holed = false
        } else {
            phase = .result
        }
    }

    func resetGame() {
        holes = GPHoleGenerator.generateHoles()
        currentHole = 0
        totalStrokes = 0
        strokesThisHole = 0
        holed = false
        isBallMoving = false
        ballVelocity = .zero
    }
}

// MARK: - Hole Generator

struct GPHoleGenerator {
    static func generateHoles() -> [GPHole] {
        [
            GPHole(ballPos: CGPoint(x: 0.5, y: 0.8), holePos: CGPoint(x: 0.5, y: 0.2)),
            GPHole(ballPos: CGPoint(x: 0.2, y: 0.75), holePos: CGPoint(x: 0.75, y: 0.25)),
            GPHole(ballPos: CGPoint(x: 0.75, y: 0.8), holePos: CGPoint(x: 0.25, y: 0.2))
        ]
    }
}

// MARK: - Button Style

struct GPButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 36)
            .padding(.vertical, 14)
            .background(Color.white)
            .foregroundColor(Color(red: 0.13, green: 0.45, blue: 0.2))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .bold()
    }
}

#Preview { GolfPuttView() }

import SwiftUI

// MARK: - Models

struct BwlPin: Identifiable {
    let id: Int
    var position: CGPoint
    var isStanding: Bool = true
}

enum BwlGamePhase {
    case start, aiming, rolling, result, gameOver
}

// MARK: - Main View

struct BowlingView: View {
    @State private var pins: [BwlPin] = BowlingView.makePins()
    @State private var phase: BwlGamePhase = .start
    @State private var ballX: CGFloat = 0
    @State private var ballY: CGFloat = 0
    @State private var ballVisible: Bool = false
    @State private var frame: Int = 1
    @State private var roll: Int = 1
    @State private var scores: [Int] = []
    @State private var dragStartY: CGFloat = 0
    @State private var pinsDownThisRoll: Int = 0
    @State private var frameMessage: String = ""

    private let laneHeight: CGFloat = 400
    private let pinRadius: CGFloat = 12
    private let ballRadius: CGFloat = 18

    static func makePins() -> [BwlPin] {
        // 10-pin triangular formation, row 1 at top
        let rows = [[0], [1, 2], [3, 4, 5], [6, 7, 8, 9]]
        var result: [BwlPin] = []
        let spacing: CGFloat = 34
        for (r, row) in rows.enumerated() {
            for (c, id) in row.enumerated() {
                let x = CGFloat(c) * spacing - CGFloat(row.count - 1) * spacing / 2
                let y = CGFloat(r) * spacing
                result.append(BwlPin(id: id, position: CGPoint(x: x, y: y)))
            }
        }
        return result
    }

    var totalScore: Int { scores.reduce(0, +) }

    var body: some View {
        ZStack {
            Color(red: 0.13, green: 0.15, blue: 0.2).ignoresSafeArea()

            if phase == .start {
                startScreen
            } else if phase == .gameOver {
                gameOverScreen
            } else {
                gameScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("BOWLING").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            Text("Drag horizontally to aim\nSwipe up to bowl").multilineTextAlignment(.center).foregroundColor(.gray)
            Button("START") {
                resetGame()
                phase = .aiming
            }
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.white).font(.headline)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Total Score: \(totalScore)").font(.title2).foregroundColor(.orange)
            Button("PLAY AGAIN") {
                resetGame()
                phase = .aiming
            }
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.orange).clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundColor(.white).font(.headline)
        }
    }

    var gameScreen: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let laneTop: CGFloat = 60
            let pinAreaY = laneTop + 40
            let ballStartY = laneTop + laneHeight - 40

            ZStack {
                // Lane
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.85, green: 0.75, blue: 0.55))
                    .frame(width: 180, height: laneHeight)
                    .position(x: cx, y: laneTop + laneHeight / 2)

                // Pins
                ForEach(pins) { pin in
                    if pin.isStanding {
                        Circle()
                            .fill(Color.white)
                            .frame(width: pinRadius * 2, height: pinRadius * 2)
                            .overlay(Circle().stroke(Color.red, lineWidth: 3))
                            .position(x: cx + pin.position.x, y: pinAreaY + pin.position.y)
                    }
                }

                // Ball
                if ballVisible {
                    Circle()
                        .fill(Color.black)
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 2))
                        .position(x: ballX, y: ballY)
                }

                // Score & info
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame: \(frame)/5  Roll: \(roll)/2").foregroundColor(.white).font(.subheadline)
                    Text("Score: \(totalScore)").foregroundColor(.orange).font(.headline)
                    if !frameMessage.isEmpty {
                        Text(frameMessage).foregroundColor(.yellow).font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .position(x: geo.size.width / 2, y: 24)

                // Drag area
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard phase == .aiming else { return }
                                let clampedX = max(cx - 70, min(cx + 70, cx + value.translation.width))
                                ballX = clampedX
                                ballY = ballStartY
                                dragStartY = value.startLocation.y
                                ballVisible = true
                            }
                            .onEnded { value in
                                guard phase == .aiming else { return }
                                let dy = value.startLocation.y - value.location.y
                                if dy > 20 {
                                    phase = .rolling
                                    animateBall(startX: ballX, startY: ballStartY, targetX: cx + (ballX - cx) * 0.3, targetY: pinAreaY, geo: geo, pinAreaY: pinAreaY, cx: cx)
                                }
                            }
                    )
            }
            .onAppear {
                ballX = cx
                ballY = laneTop + laneHeight - 40
                ballVisible = false
            }
        }
    }

    func animateBall(startX: CGFloat, startY: CGFloat, targetX: CGFloat, targetY: CGFloat, geo: GeometryProxy, pinAreaY: CGFloat, cx: CGFloat) {
        withAnimation(.linear(duration: 0.6)) {
            ballY = targetY
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Check collisions
            var count = 0
            for i in pins.indices {
                if pins[i].isStanding {
                    let px = cx + pins[i].position.x
                    let py = pinAreaY + pins[i].position.y
                    let dist = hypot(ballX - px, ballY - py)
                    if dist < ballRadius + pinRadius + 8 {
                        pins[i].isStanding = false
                        count += 1
                    }
                }
            }
            pinsDownThisRoll = count
            scores.append(count)
            advanceRoll()
        }
    }

    func advanceRoll() {
        let standing = pins.filter { $0.isStanding }.count
        if roll == 1 && standing == 0 {
            frameMessage = "STRIKE!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextFrame() }
        } else if roll == 2 {
            frameMessage = standing == 0 ? "SPARE!" : ""
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextFrame() }
        } else {
            roll = 2
            frameMessage = ""
            ballVisible = false
            phase = .aiming
        }
    }

    func nextFrame() {
        if frame >= 5 {
            phase = .gameOver
        } else {
            frame += 1
            roll = 1
            frameMessage = ""
            pins = BowlingView.makePins()
            ballVisible = false
            phase = .aiming
        }
    }

    func resetGame() {
        pins = BowlingView.makePins()
        frame = 1
        roll = 1
        scores = []
        frameMessage = ""
        ballVisible = false
        pinsDownThisRoll = 0
    }
}

#Preview { BowlingView() }

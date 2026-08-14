import SwiftUI

// MARK: - Models

struct BowlingPin: Identifiable {
    let id: Int
    var position: CGPoint
    var isStanding: Bool = true
}

enum BowlingPhase {
    case start, aiming, rolling, result, gameOver
}

// MARK: -  View (Glassmorphism + Adaptive Difficulty)

struct BowlingView: View {
    @State private var pins: [BowlingPin] = BowlingView.makePins()
    @State private var phase: BowlingPhase = .start
    @AppStorage("bowlingBestScore") private var bestScore: Int = 0
    @State private var ballX: CGFloat = 0
    @State private var ballY: CGFloat = 0
    @State private var ballVisible: Bool = false
    @State private var frame: Int = 1
    @State private var roll: Int = 1
    @State private var scores: [Int] = []
    @State private var frameMessage: String = ""
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    private let pinRadius: CGFloat = 12
    private let ballRadius: CGFloat = 18
    private let laneHeight: CGFloat = 400
    private let baseHitRadius: CGFloat = 20.0

    var hitRadius: CGFloat { CGFloat(baseHitRadius / difficultyMultiplier) }
    var animDuration: Double { 0.6 / difficultyMultiplier }

    static func makePins() -> [BowlingPin] {
        let rows: [[Int]] = [[0], [1, 2], [3, 4, 5], [6, 7, 8, 9]]
        var result: [BowlingPin] = []
        let spacing: CGFloat = 34
        for (r, row) in rows.enumerated() {
            for (c, id) in row.enumerated() {
                let x = CGFloat(c) * spacing - CGFloat(row.count - 1) * spacing / 2
                let y = CGFloat(r) * spacing
                result.append(BowlingPin(id: id, position: CGPoint(x: x, y: y)))
            }
        }
        return result
    }

    var totalScore: Int { scores.reduce(0, +) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.45), Color(red: 0.35, green: 0.1, blue: 0.5)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

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
        VStack(spacing: 28) {
            Text("BOWLING").font(.system(size: 42, weight: .black)).foregroundColor(.white)
            Text("Drag to aim, swipe up to bowl\nDifficulty adapts to your skill")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
            Button("START GAME") {
                resetGame()
                phase = .aiming
            }
            .padding(.horizontal, 44).padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1))
            .foregroundColor(.white).font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("GAME OVER").font(.system(size: 34, weight: .black)).foregroundColor(.white)
            Text("Score: \(totalScore)").font(.title).foregroundColor(.yellow)
            Text("Best: \(bestScore)").font(.subheadline).foregroundColor(.white.opacity(0.7))
            Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))").foregroundColor(.white.opacity(0.7)).font(.subheadline)
            Button("PLAY AGAIN") {
                resetGame()
                phase = .aiming
            }
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1))
            .foregroundColor(.white).font(.headline)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let laneTop: CGFloat = 80
            let pinAreaY = laneTop + 50
            let ballStartY = laneTop + laneHeight - 40

            ZStack {
                // Score panel
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame \(frame)/5 · Roll \(roll)/2").foregroundColor(.white.opacity(0.8)).font(.subheadline)
                    Text("Score: \(totalScore)").foregroundColor(.yellow).font(.headline.bold())
                    Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))").foregroundColor(.white.opacity(0.6)).font(.caption)
                }
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .position(x: geo.size.width / 2, y: 46)

                // Lane
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [Color(red: 0.9, green: 0.82, blue: 0.6), Color(red: 0.75, green: 0.65, blue: 0.42)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 190, height: laneHeight)
                    .position(x: cx, y: laneTop + laneHeight / 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(.white.opacity(0.2), lineWidth: 1)
                            .frame(width: 190, height: laneHeight)
                            .position(x: cx, y: laneTop + laneHeight / 2)
                    )

                // Pins
                ForEach(pins) { pin in
                    if pin.isStanding {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: pinRadius * 2, height: pinRadius * 2)
                            .overlay(Circle().stroke(Color.red.opacity(0.8), lineWidth: 3))
                            .position(x: cx + pin.position.x, y: pinAreaY + pin.position.y)
                    }
                }

                // Ball
                if ballVisible {
                    Circle()
                        .fill(
                            RadialGradient(colors: [.gray, .black], center: .topLeading, startRadius: 2, endRadius: 20)
                        )
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                        .position(x: ballX, y: ballY)
                }

                // Message overlay
                if !frameMessage.isEmpty {
                    Text(frameMessage)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.yellow.opacity(0.5), lineWidth: 1))
                        .position(x: cx, y: laneTop + laneHeight / 2)
                }

                // Gesture layer
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(width: geo.size.width, height: geo.size.height)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                guard phase == .aiming else { return }
                                let clampedX = max(cx - 75, min(cx + 75, cx + value.translation.width))
                                ballX = clampedX
                                ballY = ballStartY
                                ballVisible = true
                            }
                            .onEnded { value in
                                guard phase == .aiming else { return }
                                let dy = value.startLocation.y - value.location.y
                                if dy > 20 {
                                    phase = .rolling
                                    animateBall(startY: ballStartY, targetY: pinAreaY, cx: cx, pinAreaY: pinAreaY)
                                }
                            }
                    )
            }
            .onAppear {
                ballX = cx
                ballY = ballStartY
                ballVisible = false
            }
        }
    }

    func animateBall(startY: CGFloat, targetY: CGFloat, cx: CGFloat, pinAreaY: CGFloat) {
        withAnimation(.linear(duration: animDuration)) {
            ballY = targetY
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animDuration) {
            var count = 0
            for i in pins.indices {
                if pins[i].isStanding {
                    let px = cx + pins[i].position.x
                    let py = pinAreaY + pins[i].position.y
                    let dist = hypot(ballX - px, ballY - py)
                    if dist < ballRadius + hitRadius {
                        pins[i].isStanding = false
                        count += 1
                    }
                }
            }
            scores.append(count)
            let gotStrike = count == 10 && roll == 1
            let gotSpare = roll == 2 && pins.filter { !$0.isStanding }.count == 10
            recentResults.append(count >= 5)
            if recentResults.count > 5 { recentResults.removeFirst() }
            if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
            }
            advanceRoll(strike: gotStrike, spare: gotSpare)
        }
    }

    func advanceRoll(strike: Bool, spare: Bool) {
        let standing = pins.filter { $0.isStanding }.count
        if strike {
            frameMessage = "STRIKE!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextFrame() }
        } else if roll == 2 {
            frameMessage = spare ? "SPARE!" : (standing == 10 ? "GUTTER!" : "")
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
            bestScore = max(bestScore, totalScore)
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
        recentResults = []
        difficultyMultiplier = 1.0
    }
}

#Preview { BowlingView() }

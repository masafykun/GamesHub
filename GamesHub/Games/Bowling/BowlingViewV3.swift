import SwiftUI

// MARK: - LCG Seeded Random

struct BwlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

struct BwlV3Pin: Identifiable {
    let id: Int
    var position: CGPoint
    var isStanding: Bool = true
    var wobble: Double = 0
}

enum BwlV3Phase {
    case start, aiming, rolling, result, gameOver
}

// MARK: - V3 View (Neumorphism + Seeded Procedural)

struct BowlingViewV3: View {
    @State private var pins: [BwlV3Pin] = []
    @State private var phase: BwlV3Phase = .start
    @State private var ballX: CGFloat = 0
    @State private var ballY: CGFloat = 0
    @State private var ballVisible: Bool = false
    @State private var frame: Int = 1
    @State private var roll: Int = 1
    @State private var scores: [Int] = []
    @State private var frameMessage: String = ""
    @State private var seedInt: Int = 1
    @State private var lcg: BwlLCG = BwlLCG(seed: 1)
    @State private var aimOffset: CGFloat = 0
    @State private var windOffset: CGFloat = 0

    private let pinRadius: CGFloat = 12
    private let ballRadius: CGFloat = 18
    private let laneHeight: CGFloat = 400

    var totalScore: Int { scores.reduce(0, +) }

    func makePins(with rng: inout BwlLCG) -> [BwlV3Pin] {
        let rows: [[Int]] = [[0], [1, 2], [3, 4, 5], [6, 7, 8, 9]]
        var result: [BwlV3Pin] = []
        let spacing: CGFloat = 34
        for (r, row) in rows.enumerated() {
            for (c, id) in row.enumerated() {
                let jitterX = CGFloat(rng.nextDouble() * 4 - 2)
                let jitterY = CGFloat(rng.nextDouble() * 4 - 2)
                let x = CGFloat(c) * spacing - CGFloat(row.count - 1) * spacing / 2 + jitterX
                let y = CGFloat(r) * spacing + jitterY
                result.append(BwlV3Pin(id: id, position: CGPoint(x: x, y: y)))
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
            Text("BOWLING")
                .font(.system(size: 40, weight: .black))
                .foregroundColor(Color(.label))

            Text("Drag horizontally to aim\nSwipe up to throw\nPins have seeded randomness!")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))

            Button("START GAME") {
                seedInt = 1
                startNewGame()
            }
            .padding(.horizontal, 44).padding(.vertical, 16)
            .neumorphicCard(radius: 14)
            .foregroundColor(Color(.label))
            .font(.headline)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("GAME OVER")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color(.label))

            Text("Total Score: \(totalScore)")
                .font(.title2.bold())
                .foregroundColor(.orange)

            Text("Final Seed: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button("PLAY AGAIN") {
                seedInt += 1
                startNewGame()
            }
            .padding(.horizontal, 40).padding(.vertical, 14)
            .neumorphicCard(radius: 14)
            .foregroundColor(Color(.label))
            .font(.headline)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let laneTop: CGFloat = 80
            let pinAreaY = laneTop + 50
            let ballStartY = laneTop + laneHeight - 40

            ZStack {
                // Info panel
                VStack(alignment: .leading, spacing: 4) {
                    Text("Frame \(frame)/5  Roll \(roll)/2")
                        .font(.subheadline)
                        .foregroundColor(Color(.secondaryLabel))
                    Text("Score: \(totalScore)")
                        .font(.headline.bold())
                        .foregroundColor(.orange)
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                    if !frameMessage.isEmpty {
                        Text(frameMessage).font(.subheadline.bold()).foregroundColor(.orange)
                    }
                }
                .padding(14)
                .neumorphicCard(radius: 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .position(x: geo.size.width / 2, y: 52)

                // Lane background
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.systemGray5))
                    .frame(width: 190, height: laneHeight)
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.9), radius: 8, x: -4, y: -4)
                    .position(x: cx, y: laneTop + laneHeight / 2)

                // Lane stripes
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray4).opacity(0.5))
                        .frame(width: 4, height: laneHeight - 40)
                        .position(x: cx - 60 + CGFloat(i) * 20, y: laneTop + laneHeight / 2)
                }

                // Pins
                ForEach(pins) { pin in
                    if pin.isStanding {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.9), radius: 4, x: -2, y: -2)
                            Circle()
                                .stroke(Color.red.opacity(0.7), lineWidth: 3)
                                .padding(3)
                        }
                        .frame(width: pinRadius * 2, height: pinRadius * 2)
                        .position(x: cx + pin.position.x, y: pinAreaY + pin.position.y)
                    } else {
                        Circle()
                            .fill(Color(.systemGray4).opacity(0.3))
                            .frame(width: pinRadius * 2, height: pinRadius * 2)
                            .position(x: cx + pin.position.x, y: pinAreaY + pin.position.y)
                    }
                }

                // Ball
                if ballVisible {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .shadow(color: .black.opacity(0.25), radius: 6, x: 3, y: 3)
                            .shadow(color: .white.opacity(0.85), radius: 6, x: -3, y: -3)
                        Circle()
                            .fill(Color(.systemGray4))
                            .padding(5)
                    }
                    .frame(width: ballRadius * 2, height: ballRadius * 2)
                    .position(x: ballX, y: ballY)
                }

                // Wind indicator
                if phase == .aiming {
                    HStack(spacing: 4) {
                        Image(systemName: windOffset > 0 ? "wind" : "wind")
                            .foregroundColor(Color(.secondaryLabel))
                        Text(windOffset > 0 ? "Wind R" : windOffset < 0 ? "Wind L" : "No Wind")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .padding(8)
                    .neumorphicCard(radius: 10)
                    .position(x: geo.size.width - 60, y: laneTop + laneHeight + 20)
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
        let driftX = ballX + windOffset
        withAnimation(.linear(duration: 0.65)) {
            ballY = targetY
            ballX = max(cx - 75, min(cx + 75, driftX))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            var count = 0
            for i in pins.indices {
                if pins[i].isStanding {
                    let px = cx + pins[i].position.x
                    let py = pinAreaY + pins[i].position.y
                    let dist = hypot(ballX - px, ballY - py)
                    if dist < ballRadius + pinRadius + 10 {
                        pins[i].isStanding = false
                        count += 1
                    }
                }
            }
            scores.append(count)
            let allDown = pins.filter { $0.isStanding }.count == 0
            if roll == 1 && allDown {
                frameMessage = "STRIKE!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextFrame() }
            } else if roll == 2 {
                frameMessage = allDown ? "SPARE!" : ""
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { nextFrame() }
            } else {
                roll = 2
                frameMessage = ""
                ballVisible = false
                generateWindForRoll()
                phase = .aiming
            }
        }
    }

    func generateWindForRoll() {
        let raw = lcg.nextDouble()
        windOffset = CGFloat(raw * 30 - 15)
    }

    func nextFrame() {
        if frame >= 5 {
            phase = .gameOver
        } else {
            frame += 1
            roll = 1
            frameMessage = ""
            pins = makePins(with: &lcg)
            generateWindForRoll()
            ballVisible = false
            phase = .aiming
        }
    }

    func startNewGame() {
        lcg = BwlLCG(seed: seedInt)
        pins = makePins(with: &lcg)
        frame = 1
        roll = 1
        scores = []
        frameMessage = ""
        ballVisible = false
        generateWindForRoll()
        phase = .aiming
    }
}

#Preview { BowlingViewV3() }

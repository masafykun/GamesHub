import SwiftUI

struct BlBlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum BlBlV3GamePhase {
    case start, playing, gameOver
}

struct BlBlWindGust {
    let direction: Double
    let strength: Double
    let duration: Double
    var elapsed: Double = 0
}

struct BalanceBallViewV3: View {
    @State private var phase: BlBlV3GamePhase = .start
    @State private var platformAngle: Double = 0.0
    @State private var ballX: Double = 0.0
    @State private var ballVelocity: Double = 0.0
    @State private var lives: Int = 3
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var rng: BlBlLCG = BlBlLCG(seed: 1)
    @State private var windGust: BlBlWindGust? = nil
    @State private var nextGustIn: Double = 0
    @State private var platformOffset: Double = 0
    @State private var ballColor: Color = .orange

    let platformWidth: Double = 240
    let platformHeight: Double = 16
    let ballRadius: Double = 14
    let tiltAngle: Double = 12.0
    let gravity: Double = 0.55

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                if phase == .start {
                    startScreen
                } else if phase == .playing {
                    gameScreen(geo: geo)
                } else {
                    gameOverScreen
                }
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BALANCE BALL")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(Color(.label))

            Text("Tap left/right to tilt the platform.\nWatch out for wind gusts!")
                .font(.body)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button(action: startGame) {
                Text("START")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
            }
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.red)

            Text("Score: \(score)")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(Color(.label))

            Text("SEED: #\(seedInt - 1)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
            }
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Tap zones
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tiltLeft() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tiltRight() }
            }

            // HUD
            VStack {
                HStack {
                    // Lives
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < lives ? Color.red.opacity(0.8) : Color(.systemGray4))
                                .frame(width: 14, height: 14)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 12)

                    Spacer()

                    // Score
                    Text("\(score)")
                        .font(.title2.bold())
                        .foregroundColor(Color(.label))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .neumorphicCard(radius: 12)
                }
                .padding()

                // Seed display
                HStack {
                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(.tertiaryLabel))
                    Spacer()
                    // Wind indicator
                    if let gust = windGust {
                        HStack(spacing: 4) {
                            Text(gust.direction > 0 ? "WIND ▶" : "◀ WIND")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .neumorphicCard(radius: 8)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }

            // Platform and ball
            VStack {
                Spacer()
                ZStack {
                    // Ball
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [ballColor.opacity(0.9), ballColor.opacity(0.5)],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: ballRadius * 2
                            )
                        )
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: ballColor.opacity(0.3), radius: 4, x: 2, y: 2)
                        .offset(x: ballX, y: -(platformHeight / 2 + ballRadius))

                    // Platform
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: platformWidth, height: platformHeight)
                        .shadow(color: Color.black.opacity(0.18), radius: 5, x: 4, y: 4)
                        .shadow(color: Color.white.opacity(0.85), radius: 5, x: -4, y: -4)
                }
                .rotationEffect(.degrees(platformAngle))
                .offset(x: platformOffset)
                Spacer().frame(height: geo.size.height * 0.25)
            }

            // Tap hints
            VStack {
                Spacer()
                HStack {
                    Text("◀ Tilt")
                        .foregroundColor(Color(.tertiaryLabel))
                        .font(.caption)
                    Spacer()
                    Text("Tilt ▶")
                        .foregroundColor(Color(.tertiaryLabel))
                        .font(.caption)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    func startGame() {
        ballX = 0
        ballVelocity = 0
        platformAngle = 0
        platformOffset = 0
        windGust = nil
        lives = 3
        score = 0
        rng = BlBlLCG(seed: seedInt)

        // Use LCG to pick ball color
        let colorIndex = rng.nextInt(4)
        ballColor = [Color.orange, Color.purple, Color.green, Color.cyan][colorIndex]

        // Use LCG to set first gust timing
        nextGustIn = Double(rng.nextInt(8) + 5)

        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            updatePhysics()
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if phase == .playing {
                score += 1
            } else {
                t.invalidate()
            }
        }
    }

    func tiltLeft() {
        guard phase == .playing else { return }
        platformAngle = -tiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func tiltRight() {
        guard phase == .playing else { return }
        platformAngle = tiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func updatePhysics() {
        let dt = 0.033

        // Wind gust scheduling
        nextGustIn -= dt
        if nextGustIn <= 0 && windGust == nil {
            let dir = rng.nextInt(2) == 0 ? -1.0 : 1.0
            let strength = (rng.nextDouble() * 0.3 + 0.15)
            let duration = Double(rng.nextInt(3) + 2)
            windGust = BlBlWindGust(direction: dir, strength: strength, duration: duration)
            nextGustIn = Double(rng.nextInt(10) + 6)
        }

        // Apply wind
        var windAccel = 0.0
        if var gust = windGust {
            windAccel = gust.direction * gust.strength
            gust.elapsed += dt
            if gust.elapsed >= gust.duration {
                windGust = nil
            } else {
                windGust = gust
            }
        }

        // Ball physics
        let angleRad = platformAngle * .pi / 180.0
        let gravityAccel = gravity * sin(angleRad)
        ballVelocity += gravityAccel + windAccel
        ballVelocity *= 0.98
        ballX += ballVelocity

        let halfPlatform = platformWidth / 2 - ballRadius
        if abs(ballX) > halfPlatform {
            ballFell()
        }
    }

    func ballFell() {
        ballX = 0
        ballVelocity = 0
        platformAngle = 0
        windGust = nil

        lives -= 1
        if lives <= 0 {
            gameTimer?.invalidate()
            seedInt += 1
            phase = .gameOver
        }
    }
}

#Preview { BalanceBallViewV3() }

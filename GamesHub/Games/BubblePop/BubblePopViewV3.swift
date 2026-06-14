import SwiftUI

struct BbPLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct BbPBubbleV3: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let speed: CGFloat
    let radius: CGFloat
    let wobblePhase: Double
}

enum BbPPhaseV3 {
    case start, playing, gameOver
}

struct BubblePopViewV3: View {
    @State private var bubbles: [BbPBubbleV3] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var phase: BbPPhaseV3 = .start
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var lcg: BbPLCG = BbPLCG(seed: 1)
    @State private var tick: Int = 0

    let bubbleColors: [Color] = [
        Color(red: 0.9, green: 0.3, blue: 0.3),
        Color(red: 0.9, green: 0.6, blue: 0.2),
        Color(red: 0.3, green: 0.7, blue: 0.4),
        Color(red: 0.3, green: 0.5, blue: 0.9),
        Color(red: 0.7, green: 0.3, blue: 0.85),
        Color(red: 0.9, green: 0.4, blue: 0.65)
    ]

    var spawnInterval: TimeInterval {
        max(0.4, 1.3 - Double(score) * 0.025)
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BubblePop")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))

            Text("Tap bubbles before\nthey float away!")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 22)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { bubble in
                    bubbleView(bubble)
                        .position(x: bubble.x, y: bubble.y)
                        .onTapGesture {
                            popBubble(id: bubble.id)
                        }
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCORE")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(.tertiaryLabel))
                            Text("\(score)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(.label))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 14)
                        .padding(.leading)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("LIVES")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(.tertiaryLabel))
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { i in
                                    Circle()
                                        .fill(i < lives ? Color.red.opacity(0.75) : Color(.systemGray4))
                                        .frame(width: 10, height: 10)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .neumorphicCard(radius: 14)
                        .padding(.trailing)
                    }
                    .padding(.top, 8)

                    Spacer()

                    HStack {
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(Color(.tertiaryLabel))
                            .padding(.bottom, 8)
                            .padding(.leading, 16)
                        Spacer()
                    }
                }
            }
            .onAppear { scheduleTimers(in: geo.size) }
            .onDisappear { stopTimers() }
        }
    }

    func bubbleView(_ bubble: BbPBubbleV3) -> some View {
        let wobble = sin(Double(tick) * 0.06 + bubble.wobblePhase) * 3.0
        return ZStack {
            Circle()
                .fill(bubble.color.opacity(0.85))
                .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                .shadow(color: bubble.color.opacity(0.3), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .clear],
                        center: UnitPoint(x: 0.35, y: 0.3),
                        startRadius: 1,
                        endRadius: bubble.radius
                    )
                )
                .frame(width: bubble.radius * 2, height: bubble.radius * 2)
        }
        .offset(x: wobble)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))

            VStack(spacing: 6) {
                Text("FINAL SCORE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(.tertiaryLabel))
                Text("\(score)")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
            }
            .padding(.vertical, 8)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))

            VStack(spacing: 14) {
                Button(action: startGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundColor(Color(.label))
                        .frame(width: 180)
                        .padding(.vertical, 14)
                        .neumorphicCard(radius: 14)
                }
                Button(action: { phase = .start }) {
                    Text("Menu")
                        .foregroundColor(Color(.secondaryLabel))
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(36)
        .neumorphicCard(radius: 20)
        .padding(40)
    }

    func startGame() {
        bubbles = []
        score = 0
        lives = 3
        seedInt += 1
        lcg = BbPLCG(seed: seedInt)
        tick = 0
        phase = .playing
    }

    func scheduleTimers(in size: CGSize) {
        stopTimers()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnBubble(in: size)
        }
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
            tick += 1
            moveBubbles(in: size)
        }
    }

    func stopTimers() {
        spawnTimer?.invalidate()
        spawnTimer = nil
        moveTimer?.invalidate()
        moveTimer = nil
    }

    func spawnBubble(in size: CGSize) {
        let radius = CGFloat(lcg.nextDouble() * 18 + 18)
        let x = CGFloat(lcg.nextDouble()) * (size.width - radius * 2) + radius
        let speed = CGFloat(lcg.nextDouble() * 2.0 + 1.5)
        let colorIndex = lcg.nextInt(bubbleColors.count)
        let color = bubbleColors[colorIndex]
        let wobblePhase = lcg.nextDouble() * .pi * 2
        let bubble = BbPBubbleV3(
            x: x, y: size.height + radius,
            color: color, speed: speed,
            radius: radius, wobblePhase: wobblePhase
        )
        bubbles.append(bubble)

        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnBubble(in: size)
        }
    }

    func moveBubbles(in size: CGSize) {
        var missCount = 0
        for i in bubbles.indices {
            bubbles[i].y -= bubbles[i].speed
            if bubbles[i].y + bubbles[i].radius < 0 {
                missCount += 1
            }
        }
        if missCount > 0 {
            bubbles.removeAll { $0.y + $0.radius < 0 }
            lives = max(0, lives - missCount)
        }
        if lives <= 0 {
            stopTimers()
            phase = .gameOver
        }
    }

    func popBubble(id: UUID) {
        bubbles.removeAll { $0.id == id }
        score += 1
    }
}

#Preview { BubblePopViewV3() }

import SwiftUI

enum IfHpV3Phase { case start, playing, over }

struct IfHpV3Platform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 14
}

struct IfHpLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct InfinityHopViewV3: View {
    @State private var phase: IfHpV3Phase = .start
    @State private var playerX: CGFloat = 0.5
    @State private var playerY: CGFloat = 0.6
    @State private var platforms: [IfHpV3Platform] = []
    @State private var score: Int = 0
    @State private var velocityX: CGFloat = 0
    @State private var velocityY: CGFloat = 0
    @State private var timer: Timer?
    @State private var highScore: Int = 0
    @State private var seedInt: Int = 1
    @State private var lcg: IfHpLCG = IfHpLCG(seed: 1)

    private let gravity: CGFloat = 0.018
    private let hopStrength: CGFloat = -0.032
    private let scrollSpeed: CGFloat = 0.003
    private let horizontalSpeed: CGFloat = 0.035

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                if phase == .start {
                    startScreen
                } else if phase == .playing {
                    gameScreen(geo: geo)
                } else {
                    overScreen
                }
            }
        }
    }

    private var startScreen: some View {
        VStack(spacing: 28) {
            Text("INFINITY HOP")
                .font(.largeTitle.bold())
                .foregroundColor(Color(.label))

            Text("Tap left or right to hop\nonto platforms")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Text("High Score: \(highScore)")
                    .font(.headline)
                    .foregroundColor(Color(.label))
                Text("SEED: #\(seedInt)")
                    .font(.caption)
                    .monospaced()
                    .foregroundColor(Color(.tertiaryLabel))
            }

            Button("START") { startGame() }
                .font(.title2.bold())
                .foregroundColor(Color(.label))
                .padding(.horizontal, 44).padding(.vertical, 14)
                .neumorphicCard(radius: 22)
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(40)
    }

    private func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(platforms) { p in
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(.systemGray6))
                    .frame(width: p.width * geo.size.width, height: p.height)
                    .neumorphicCard(radius: 7)
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }

            Circle()
                .fill(Color(.systemIndigo))
                .frame(width: 32, height: 32)
                .shadow(color: Color(.systemIndigo).opacity(0.4), radius: 6, x: 3, y: 3)
                .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                .position(x: playerX * geo.size.width, y: playerY * geo.size.height)

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCORE")
                            .font(.caption)
                            .foregroundColor(Color(.secondaryLabel))
                        Text("\(score)")
                            .font(.title.bold())
                            .foregroundColor(Color(.label))
                    }
                    .padding(12)
                    .neumorphicCard(radius: 12)
                    .padding()

                    Spacer()

                    Text("SEED: #\(seedInt)")
                        .font(.caption)
                        .monospaced()
                        .foregroundColor(Color(.tertiaryLabel))
                        .padding(.trailing)
                }
                Spacer()
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    hop(left: value.location.x < geo.size.width / 2)
                })
        }
    }

    private var overScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER")
                .font(.largeTitle.bold())
                .foregroundColor(Color(.label))

            VStack(spacing: 8) {
                Text("Score: \(score)")
                    .font(.title2.bold())
                    .foregroundColor(Color(.systemIndigo))
                Text("Best: \(highScore)")
                    .font(.headline)
                    .foregroundColor(Color(.secondaryLabel))
                Text("SEED: #\(seedInt)")
                    .font(.caption)
                    .monospaced()
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            VStack(spacing: 12) {
                Button("PLAY AGAIN") { startGame() }
                    .font(.title2.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .neumorphicCard(radius: 22)

                Button("MENU") { phase = .start }
                    .font(.headline)
                    .foregroundColor(Color(.secondaryLabel))
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(40)
    }

    private func startGame() {
        seedInt += 1
        lcg = IfHpLCG(seed: seedInt)
        score = 0
        playerX = 0.5
        playerY = 0.6
        velocityX = 0
        velocityY = 0
        platforms = []
        for i in 0..<8 {
            let px = CGFloat(lcg.nextDouble()) * 0.6 + 0.2
            platforms.append(IfHpV3Platform(x: px, y: CGFloat(i) * 0.14 + 0.2, width: 0.35))
        }
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in tick() }
    }

    private func hop(left: Bool) {
        velocityX = left ? -horizontalSpeed : horizontalSpeed
        velocityY = hopStrength
    }

    private func tick() {
        guard phase == .playing else { timer?.invalidate(); return }

        velocityY += gravity
        playerX += velocityX
        playerY += velocityY
        velocityX *= 0.92
        playerX = max(0.02, min(0.98, playerX))

        for i in platforms.indices { platforms[i].y += scrollSpeed }
        platforms.removeAll { $0.y > 1.1 }

        while platforms.count < 8 {
            let minX = 0.15
            let maxX = 0.85
            let px = CGFloat(lcg.nextDouble()) * CGFloat(maxX - minX) + CGFloat(minX)
            let w = max(0.12, 0.35 - CGFloat(score) * 0.004)
            platforms.append(IfHpV3Platform(x: px, y: -0.05, width: w))
        }

        checkLanding()
        if playerY > 1.05 { endGame() }
    }

    private func checkLanding() {
        guard velocityY > 0 else { return }
        for p in platforms {
            let left = p.x - p.width / 2
            let right = p.x + p.width / 2
            let top = p.y - 0.012
            let bottom = p.y + 0.012
            if playerX > left && playerX < right && playerY + 0.025 > top && playerY + 0.025 < bottom + 0.02 {
                playerY = top - 0.025
                velocityY = 0
                score += 1
                return
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        if score > highScore { highScore = score }
        phase = .over
    }
}

#Preview { InfinityHopViewV3() }

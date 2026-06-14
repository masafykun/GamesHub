import SwiftUI

// MARK: - LCG Seeded RNG
struct TWClLCG {
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
struct TWClV3Platform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var colorIndex: Int
    let height: CGFloat = 14
}

enum TWClV3Phase {
    case start, playing, gameOver
}

// MARK: - TowerClimbViewV3
struct TowerClimbViewV3: View {
    @State private var phase: TWClV3Phase = .start
    @State private var playerX: CGFloat = 0
    @State private var playerY: CGFloat = 0
    @State private var playerVX: CGFloat = 0
    @State private var playerVY: CGFloat = 0
    @State private var platforms: [TWClV3Platform] = []
    @State private var score: Int = 0
    @State private var highScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var screenSize: CGSize = .zero
    @State private var seedInt: Int = 1
    @State private var rng: TWClLCG = TWClLCG(seed: 1)

    let playerSize: CGFloat = 26
    let gravity: CGFloat = 0.45
    let scrollSpeed: CGFloat = 1.5
    let jumpPower: CGFloat = -11.0

    let platformColors: [Color] = [
        Color(red: 0.55, green: 0.7, blue: 0.9),
        Color(red: 0.65, green: 0.8, blue: 0.7),
        Color(red: 0.75, green: 0.65, blue: 0.85),
        Color(red: 0.85, green: 0.75, blue: 0.6),
        Color(red: 0.6, green: 0.8, blue: 0.8)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .gameOver:
                    gameOverScreen
                }
            }
            .onAppear { screenSize = geo.size }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 4) {
                Text("TOWER").font(.system(size: 52, weight: .black)).foregroundColor(Color(.label))
                Text("CLIMB").font(.system(size: 52, weight: .black)).foregroundColor(Color(.secondaryLabel))
            }
            Text("Tap left or right to jump\nonto platforms!").font(.system(size: 16)).foregroundColor(Color(.secondaryLabel)).multilineTextAlignment(.center)
            Button(action: startGame) {
                Text("START").font(.system(size: 22, weight: .bold)).foregroundColor(Color(.label)).padding(.horizontal, 48).padding(.vertical, 14)
            }.neumorphicCard(radius: 28)
            if highScore > 0 {
                Text("Best: \(highScore)").font(.system(size: 14)).foregroundColor(Color(.tertiaryLabel))
            }
            Text("SEED: #\(seedInt)").font(.system(size: 11).monospaced()).foregroundColor(Color(.tertiaryLabel))
        }
    }

    // MARK: - Game Screen
    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Platforms with neumorphic style
            ForEach(platforms) { p in
                RoundedRectangle(cornerRadius: 7)
                    .fill(platformColors[p.colorIndex % platformColors.count])
                    .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                    .shadow(color: Color(.systemGray3).opacity(0.7), radius: 3, x: 2, y: 2)
                    .frame(width: p.width, height: p.height)
                    .position(x: p.x, y: p.y)
            }
            // Player - neumorphic circle
            Circle()
                .fill(Color(.systemGray5))
                .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                .shadow(color: Color(.systemGray3).opacity(0.8), radius: 4, x: 3, y: 3)
                .frame(width: playerSize, height: playerSize)
                .position(x: playerX, y: playerY)
            // Score + seed display
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(score)").font(.system(size: 36, weight: .black)).foregroundColor(Color(.label))
                        Text("SEED: #\(seedInt)").font(.system(size: 10).monospaced()).foregroundColor(Color(.tertiaryLabel))
                    }.padding(14)
                    Spacer()
                }.padding(.top, 50).padding(.leading, 20)
                Spacer()
            }
            // Tap zones
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: true) }
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: false) }
            }
        }
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 40, weight: .black)).foregroundColor(Color(.label))
            VStack(spacing: 10) {
                Text("Score: \(score)").font(.system(size: 30, weight: .bold)).foregroundColor(Color(.label))
                if score >= highScore && score > 0 {
                    Text("New Best!").font(.system(size: 18, weight: .semibold)).foregroundColor(.green)
                } else if highScore > 0 {
                    Text("Best: \(highScore)").font(.system(size: 15)).foregroundColor(Color(.secondaryLabel))
                }
                Text("SEED: #\(seedInt - 1)").font(.system(size: 11).monospaced()).foregroundColor(Color(.tertiaryLabel))
            }.padding(20)
            .neumorphicCard(radius: 16)
            Button(action: startGame) {
                Text("NEXT SEED").font(.system(size: 20, weight: .bold)).foregroundColor(Color(.label)).padding(.horizontal, 40).padding(.vertical, 13)
            }.neumorphicCard(radius: 24)
        }
    }

    // MARK: - Game Logic
    func startGame() {
        score = 0
        rng = TWClLCG(seed: seedInt)
        playerX = screenSize.width / 2
        playerY = screenSize.height * 0.6
        playerVX = 0; playerVY = 0
        platforms = spawnInitialPlatforms()
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in gameLoop() }
    }

    func spawnInitialPlatforms() -> [TWClV3Platform] {
        var ps: [TWClV3Platform] = []
        let w = screenSize.width; let h = screenSize.height
        ps.append(TWClV3Platform(x: w / 2, y: h * 0.65, width: 120, colorIndex: 0))
        var y = h * 0.65 - 110
        var idx = 1
        while y > -100 {
            let px = CGFloat(rng.nextDouble()) * (w - 120) + 60
            let ci = rng.nextInt(platformColors.count)
            ps.append(TWClV3Platform(x: px, y: y, width: platformWidth(), colorIndex: ci))
            y -= 110; idx += 1
        }
        return ps
    }

    func platformWidth() -> CGFloat { max(36, 120 - CGFloat(score) * 1.5) }

    func doJump(left: Bool) {
        guard phase == .playing else { return }
        playerVX = left ? -7.0 : 7.0
        playerVY = jumpPower
    }

    func gameLoop() {
        guard phase == .playing else { return }
        let w = screenSize.width; let h = screenSize.height
        playerVY += gravity
        playerX += playerVX; playerY += playerVY
        playerVX *= 0.92
        playerX = max(playerSize / 2, min(w - playerSize / 2, playerX))
        for i in platforms.indices { platforms[i].y += scrollSpeed }
        if playerVY > 0 {
            for p in platforms {
                let halfW = p.width / 2 + playerSize / 2
                if abs(playerX - p.x) < halfW - 4 &&
                    playerY + playerSize / 2 >= p.y - p.height / 2 &&
                    playerY + playerSize / 2 <= p.y + p.height / 2 + playerVY + 2 {
                    playerY = p.y - p.height / 2 - playerSize / 2
                    playerVY = 0
                }
            }
        }
        let topY = platforms.map(\.y).min() ?? 0
        if topY > 80 {
            let px = CGFloat(rng.nextDouble()) * (w - 120) + 60
            let ci = rng.nextInt(platformColors.count)
            platforms.append(TWClV3Platform(x: px, y: topY - 110, width: platformWidth(), colorIndex: ci))
        }
        let offScreen = platforms.filter { $0.y > h + 20 }
        score += offScreen.count
        platforms.removeAll { $0.y > h + 20 }
        if playerY > h + 40 { endGame() }
    }

    func endGame() {
        timer?.invalidate(); timer = nil
        if score > highScore { highScore = score }
        seedInt += 1
        phase = .gameOver
    }
}

#Preview { TowerClimbViewV3() }

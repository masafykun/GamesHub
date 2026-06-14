import SwiftUI

// MARK: - Models

struct GravitySwitchV3Obstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var gapY: CGFloat
    var gapHeight: CGFloat
}

enum GravitySwitchV3State {
    case waiting
    case playing
    case dead
}

// MARK: - LCG Helper

struct GravitySwitchV3LCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed < 0 ? 1 : seed + 1)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    // Returns a CGFloat in [0, 1)
    mutating func nextFloat() -> CGFloat {
        return CGFloat(next() >> 11) / CGFloat(1 << 53)
    }

    // Returns a CGFloat in [lo, hi]
    mutating func nextFloat(in range: ClosedRange<CGFloat>) -> CGFloat {
        return range.lowerBound + nextFloat() * (range.upperBound - range.lowerBound)
    }
}

// MARK: - ViewModel

class GravitySwitchV3ViewModel: ObservableObject {
    @Published var playerY: CGFloat = 0
    @Published var playerVelocityY: CGFloat = 0
    @Published var gravityUp: Bool = false
    @Published var obstacles: [GravitySwitchV3Obstacle] = []
    @Published var score: Int = 0
    @Published var highScore: Int = 0
    @Published var gameState: GravitySwitchV3State = .waiting
    @Published var speed: CGFloat = 150
    @Published var seedInt: Int = 1

    var canvasWidth: CGFloat = 390
    var canvasHeight: CGFloat = 844

    let playerX: CGFloat = 80
    let playerSize: CGFloat = 28
    let obstacleWidth: CGFloat = 22
    let obstacleSpacing: CGFloat = 230
    let baseSpeed: CGFloat = 150
    let gravity: CGFloat = 900
    let flipImpulse: CGFloat = 420

    private var timer: Timer?
    private var distanceTraveled: CGFloat = 0
    private var timePlayed: CGFloat = 0
    private var nextObstacleDistance: CGFloat = 0
    private var lcg: GravitySwitchV3LCG = GravitySwitchV3LCG(seed: 1)
    private var obstacleIndex: Int = 0

    func setup(width: CGFloat, height: CGFloat) {
        canvasWidth = width
        canvasHeight = height
        playerY = height / 2
        obstacles = []
    }

    func startGame(newSeed: Bool = false) {
        if newSeed {
            seedInt += 1
        }
        lcg = GravitySwitchV3LCG(seed: seedInt)
        obstacleIndex = 0

        playerY = canvasHeight / 2
        playerVelocityY = 0
        gravityUp = false
        obstacles = []
        score = 0
        speed = baseSpeed
        distanceTraveled = 0
        timePlayed = 0
        nextObstacleDistance = canvasWidth + 80
        gameState = .playing
        startTimer()
    }

    func flipGravity() {
        guard gameState == .playing else { return }
        gravityUp.toggle()
        playerVelocityY = gravityUp ? -flipImpulse : flipImpulse
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard gameState == .playing else { return }

        let dt: CGFloat = 1.0 / 60.0
        timePlayed += dt

        speed = baseSpeed + timePlayed * 18

        let gravityDir: CGFloat = gravityUp ? -1 : 1
        playerVelocityY += gravityDir * gravity * dt
        playerVelocityY = max(-900, min(900, playerVelocityY))
        playerY += playerVelocityY * dt

        let halfPlayer = playerSize / 2
        if playerY - halfPlayer <= 0 || playerY + halfPlayer >= canvasHeight {
            triggerDeath()
            return
        }

        let dx = speed * dt
        distanceTraveled += dx

        for i in obstacles.indices {
            obstacles[i].x -= dx
        }

        // Spawn obstacles at deterministic positions using LCG
        while distanceTraveled + canvasWidth >= nextObstacleDistance {
            let spawnX = nextObstacleDistance - distanceTraveled + canvasWidth
            spawnObstacle(atX: spawnX)
            nextObstacleDistance += obstacleSpacing
        }

        obstacles.removeAll { $0.x < -obstacleWidth - 10 }

        for obs in obstacles {
            if checkCollision(obs) {
                triggerDeath()
                return
            }
        }

        score = Int(distanceTraveled / 10)
    }

    private func spawnObstacle(atX x: CGFloat) {
        let minGap: CGFloat = 120
        let maxGap: CGFloat = 190
        let gapH = lcg.nextFloat(in: minGap...maxGap)
        let minY = gapH / 2 + 20
        let maxY = canvasHeight - gapH / 2 - 20
        let gapY = lcg.nextFloat(in: minY...maxY)
        obstacles.append(GravitySwitchV3Obstacle(x: x, gapY: gapY, gapHeight: gapH))
        obstacleIndex += 1
    }

    private func checkCollision(_ obs: GravitySwitchV3Obstacle) -> Bool {
        let pLeft = playerX - playerSize / 2
        let pRight = playerX + playerSize / 2
        let pTop = playerY - playerSize / 2
        let pBottom = playerY + playerSize / 2

        let oLeft = obs.x - obstacleWidth / 2
        let oRight = obs.x + obstacleWidth / 2

        guard pRight > oLeft && pLeft < oRight else { return false }

        let topBarBottom = obs.gapY - obs.gapHeight / 2
        let bottomBarTop = obs.gapY + obs.gapHeight / 2

        if pTop < topBarBottom || pBottom > bottomBarTop {
            return true
        }
        return false
    }

    private func triggerDeath() {
        gameState = .dead
        if score > highScore {
            highScore = score
        }
        stopTimer()
    }
}

// MARK: - Main View

struct GravitySwitchViewV3: View {
    @StateObject private var vm = GravitySwitchV3ViewModel()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()

                if vm.gameState == .waiting {
                    GravitySwitchV3StartScreen(seedInt: vm.seedInt)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    vm.setup(width: geo.size.width, height: geo.size.height)
                                    vm.startGame(newSeed: false)
                                }
                        )
                } else {
                    // Game canvas layer
                    GravitySwitchV3Canvas(vm: vm)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    if vm.gameState == .playing {
                                        vm.flipGravity()
                                    }
                                }
                        )

                    // HUD overlay
                    VStack {
                        HStack(alignment: .top) {
                            // Score card
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SCORE")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(.secondaryLabel))
                                Text("\(vm.score)")
                                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Color(.label))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .neumorphicCard(radius: 14)

                            Spacer()

                            // Seed display (prominent)
                            VStack(spacing: 2) {
                                Text("SEED")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(.secondaryLabel))
                                Text("#\(vm.seedInt)")
                                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Color.accentColor)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .neumorphicCard(radius: 14)

                            Spacer()

                            // Best card
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("BEST")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color(.secondaryLabel))
                                Text("\(vm.highScore)")
                                    .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Color(.label))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .neumorphicCard(radius: 14)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Spacer()

                        // Gravity indicator at bottom
                        HStack(spacing: 8) {
                            Image(systemName: vm.gravityUp ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(vm.gravityUp ? Color.blue : Color.orange)
                            Text(vm.gravityUp ? "GRAVITY UP" : "GRAVITY DOWN")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(.secondaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .neumorphicCard(radius: 12)
                        .padding(.bottom, 20)
                    }

                    // Death overlay
                    if vm.gameState == .dead {
                        GravitySwitchV3DeathOverlay(vm: vm)
                    }
                }
            }
            .onAppear {
                canvasSize = geo.size
                vm.setup(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Canvas

struct GravitySwitchV3Canvas: View {
    @ObservedObject var vm: GravitySwitchV3ViewModel

    var body: some View {
        Canvas { ctx, size in
            // Background rails (top & bottom danger zones)
            let ceilRect = CGRect(x: 0, y: 0, width: size.width, height: 4)
            ctx.fill(Path(ceilRect), with: .color(Color(.systemRed).opacity(0.5)))
            let floorRect = CGRect(x: 0, y: size.height - 4, width: size.width, height: 4)
            ctx.fill(Path(floorRect), with: .color(Color(.systemRed).opacity(0.5)))

            // Draw obstacles with neumorphic style
            for obs in vm.obstacles {
                let topBarHeight = obs.gapY - obs.gapHeight / 2
                let bottomBarTop = obs.gapY + obs.gapHeight / 2
                let bottomBarHeight = size.height - bottomBarTop
                let oLeft = obs.x - vm.obstacleWidth / 2

                // Top bar shadow (dark)
                let topShadow = CGRect(x: oLeft + 3, y: 3, width: vm.obstacleWidth, height: topBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: topShadow),
                         with: .color(Color(.systemGray4).opacity(0.7)))

                // Top bar highlight (light)
                let topHighlight = CGRect(x: oLeft - 2, y: -2, width: vm.obstacleWidth, height: topBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: topHighlight),
                         with: .color(Color.white.opacity(0.5)))

                // Top bar main
                let topRect = CGRect(x: oLeft, y: 0, width: vm.obstacleWidth, height: topBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: topRect),
                         with: .color(Color(.systemGray5)))

                // Top edge accent
                let topEdge = CGRect(x: oLeft, y: topBarHeight - 4, width: vm.obstacleWidth, height: 4)
                ctx.fill(Path(topEdge), with: .color(Color(.systemRed).opacity(0.8)))

                // Bottom bar shadow
                let botShadow = CGRect(x: oLeft + 3, y: bottomBarTop + 3, width: vm.obstacleWidth, height: bottomBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: botShadow),
                         with: .color(Color(.systemGray4).opacity(0.7)))

                // Bottom bar highlight
                let botHighlight = CGRect(x: oLeft - 2, y: bottomBarTop - 2, width: vm.obstacleWidth, height: bottomBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: botHighlight),
                         with: .color(Color.white.opacity(0.5)))

                // Bottom bar main
                let botRect = CGRect(x: oLeft, y: bottomBarTop, width: vm.obstacleWidth, height: bottomBarHeight)
                ctx.fill(RoundedRectangle(cornerRadius: 4).path(in: botRect),
                         with: .color(Color(.systemGray5)))

                // Bottom edge accent
                let botEdge = CGRect(x: oLeft, y: bottomBarTop, width: vm.obstacleWidth, height: 4)
                ctx.fill(Path(botEdge), with: .color(Color(.systemRed).opacity(0.8)))
            }

            // Player — neumorphic square
            let pRect = CGRect(
                x: vm.playerX - vm.playerSize / 2,
                y: vm.playerY - vm.playerSize / 2,
                width: vm.playerSize,
                height: vm.playerSize
            )

            // Player shadow (dark, bottom-right)
            let pShadow = pRect.offsetBy(dx: 3, dy: 3)
            ctx.fill(RoundedRectangle(cornerRadius: 7).path(in: pShadow),
                     with: .color(Color(.systemGray4)))

            // Player highlight (light, top-left)
            let pHighlight = pRect.offsetBy(dx: -2, dy: -2)
            ctx.fill(RoundedRectangle(cornerRadius: 7).path(in: pHighlight),
                     with: .color(Color.white.opacity(0.9)))

            // Player body
            ctx.fill(RoundedRectangle(cornerRadius: 6).path(in: pRect),
                     with: .color(Color(.systemGray6)))

            // Player accent color fill (semi-transparent blue tint)
            ctx.fill(RoundedRectangle(cornerRadius: 6).path(in: pRect),
                     with: .color(Color.accentColor.opacity(0.25)))

            // Player inner shine
            let innerRect = pRect.insetBy(dx: 5, dy: 5)
            ctx.fill(RoundedRectangle(cornerRadius: 3).path(in: innerRect),
                     with: .color(Color.white.opacity(0.3)))

            // Gravity direction arrow above/below player
            let arrowOffset: CGFloat = vm.playerSize / 2 + 14
            let arrowY: CGFloat = vm.gravityUp
                ? vm.playerY - arrowOffset
                : vm.playerY + arrowOffset

            let arrowPath = Path { p in
                if vm.gravityUp {
                    p.move(to: CGPoint(x: vm.playerX, y: arrowY - 5))
                    p.addLine(to: CGPoint(x: vm.playerX - 7, y: arrowY + 5))
                    p.addLine(to: CGPoint(x: vm.playerX + 7, y: arrowY + 5))
                    p.closeSubpath()
                } else {
                    p.move(to: CGPoint(x: vm.playerX, y: arrowY + 5))
                    p.addLine(to: CGPoint(x: vm.playerX - 7, y: arrowY - 5))
                    p.addLine(to: CGPoint(x: vm.playerX + 7, y: arrowY - 5))
                    p.closeSubpath()
                }
            }
            ctx.fill(arrowPath, with: .color(Color(.label).opacity(0.4)))
        }
    }
}

// MARK: - Start Screen

struct GravitySwitchV3StartScreen: View {
    let seedInt: Int
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 20) {
                Text("GRAVITY")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(Color(.label))
                + Text(" SWITCH")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(Color.accentColor)
            }
            .multilineTextAlignment(.center)
            .padding(.bottom, 8)

            Text("V3 — PROCEDURAL")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(.secondaryLabel))
                .padding(.bottom, 32)

            // Seed badge
            VStack(spacing: 4) {
                Text("SEED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(.secondaryLabel))
                Text("#\(seedInt)")
                    .font(.system(size: 32, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.accentColor)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .neumorphicCard(radius: 18)
            .padding(.bottom, 32)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(Color(.secondaryLabel))
                    Text("Tap to flip gravity")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.secondaryLabel))
                }
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemRed).opacity(0.7))
                    Text("Avoid the barriers")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color(.secondaryLabel))
                }
            }
            .padding(.bottom, 48)

            Spacer()

            Text("TAP ANYWHERE TO START")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(Color(.label))
                .opacity(pulse ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
                .padding(.bottom, 48)
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Death Overlay

struct GravitySwitchV3DeathOverlay: View {
    @ObservedObject var vm: GravitySwitchV3ViewModel

    var body: some View {
        ZStack {
            Color(.systemGray6).opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(Color(.systemRed))

                // Seed display on death screen
                HStack(spacing: 6) {
                    Text("SEED: #\(vm.seedInt)")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .neumorphicCard(radius: 10)

                VStack(spacing: 10) {
                    VStack(spacing: 2) {
                        Text("SCORE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(.secondaryLabel))
                        Text("\(vm.score)")
                            .font(.system(size: 40, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(.label))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 16)

                    VStack(spacing: 2) {
                        Text("BEST")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(.secondaryLabel))
                        Text("\(vm.highScore)")
                            .font(.system(size: 28, weight: .heavy, design: .monospaced))
                            .foregroundColor(Color(.label))
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .neumorphicCard(radius: 14)
                }

                HStack(spacing: 14) {
                    // Same seed replay
                    Button {
                        vm.startGame(newSeed: false)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20, weight: .bold))
                            Text("RETRY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color(.label))
                        .frame(width: 90, height: 60)
                        .neumorphicCard(radius: 14)
                    }

                    // New seed
                    Button {
                        vm.startGame(newSeed: true)
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 20, weight: .bold))
                            Text("NEW SEED")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color.accentColor)
                        .frame(width: 90, height: 60)
                        .neumorphicCard(radius: 14)
                    }
                }
            }
            .padding(32)
            .neumorphicCard(radius: 24)
            .padding(.horizontal, 28)
        }
    }
}

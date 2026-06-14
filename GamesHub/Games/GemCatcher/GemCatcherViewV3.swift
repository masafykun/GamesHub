import SwiftUI

// MARK: - Models

struct GCV3FallingItem: Identifiable {
    let id = UUID()
    var x: CGFloat      // normalized 0-1
    var y: CGFloat      // normalized 0-1
    var type: GemCatcherItemType
    var speed: CGFloat
    var size: CGFloat   // normalized 0-1
}

extension GemCatcherGemColor {
    var highlightColor: Color {
        switch self {
        case .red:   return Color(red: 1.0, green: 0.5, blue: 0.5)
        case .green: return Color(red: 0.5, green: 1.0, blue: 0.5)
        case .blue:  return Color(red: 0.5, green: 0.8, blue: 1.0)
        }
    }
}

// MARK: - LCG RNG

struct GemCatcherLCG {
    var state: UInt64

    init(seed: Int) {
        var s = UInt64(max(seed, 1))
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    /// Returns a value in [0, 1)
    mutating func nextFloat() -> CGFloat {
        return CGFloat(next() >> 11) / CGFloat(1 << 53)
    }

    /// Returns an Int in [0, n)
    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Main View

struct GemCatcherViewV3: View {

    // MARK: State

    @State private var seedInt: Int = 1
    @State private var rng: GemCatcherLCG = GemCatcherLCG(seed: 1)

    @State private var score: Int = 0
    @State private var timeLeft: Double = 60
    @State private var isPlaying: Bool = false
    @State private var isGameOver: Bool = false

    @State private var basketX: CGFloat = 0.5   // normalized

    @State private var fallingItems: [GCV3FallingItem] = []
    @State private var particles: [GemCatcherParticle] = []

    @State private var gameTimer: Timer? = nil

    // Timing accumulators
    @State private var spawnAccumulator: Double = 0
    @State private var nextSpawnInterval: Double = 1.2

    // Screen geometry captured from GeometryReader
    @State private var screenSize: CGSize = .zero

    // Drag state
    @State private var dragStartBasketX: CGFloat = 0.5

    // Score pop feedback
    @State private var scorePops: [GemCatcherScorePop] = []

    // MARK: Constants
    private let basketWidth: CGFloat = 0.18
    private let basketHeight: CGFloat = 0.045
    private let catchZoneY: CGFloat = 0.88    // normalized Y of basket top
    private let itemBaseSize: CGFloat = 0.06
    private let baseSpeed: CGFloat = 0.18     // normalized units/second

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color(.systemGray6)
                    .ignoresSafeArea()

                if !isPlaying && !isGameOver {
                    startScreen(geo: geo)
                } else {
                    gameplayLayer(geo: geo)
                }

                if isGameOver {
                    gameOverOverlay(geo: geo)
                }
            }
            .onAppear {
                screenSize = geo.size
            }
            .onChange(of: geo.size) { newSize in
                screenSize = newSize
            }
        }
    }

    // MARK: - Start Screen

    private func startScreen(geo: GeometryProxy) -> some View {
        VStack(spacing: 28) {
            Spacer()

            Text("GEM CATCHER")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.primary)

            Text("V3 · Procedural")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)

            VStack(spacing: 10) {
                instructionRow(icon: "diamond.fill",  color: .blue,   text: "Catch gems for +10")
                instructionRow(icon: "xmark.circle.fill", color: .red, text: "Avoid bombs (−30)")
                instructionRow(icon: "arrow.left.arrow.right", color: .purple, text: "Drag basket to move")
            }
            .padding(20)
            .neumorphicCard()

            Spacer()

            Button(action: startGame) {
                Text("START GAME")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.3, blue: 1.0),
                                     Color(red: 0.2, green: 0.6, blue: 1.0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color(red: 0.3, green: 0.4, blue: 1.0).opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private func instructionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 18))
                .frame(width: 28)
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
    }

    // MARK: - Gameplay Layer

    private func gameplayLayer(geo: GeometryProxy) -> some View {
        ZStack {
            // Falling items
            ForEach(fallingItems) { item in
                fallingItemView(item: item, geo: geo)
            }

            // Particles
            ForEach(particles) { p in
                Circle()
                    .fill(p.color)
                    .frame(width: p.size, height: p.size)
                    .position(x: p.x, y: p.y)
                    .opacity(p.opacity)
            }

            // Score pops
            ForEach(scorePops) { pop in
                Text(pop.text)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(pop.color)
                    .position(x: pop.x, y: pop.y)
                    .opacity(pop.opacity)
            }

            // Basket
            basketView(geo: geo)

            // HUD
            VStack(spacing: 0) {
                hudBar(geo: geo)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let normalized = value.location.x / geo.size.width
                    let half = basketWidth / 2
                    basketX = min(max(normalized, half), 1 - half)
                }
        )
    }

    private func fallingItemView(item: GCV3FallingItem, geo: GeometryProxy) -> some View {
        let px = item.x * geo.size.width
        let py = item.y * geo.size.height
        let sz = item.size * min(geo.size.width, geo.size.height)

        return Group {
            switch item.type {
            case .gem(let color):
                gemShape(color: color, size: sz)
            case .bomb:
                bombShape(size: sz)
            }
        }
        .position(x: px, y: py)
    }

    private func gemShape(color: GemCatcherGemColor, size: CGFloat) -> some View {
        ZStack {
            Diamond()
                .fill(
                    LinearGradient(
                        colors: [color.highlightColor, color.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: color.color.opacity(0.5), radius: 6, x: 0, y: 3)

            Diamond()
                .fill(Color.white.opacity(0.25))
                .frame(width: size * 0.45, height: size * 0.45)
                .offset(x: -size * 0.1, y: -size * 0.12)
        }
    }

    private func bombShape(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.8, green: 0.1, blue: 0.1),
                                 Color(red: 0.4, green: 0.0, blue: 0.0)],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.red.opacity(0.5), radius: 6, x: 0, y: 3)

            // Fuse
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(red: 0.6, green: 0.4, blue: 0.1))
                .frame(width: size * 0.12, height: size * 0.3)
                .offset(y: -size * 0.6)

            // Shine
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: size * 0.35, height: size * 0.35)
                .offset(x: -size * 0.15, y: -size * 0.15)

            // Warning symbol
            Text("💣")
                .font(.system(size: size * 0.4))
        }
    }

    private func basketView(geo: GeometryProxy) -> some View {
        let bw = basketWidth * geo.size.width
        let bh = basketHeight * geo.size.height
        let bx = basketX * geo.size.width
        let by = catchZoneY * geo.size.height + bh / 2

        return ZStack {
            // Body
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.55, green: 0.4, blue: 1.0),
                                 Color(red: 0.3, green: 0.2, blue: 0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: bw, height: bh)
                .shadow(color: Color.purple.opacity(0.4), radius: 8, x: 0, y: 4)

            // Inner groove (neumorphic inset)
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.white.opacity(0.15))
                .frame(width: bw - 10, height: bh - 6)

            // Rim highlight
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                .frame(width: bw, height: bh)
        }
        .position(x: bx, y: by)
    }

    private func hudBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 12) {
            // Score
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("\(score)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .animation(.none, value: score)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 12)

            // Seed
            VStack(spacing: 2) {
                Text("SEED")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text("#\(seedInt)")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.4, green: 0.3, blue: 1.0))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 12)

            // Timer
            VStack(spacing: 2) {
                Text("TIME")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Text(String(format: "%02d", Int(ceil(timeLeft))))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(timeLeft < 10 ? .red : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .neumorphicCard(radius: 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Game Over Overlay

    private func gameOverOverlay(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                VStack(spacing: 8) {
                    Text("FINAL SCORE")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text("\(score)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(score >= 0 ? Color(red: 0.3, green: 0.8, blue: 0.4) : .red)

                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.4, green: 0.3, blue: 1.0))
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .neumorphicCard()

                Button(action: restartGame) {
                    Text("PLAY AGAIN")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.4, green: 0.3, blue: 1.0),
                                         Color(red: 0.2, green: 0.6, blue: 1.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: Color.purple.opacity(0.35), radius: 8, x: 0, y: 4)
                }

                Button(action: goToMenu) {
                    Text("Main Menu")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .neumorphicCard(radius: 24)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        rng = GemCatcherLCG(seed: seedInt)
        score = 0
        timeLeft = 60
        fallingItems = []
        particles = []
        scorePops = []
        spawnAccumulator = 0
        nextSpawnInterval = 1.2
        basketX = 0.5
        isPlaying = true
        isGameOver = false
        scheduleNextSpawn()
        startGameLoop()
    }

    private func restartGame() {
        stopGameLoop()
        seedInt += 1
        isGameOver = false
        isPlaying = false
        startGame()
    }

    private func goToMenu() {
        stopGameLoop()
        isPlaying = false
        isGameOver = false
        fallingItems = []
        particles = []
        scorePops = []
    }

    private func startGameLoop() {
        stopGameLoop()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame(dt: 1.0 / 60.0)
        }
        RunLoop.main.add(t, forMode: .common)
        gameTimer = t
    }

    private func stopGameLoop() {
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func scheduleNextSpawn() {
        // Determine interval: starts at 1.2s, decreases toward 0.5s as time elapses
        let elapsed = 60.0 - timeLeft
        let rawInterval = max(0.5, 1.2 - elapsed * 0.01)
        nextSpawnInterval = rawInterval
    }

    private func spawnItem() {
        // Use LCG to determine type and position
        let typeRoll = rng.nextInt(10)   // 0-9; 0-1 = bomb, 2-9 = gem
        let xRaw = rng.nextFloat()
        let speedRaw = rng.nextFloat()
        let sizeRaw = rng.nextFloat()

        let elapsed = 60.0 - timeLeft
        let difficulty = min(elapsed / 60.0, 1.0)

        let speed = baseSpeed + CGFloat(difficulty) * 0.18 + speedRaw * 0.06
        let size = itemBaseSize * (0.85 + sizeRaw * 0.35)
        let margin: CGFloat = 0.05
        let x = margin + xRaw * (1.0 - 2 * margin)

        let isBomb = typeRoll < 2
        let type: GemCatcherItemType
        if isBomb {
            type = .bomb
        } else {
            let colorIdx = rng.nextInt(GemCatcherGemColor.allCases.count)
            let color = GemCatcherGemColor.allCases[colorIdx]
            type = .gem(color)
        }

        let item = GCV3FallingItem(x: x, y: -size, type: type, speed: speed, size: size)
        fallingItems.append(item)
    }

    private func updateGame(dt: Double) {
        guard isPlaying && !isGameOver else { return }

        // Countdown
        timeLeft -= dt
        if timeLeft <= 0 {
            timeLeft = 0
            endGame()
            return
        }

        // Spawn accumulation
        spawnAccumulator += dt
        if spawnAccumulator >= nextSpawnInterval {
            spawnAccumulator = 0
            spawnItem()
            scheduleNextSpawn()
        }

        // Move items
        let screenH = screenSize.height > 0 ? screenSize.height : 750.0
        let screenW = screenSize.width > 0 ? screenSize.width : 390.0

        var toRemove: [UUID] = []

        for i in fallingItems.indices {
            fallingItems[i].y += fallingItems[i].speed * CGFloat(dt)

            let item = fallingItems[i]
            let itemPxX = item.x * screenW
            let itemPxY = item.y * screenH
            let itemRadius = item.size * min(screenW, screenH) / 2

            // Check catch
            let basketPxX = basketX * screenW
            let basketPxY = catchZoneY * screenH
            let bw2 = basketWidth * screenW / 2
            let bh = basketHeight * screenH

            let hitX = abs(itemPxX - basketPxX) < (bw2 + itemRadius * 0.5)
            let hitY = itemPxY + itemRadius >= basketPxY && itemPxY - itemRadius < basketPxY + bh

            if hitX && hitY {
                toRemove.append(item.id)
                handleCatch(item: item, atX: itemPxX, atY: itemPxY)
            } else if item.y > 1.1 {
                // Missed
                toRemove.append(item.id)
                if case .gem = item.type {
                    score -= 5
                    spawnScorePop("-5", color: .orange, x: itemPxX, y: screenH - 40)
                }
            }
        }

        fallingItems.removeAll { toRemove.contains($0.id) }

        // Update particles
        for i in particles.indices {
            particles[i].x += particles[i].vx * CGFloat(dt)
            particles[i].y += particles[i].vy * CGFloat(dt)
            particles[i].vy += 300 * CGFloat(dt) // gravity
            particles[i].opacity -= CGFloat(dt) * 2.2
            particles[i].size -= CGFloat(dt) * 8
        }
        particles.removeAll { $0.opacity <= 0 || $0.size <= 0 }

        // Update score pops
        for i in scorePops.indices {
            scorePops[i].y -= CGFloat(dt) * 60
            scorePops[i].opacity -= CGFloat(dt) * 1.5
        }
        scorePops.removeAll { $0.opacity <= 0 }
    }

    private func handleCatch(item: GCV3FallingItem, atX: CGFloat, atY: CGFloat) {
        switch item.type {
        case .gem(let color):
            score += 10
            spawnParticles(at: atX, y: atY, color: color.color, count: 12)
            spawnScorePop("+10", color: color.color, x: atX, y: atY)
        case .bomb:
            score -= 30
            spawnParticles(at: atX, y: atY, color: .red, count: 16)
            spawnScorePop("-30", color: .red, x: atX, y: atY)
        }
    }

    private func endGame() {
        stopGameLoop()
        isPlaying = false
        isGameOver = true
        fallingItems = []
    }

    // MARK: - Particles & Pops

    private func spawnParticles(at x: CGFloat, y: CGFloat, color: Color, count: Int) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0 ..< .pi * 2)
            let speed = CGFloat.random(in: 60 ... 200)
            let p = GemCatcherParticle(
                x: x, y: y,
                vx: cos(angle) * speed,
                vy: sin(angle) * speed - 80,
                color: color,
                size: CGFloat.random(in: 4...10),
                opacity: 1.0
            )
            particles.append(p)
        }
    }

    private func spawnScorePop(_ text: String, color: Color, x: CGFloat, y: CGFloat) {
        let pop = GemCatcherScorePop(text: text, color: color, x: x, y: y, opacity: 1.0)
        scorePops.append(pop)
    }
}

// MARK: - Supporting Models

struct GemCatcherParticle: Identifiable {
    let id: UUID = UUID()
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var color: Color
    var size: CGFloat
    var opacity: CGFloat
}

struct GemCatcherScorePop: Identifiable {
    let id: UUID = UUID()
    var text: String
    var color: Color
    var x: CGFloat
    var y: CGFloat
    var opacity: CGFloat
}

// MARK: - Diamond Shape

struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

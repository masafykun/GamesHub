import SwiftUI

struct FSlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct FSlV3Fruit {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var velocity: CGSize
    var isBomb: Bool
    var radius: CGFloat = 36
    var sliced: Bool = false
    var rotation: Double = 0
    var rotationSpeed: Double = 0
}

enum FSlV3Phase { case start, playing, gameOver }

struct FruitSliceViewV3: View {
    @State private var phase: FSlV3Phase = .start
    @State private var fruits: [FSlV3Fruit] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var timer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var sliceTrail: [CGPoint] = []
    @State private var seedInt: Int = 1
    @State private var lcg: FSlLCG = FSlLCG(seed: 1)
    @State private var spawnQueue: [Int] = []
    @State private var spawnIndex: Int = 0
    @State private var bestScore: Int = 0
    @AppStorage("FSlV3Best") private var storedBest: Int = 0

    let emojiList = ["🍎","🍊","🍋","🍇","🍓","🍑","🍈","🥝"]
    let screenW: CGFloat = 393
    let screenH: CGFloat = 852

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            if phase == .start { startScreen }
            else if phase == .playing { gameScreen }
            else { gameOverScreen }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("🍎").font(.system(size: 64))
                Text("Fruit Slice").font(.system(size: 40, weight: .bold)).foregroundColor(.primary)
                Text("Neumorphism Edition").font(.caption).foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Drag to slice flying fruits", systemImage: "hand.draw")
                Label("Avoid 💣 bombs at all costs", systemImage: "exclamationmark.triangle.fill")
                Label("3 lives — don't miss!", systemImage: "heart.fill")
                Label("Seeded procedural generation", systemImage: "dice")
            }
            .font(.subheadline)
            .foregroundColor(.primary.opacity(0.8))
            .padding(20)
            .neumorphicCard(radius: 16)

            if storedBest > 0 {
                Text("Best Score: \(storedBest)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }

            Button("Start Game") { startGame() }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 48).padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red: 0.4, green: 0.2, blue: 0.9), Color(red: 0.7, green: 0.2, blue: 0.6)],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.3), radius: 8, x: 4, y: 4)
        }
        .padding(28)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(fruits, id: \.id) { fruit in
                    if !fruit.sliced {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: fruit.radius * 2, height: fruit.radius * 2)
                                .shadow(color: .white, radius: 6, x: -3, y: -3)
                                .shadow(color: Color(.systemGray4), radius: 6, x: 3, y: 3)
                            Text(fruit.emoji)
                                .font(.system(size: fruit.radius * 1.2))
                                .rotationEffect(.degrees(fruit.rotation))
                        }
                        .position(fruit.position)
                    }
                }

                if sliceTrail.count > 1 {
                    Path { path in
                        path.move(to: sliceTrail[0])
                        for pt in sliceTrail.dropFirst() { path.addLine(to: pt) }
                    }
                    .stroke(
                        LinearGradient(colors: [Color.purple.opacity(0.3), Color.purple],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE").font(.caption2.bold()).foregroundColor(.secondary)
                            Text("\(score)").font(.system(size: 30, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .neumorphicCard(radius: 12)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LIVES").font(.caption2.bold()).foregroundColor(.secondary)
                            Text(String(repeating: "❤️", count: lives)).font(.title3)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .neumorphicCard(radius: 12)
                    }
                    .padding()

                    HStack {
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                        Spacer()
                    }
                    .padding(.horizontal)

                    Spacer()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let pt = val.location
                        sliceTrail.append(pt)
                        if sliceTrail.count > 20 { sliceTrail.removeFirst() }
                        checkSlice(at: pt)
                    }
                    .onEnded { _ in sliceTrail = [] }
            )
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("Game Over").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundColor(.primary)

            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("FINAL SCORE").font(.caption.bold()).foregroundColor(.secondary)
                    Text("\(score)").font(.system(size: 52, weight: .bold, design: .rounded))
                }
                if score >= storedBest && score > 0 {
                    Text("New Best!").font(.headline).foregroundColor(.purple)
                } else if storedBest > 0 {
                    Text("Best: \(storedBest)").font(.subheadline).foregroundColor(.secondary)
                }
                Text("Seed: #\(seedInt - 1)")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
            }
            .padding(24)
            .neumorphicCard(radius: 20)

            VStack(spacing: 14) {
                Button("Play Again") { startGame() }
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color(red: 0.4, green: 0.2, blue: 0.9), Color(red: 0.7, green: 0.2, blue: 0.6)],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .shadow(color: .purple.opacity(0.3), radius: 8, x: 4, y: 4)

                Button("Menu") { phase = .start; stopTimers() }
                    .font(.subheadline).foregroundColor(.secondary)
            }
        }
        .padding(28)
    }

    func startGame() {
        score = 0; lives = 3; fruits = []; sliceTrail = []
        lcg = FSlLCG(seed: seedInt)
        buildSpawnQueue()
        spawnIndex = 0
        phase = .playing
        stopTimers()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in updateFruits() }
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { _ in spawnNextFruit() }
        spawnNextFruit()
    }

    func buildSpawnQueue() {
        spawnQueue = []
        for _ in 0..<50 {
            spawnQueue.append(lcg.nextInt(emojiList.count + 2))
        }
    }

    func stopTimers() { timer?.invalidate(); spawnTimer?.invalidate(); timer = nil; spawnTimer = nil }

    func spawnNextFruit() {
        guard phase == .playing else { return }
        let raw = spawnQueue[spawnIndex % spawnQueue.count]
        spawnIndex += 1
        let isBomb = raw >= emojiList.count
        let emoji = isBomb ? "💣" : emojiList[raw % emojiList.count]
        let xRaw = lcg.nextDouble()
        let vyRaw = lcg.nextDouble()
        let vxRaw = lcg.nextDouble()
        let rotRaw = lcg.nextDouble()
        let x = CGFloat(xRaw) * 270 + 60
        let vy = CGFloat(vyRaw) * (-200) + (-600)
        let vx = CGFloat(vxRaw) * 120 - 60
        let rotSpeed = (rotRaw - 0.5) * 200
        let fruit = FSlV3Fruit(
            emoji: emoji,
            position: CGPoint(x: x, y: screenH + 40),
            velocity: CGSize(width: vx, height: vy),
            isBomb: isBomb,
            rotationSpeed: rotSpeed
        )
        fruits.append(fruit)
    }

    func updateFruits() {
        let dt: CGFloat = 0.033
        let gravity: CGFloat = 900
        var anyMissed = false
        fruits = fruits.compactMap { var f = $0
            f.velocity.height += gravity * dt
            f.position.x += f.velocity.width * dt
            f.position.y += f.velocity.height * dt
            f.rotation += f.rotationSpeed * Double(dt)
            if f.position.y > screenH + 80 && !f.sliced {
                if !f.isBomb { anyMissed = true }
                return nil
            }
            if f.sliced { return nil }
            return f
        }
        if anyMissed {
            lives -= 1
            if lives <= 0 { endGame() }
        }
    }

    func checkSlice(at point: CGPoint) {
        for i in fruits.indices {
            guard !fruits[i].sliced else { continue }
            let dx = fruits[i].position.x - point.x
            let dy = fruits[i].position.y - point.y
            if sqrt(dx*dx + dy*dy) < fruits[i].radius {
                if fruits[i].isBomb { endGame(); return }
                fruits[i].sliced = true
                score += 1
            }
        }
    }

    func endGame() {
        stopTimers()
        if score > storedBest { storedBest = score }
        seedInt += 1
        phase = .gameOver
    }
}

#Preview { FruitSliceViewV3() }

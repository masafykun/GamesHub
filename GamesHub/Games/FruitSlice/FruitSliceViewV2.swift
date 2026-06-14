import SwiftUI

struct FSlV2Fruit {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var velocity: CGSize
    var isBomb: Bool
    var radius: CGFloat = 36
    var sliced: Bool = false
}

enum FSlV2Phase { case start, playing, gameOver }

struct FruitSliceViewV2: View {
    @State private var phase: FSlV2Phase = .start
    @State private var fruits: [FSlV2Fruit] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var timer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var sliceTrail: [CGPoint] = []
    @State private var recentResults: [Bool] = []
    @State private var difficulty: Double = 1.0
    @State private var spawnInterval: Double = 1.2
    @State private var comboCount: Int = 0

    let emojis = ["🍎","🍊","🍋","🍇","🍓"]
    let screenW: CGFloat = 393
    let screenH: CGFloat = 852

    var gradientBG: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            gradientBG.ignoresSafeArea()

            if phase == .start { startScreen }
            else if phase == .playing { gameScreen }
            else { gameOverScreen }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("🍎").font(.system(size: 64))
                Text("Fruit Slice").font(.system(size: 42, weight: .bold)).foregroundColor(.white)
                Text("Glassmorphism Edition").font(.caption).foregroundColor(.white.opacity(0.6))
            }
            VStack(alignment: .leading, spacing: 10) {
                Label("Slice flying fruits to earn points", systemImage: "hand.draw")
                Label("Avoid 💣 bombs — instant death!", systemImage: "exclamationmark.triangle")
                Label("Missing fruits costs a life (3 total)", systemImage: "heart")
                Label("Difficulty adapts to your skill", systemImage: "chart.line.uptrend.xyaxis")
            }
            .foregroundColor(.white.opacity(0.85))
            .font(.subheadline)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Start Game") { startGame() }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 48).padding(.vertical, 14)
                .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: .purple.opacity(0.5), radius: 12)
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
                                .fill(.ultraThinMaterial)
                                .frame(width: fruit.radius * 2, height: fruit.radius * 2)
                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                            Text(fruit.emoji).font(.system(size: fruit.radius * 1.2))
                        }
                        .position(fruit.position)
                    }
                }
                if sliceTrail.count > 1 {
                    Path { path in
                        path.move(to: sliceTrail[0])
                        for pt in sliceTrail.dropFirst() { path.addLine(to: pt) }
                    }
                    .stroke(LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing), lineWidth: 3)
                }
                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCORE").font(.caption2).foregroundColor(.white.opacity(0.6))
                            Text("\(score)").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("LIVES").font(.caption2).foregroundColor(.white.opacity(0.6))
                            Text(String(repeating: "❤️", count: lives)).font(.title3)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .padding()

                    if difficulty > 1.2 {
                        Text("⚡ HYPER MODE").font(.caption.bold())
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.yellow.opacity(0.5), lineWidth: 1))
                    }

                    Spacer()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let pt = val.location
                        sliceTrail.append(pt)
                        if sliceTrail.count > 18 { sliceTrail.removeFirst() }
                        checkSlice(at: pt)
                    }
                    .onEnded { _ in sliceTrail = [] }
            )
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.system(size: 38, weight: .bold)).foregroundColor(.white)
            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("FINAL SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(score)").font(.system(size: 52, weight: .bold)).foregroundColor(.white)
                }
                Text("Difficulty: \(String(format: "%.1fx", difficulty))")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: 12) {
                Button("Play Again") { startGame() }
                    .font(.title2.bold()).foregroundColor(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                Button("Menu") { phase = .start; stopTimers() }
                    .font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(28)
    }

    func startGame() {
        score = 0; lives = 3; fruits = []; sliceTrail = []
        difficulty = 1.0; spawnInterval = 1.2; comboCount = 0
        phase = .playing
        stopTimers()
        scheduleTimers()
        spawnFruit()
    }

    func scheduleTimers() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in updateFruits() }
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in spawnFruit() }
    }

    func stopTimers() { timer?.invalidate(); spawnTimer?.invalidate(); timer = nil; spawnTimer = nil }

    func spawnFruit() {
        guard phase == .playing else { return }
        let x = CGFloat.random(in: 60...330)
        let isBomb = Int.random(in: 0..<6) == 0
        let emoji = isBomb ? "💣" : emojis.randomElement()!
        let baseVy = -700.0 * difficulty
        let vy = CGFloat.random(in: baseVy * 1.1 ... baseVy * 0.9)
        let vx = CGFloat.random(in: -60...60) * CGFloat(difficulty)
        let fruit = FSlV2Fruit(emoji: emoji, position: CGPoint(x: x, y: screenH + 40), velocity: CGSize(width: vx, height: vy), isBomb: isBomb)
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
            if f.position.y > screenH + 80 && !f.sliced {
                if !f.isBomb { anyMissed = true }
                return nil
            }
            if f.sliced { return nil }
            return f
        }
        if anyMissed {
            lives -= 1
            recordResult(false)
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
                recordResult(true)
            }
        }
    }

    func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 {
            let successes = recentResults.filter { $0 }.count
            if successes > 4 {
                difficulty = min(difficulty * 1.2, 3.0)
                spawnInterval = max(0.5, spawnInterval * 0.85)
                stopTimers()
                scheduleTimers()
            }
        }
    }

    func endGame() { stopTimers(); phase = .gameOver }
}

#Preview { FruitSliceViewV2() }

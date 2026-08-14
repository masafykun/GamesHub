import SwiftUI

// MARK: - Models

struct FruitSliceFruit: Identifiable {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var velocity: CGSize
    var isBomb: Bool
    var radius: CGFloat = 36
    var sliced: Bool = false
    /// Set once the fruit has risen into view; only then can it be "missed".
    var entered: Bool = false
}

enum FruitSlicePhase { case start, playing, gameOver }

// MARK: - Engine

/// The loop lives in an object rather than the view so exactly one timer can
/// ever be running — driving it from the struct let stale timers pile up and
/// drain lives the moment a round started.
final class FruitSliceEngine: ObservableObject {
    @Published var phase: FruitSlicePhase = .start
    @Published var fruits: [FruitSliceFruit] = []
    @Published var score: Int = 0
    @Published var lives: Int = 3
    @Published var difficulty: Double = 1.0

    var canvasSize: CGSize = CGSize(width: 393, height: 852)
    var onGameOver: ((Int) -> Void)?

    private let emojis = ["🍎", "🍊", "🍋", "🍇", "🍓"]
    private let tickInterval = 1.0 / 30.0
    private var spawnInterval: Double = 1.2
    private var spawnAccumulator: Double = 0
    private var recentResults: [Bool] = []
    private var timer: Timer?

    // MARK: Lifecycle

    func start() {
        stop()
        score = 0
        lives = 3
        fruits = []
        difficulty = 1.0
        spawnInterval = 1.2
        spawnAccumulator = spawnInterval    // first toss comes right away
        recentResults = []
        phase = .playing

        let t = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer = t
        RunLoop.main.add(t, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func backToMenu() {
        stop()
        fruits = []
        phase = .start
    }

    // MARK: Loop

    private func tick() {
        guard phase == .playing else { return }

        spawnAccumulator += tickInterval
        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            spawnFruit()
        }

        let dt = CGFloat(tickInterval)
        let gravity: CGFloat = 900
        let floor = canvasSize.height
        var missed = 0

        fruits = fruits.compactMap { fruit in
            var f = fruit
            f.velocity.height += gravity * dt
            f.position.x += f.velocity.width * dt
            f.position.y += f.velocity.height * dt

            if f.position.y < floor - f.radius { f.entered = true }

            if f.sliced { return nil }
            if f.position.y > floor + 80 {
                // A fruit that never made it into view is dropped for free.
                if !f.isBomb && f.entered { missed += 1 }
                return nil
            }
            return f
        }

        if missed > 0 {
            lives -= missed
            for _ in 0..<missed { recordResult(false) }
            if lives <= 0 {
                lives = 0
                endGame()
            }
        }
    }

    private func spawnFruit() {
        guard phase == .playing else { return }
        let width = max(140, canvasSize.width)
        let x = CGFloat.random(in: 50...(width - 50))
        let isBomb = Int.random(in: 0..<6) == 0
        let emoji = isBomb ? "💣" : (emojis.randomElement() ?? "🍎")

        // Fast enough to arc into the middle of the screen where it can be sliced.
        let baseVy = -980.0 * difficulty
        let vy = CGFloat.random(in: baseVy * 1.1 ... baseVy * 0.9)
        let vx = CGFloat.random(in: -60...60) * CGFloat(difficulty)

        fruits.append(
            FruitSliceFruit(
                emoji: emoji,
                position: CGPoint(x: x, y: canvasSize.height + 40),
                velocity: CGSize(width: vx, height: vy),
                isBomb: isBomb
            )
        )
    }

    // MARK: Input

    func slice(at point: CGPoint) {
        guard phase == .playing else { return }
        for i in fruits.indices where !fruits[i].sliced {
            let dx = fruits[i].position.x - point.x
            let dy = fruits[i].position.y - point.y
            guard sqrt(dx * dx + dy * dy) < fruits[i].radius else { continue }

            if fruits[i].isBomb {
                endGame()
                return
            }
            fruits[i].sliced = true
            score += 1
            recordResult(true)
        }
    }

    private func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5, recentResults.filter({ $0 }).count > 4 {
            difficulty = min(difficulty * 1.2, 3.0)
            spawnInterval = max(0.5, spawnInterval * 0.85)
            recentResults = []
        }
    }

    private func endGame() {
        stop()
        phase = .gameOver
        onGameOver?(score)
    }

    deinit { timer?.invalidate() }
}

// MARK: - View

struct FruitSliceView: View {
    @StateObject private var engine = FruitSliceEngine()
    @AppStorage("fruitSliceBestScore") private var bestScore: Int = 0
    @State private var sliceTrail: [CGPoint] = []

    private var gradientBG: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    var body: some View {
        ZStack {
            gradientBG.ignoresSafeArea()

            switch engine.phase {
            case .start:    startScreen
            case .playing:  gameScreen
            case .gameOver: gameOverScreen
            }
        }
        .onAppear {
            engine.onGameOver = { score in bestScore = max(bestScore, score) }
        }
        .onDisappear { engine.stop() }
        .preferredColorScheme(.dark)
    }

    // MARK: Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("🍎").font(.system(size: 64))
                Text("Fruit Slice").font(.system(size: 42, weight: .bold)).foregroundColor(.white)
                if bestScore > 0 {
                    Text("Best: \(bestScore)").font(.caption).foregroundColor(.white.opacity(0.6))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Swipe across flying fruit to slice it", systemImage: "hand.draw")
                Label("Avoid 💣 bombs — instant game over", systemImage: "exclamationmark.triangle")
                Label("Missing a fruit costs a life (3 total)", systemImage: "heart")
                Label("Slice cleanly and the pace picks up", systemImage: "chart.line.uptrend.xyaxis")
            }
            .foregroundColor(.white.opacity(0.85))
            .font(.subheadline)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            Button("Start Game") { engine.start() }
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
                ForEach(engine.fruits) { fruit in
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
                    .stroke(
                        LinearGradient(colors: [.cyan, .white], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 3
                    )
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCORE").font(.caption2).foregroundColor(.white.opacity(0.6))
                            Text("\(engine.score)").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("LIVES").font(.caption2).foregroundColor(.white.opacity(0.6))
                            Text(String(repeating: "❤️", count: max(0, engine.lives))).font(.title3)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                    }
                    .padding()

                    if engine.difficulty > 1.2 {
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
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        sliceTrail.append(val.location)
                        if sliceTrail.count > 18 { sliceTrail.removeFirst() }
                        engine.slice(at: val.location)
                    }
                    .onEnded { _ in sliceTrail = [] }
            )
            .onAppear { engine.canvasSize = geo.size }
            .onChange(of: geo.size) { _, newSize in engine.canvasSize = newSize }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.system(size: 38, weight: .bold)).foregroundColor(.white)

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("FINAL SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(engine.score)").font(.system(size: 52, weight: .bold)).foregroundColor(.white)
                }
                Text("Best: \(bestScore)  ·  Speed: \(String(format: "%.1fx", engine.difficulty))")
                    .font(.subheadline).foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: 12) {
                Button("Play Again") { engine.start() }
                    .font(.title2.bold()).foregroundColor(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                Button("Menu") { engine.backToMenu() }
                    .font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(28)
    }
}

#Preview {
    FruitSliceView()
}

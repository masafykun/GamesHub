import SwiftUI

struct FSlFruit {
    let id = UUID()
    var emoji: String
    var position: CGPoint
    var velocity: CGSize
    var isBomb: Bool
    var radius: CGFloat = 36
    var sliced: Bool = false
    var missed: Bool = false
}

enum FSlPhase { case start, playing, gameOver }

struct FruitSliceView: View {
    @State private var phase: FSlPhase = .start
    @State private var fruits: [FSlFruit] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var timer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var dragStart: CGPoint? = nil
    @State private var dragEnd: CGPoint? = nil
    @State private var sliceTrail: [CGPoint] = []

    let emojis = ["🍎","🍊","🍋","🍇","🍓"]
    let screenW: CGFloat = 393
    let screenH: CGFloat = 852

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if phase == .start {
                startScreen
            } else if phase == .playing {
                gameScreen
            } else {
                gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("🍎 Fruit Slice").font(.system(size: 42, weight: .bold)).foregroundColor(.white)
            Text("Slice fruits, avoid bombs!").font(.title3).foregroundColor(.gray)
            VStack(alignment: .leading, spacing: 8) {
                Text("• Drag across fruits to slice them").foregroundColor(.white.opacity(0.8))
                Text("• Avoid 💣 bombs — instant game over").foregroundColor(.white.opacity(0.8))
                Text("• 3 lives — don't miss fruits!").foregroundColor(.white.opacity(0.8))
            }
            Button("Start Game") {
                startGame()
            }
            .font(.title2.bold())
            .foregroundColor(.black)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.yellow).clipShape(Capsule())
        }
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(fruits, id: \.id) { fruit in
                    if !fruit.sliced {
                        Text(fruit.emoji)
                            .font(.system(size: fruit.radius * 1.3))
                            .position(fruit.position)
                    }
                }
                if sliceTrail.count > 1 {
                    Path { path in
                        path.move(to: sliceTrail[0])
                        for pt in sliceTrail.dropFirst() { path.addLine(to: pt) }
                    }
                    .stroke(Color.white.opacity(0.7), lineWidth: 3)
                }
                VStack {
                    HStack {
                        Text("Score: \(score)").font(.title2.bold()).foregroundColor(.white)
                        Spacer()
                        Text(String(repeating: "❤️", count: lives)).font(.title2)
                    }
                    .padding()
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
        VStack(spacing: 24) {
            Text("Game Over").font(.system(size: 40, weight: .bold)).foregroundColor(.red)
            Text("Score: \(score)").font(.system(size: 36, weight: .semibold)).foregroundColor(.white)
            Button("Play Again") { startGame() }
                .font(.title2.bold()).foregroundColor(.black)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.yellow).clipShape(Capsule())
            Button("Menu") { phase = .start; stopTimers() }
                .font(.title3).foregroundColor(.gray)
        }
    }

    func startGame() {
        score = 0; lives = 3; fruits = []; sliceTrail = []
        phase = .playing
        stopTimers()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in updateFruits() }
        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { _ in spawnFruit() }
        spawnFruit()
    }

    func stopTimers() { timer?.invalidate(); spawnTimer?.invalidate(); timer = nil; spawnTimer = nil }

    func spawnFruit() {
        guard phase == .playing else { return }
        let x = CGFloat.random(in: 60...330)
        let isBomb = Int.random(in: 0..<6) == 0
        let emoji = isBomb ? "💣" : emojis.randomElement()!
        let vx = CGFloat.random(in: -60...60)
        let vy = CGFloat.random(in: -700 ... -500)
        let fruit = FSlFruit(emoji: emoji, position: CGPoint(x: x, y: screenH + 40), velocity: CGSize(width: vx, height: vy), isBomb: isBomb)
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

    func endGame() { stopTimers(); phase = .gameOver }
}

#Preview { FruitSliceView() }

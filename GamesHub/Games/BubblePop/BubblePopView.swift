import SwiftUI

struct BbPBubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let speed: CGFloat
    let radius: CGFloat
}

enum BbPPhase {
    case start, playing, gameOver
}

struct BubblePopView: View {
    @State private var bubbles: [BbPBubble] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var phase: BbPPhase = .start
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil

    let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]

    var spawnInterval: TimeInterval {
        max(0.4, 1.2 - Double(score) * 0.03)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("BubblePop")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Tap bubbles before\nthey reach the top!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .clipShape(Capsule())
            }
        }
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(bubble.color)
                        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                        .position(x: bubble.x, y: bubble.y)
                        .onTapGesture {
                            popBubble(id: bubble.id)
                        }
                }

                VStack {
                    HStack {
                        Text("Score: \(score)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                        Text("Lives: \(String(repeating: "❤️", count: lives))")
                            .font(.headline)
                            .padding()
                    }
                    Spacer()
                }
            }
            .onAppear { scheduleTimers(in: geo.size) }
            .onDisappear { stopTimers() }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Score: \(score)")
                .font(.title2)
                .foregroundColor(.yellow)
            Button(action: startGame) {
                Text("Play Again")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .clipShape(Capsule())
            }
            Button(action: { phase = .start }) {
                Text("Menu")
                    .foregroundColor(.gray)
            }
        }
    }

    func startGame() {
        bubbles = []
        score = 0
        lives = 3
        phase = .playing
    }

    func scheduleTimers(in size: CGSize) {
        stopTimers()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnBubble(in: size)
        }
        moveTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in
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
        let radius = CGFloat.random(in: 20...35)
        let x = CGFloat.random(in: radius...(size.width - radius))
        let speed = CGFloat.random(in: 1.5...3.5)
        let color = colors.randomElement() ?? .blue
        let bubble = BbPBubble(x: x, y: size.height + radius, color: color, speed: speed, radius: radius)
        bubbles.append(bubble)

        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: true) { _ in
            spawnBubble(in: size)
        }
    }

    func moveBubbles(in size: CGSize) {
        var toRemove: [UUID] = []
        for i in bubbles.indices {
            bubbles[i].y -= bubbles[i].speed
            if bubbles[i].y + bubbles[i].radius < 0 {
                toRemove.append(bubbles[i].id)
                lives -= 1
            }
        }
        bubbles.removeAll { toRemove.contains($0.id) }
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

#Preview { BubblePopView() }

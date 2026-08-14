import SwiftUI

struct BubblePopBubble: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    var speed: CGFloat
    let radius: CGFloat
}

enum BubblePopPhase {
    case start, playing, gameOver
}

struct BubblePopView: View {
    @State private var bubbles: [BubblePopBubble] = []
    @State private var score: Int = 0
    @State private var lives: Int = 3
    @State private var phase: BubblePopPhase = .start
    @State private var spawnTimer: Timer? = nil
    @State private var moveTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @AppStorage("bubblePopBestScore") private var bestScore: Int = 0

    let colors: [Color] = [.red, .orange, .yellow, .green, .cyan, .purple, .pink, .mint]

    var spawnInterval: TimeInterval {
        max(0.3, (1.2 - Double(score) * 0.02) / difficultyMultiplier)
    }

    var baseSpeed: CGFloat {
        CGFloat(difficultyMultiplier) * 1.5
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.1, blue: 0.3), Color(red: 0.3, green: 0.1, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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

    var glassPanel: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BubblePop")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Tap colorful bubbles\nbefore they escape!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))")
                    .font(.caption)
                    .foregroundStyle(.yellow.opacity(0.9))
            }
            Button(action: startGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    )
            }
        }
        .padding(32)
        .background(glassPanel)
        .padding(40)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(bubbles) { bubble in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [bubble.color.opacity(0.9), bubble.color.opacity(0.5)],
                                center: .topLeading,
                                startRadius: 2,
                                endRadius: bubble.radius * 2
                            )
                        )
                        .frame(width: bubble.radius * 2, height: bubble.radius * 2)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.4), lineWidth: 1.5)
                        )
                        .position(x: bubble.x, y: bubble.y)
                        .onTapGesture {
                            popBubble(id: bubble.id)
                        }
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE")
                                .font(.caption2).foregroundStyle(.white.opacity(0.6))
                            Text("\(score)")
                                .font(.title2.bold()).foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(glassPanel)
                        .padding(.leading)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LIVES")
                                .font(.caption2).foregroundStyle(.white.opacity(0.6))
                            Text(String(repeating: "♥ ", count: lives).trimmingCharacters(in: .whitespaces))
                                .font(.headline).foregroundStyle(.pink)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(glassPanel)
                        .padding(.trailing)
                    }
                    .padding(.top, 8)
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
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("Final Score")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                Text("\(score)")
                    .font(.system(size: 52, weight: .black))
                    .foregroundStyle(.yellow)
            }
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            VStack(spacing: 12) {
                Button(action: startGame) {
                    Text("Play Again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.4), lineWidth: 1))
                        )
                }
                Button(action: { phase = .start }) {
                    Text("Menu")
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 8)
                }
            }
        }
        .padding(32)
        .background(glassPanel)
        .padding(40)
    }

    func startGame() {
        bubbles = []
        score = 0
        lives = 3
        phase = .playing
        checkAdaptiveDifficulty()
    }

    func checkAdaptiveDifficulty() {
        if recentResults.count >= 5 {
            let lastFive = recentResults.suffix(5)
            let trueCount = lastFive.filter { $0 }.count
            if trueCount > 4 {
                difficultyMultiplier = min(3.0, difficultyMultiplier * 1.2)
            }
        }
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
        let radius = CGFloat.random(in: 18...34)
        let x = CGFloat.random(in: radius...(size.width - radius))
        let speed = CGFloat.random(in: baseSpeed...(baseSpeed + 2.5))
        let color = colors.randomElement() ?? .blue
        let bubble = BubblePopBubble(x: x, y: size.height + radius, color: color, speed: speed, radius: radius)
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
            for _ in 0..<missCount {
                recentResults.append(false)
            }
        }
        if lives <= 0 {
            stopTimers()
            bestScore = max(bestScore, score)
            recentResults.append(score > 10)
            if recentResults.count > 20 { recentResults.removeFirst(recentResults.count - 20) }
            phase = .gameOver
        }
    }

    func popBubble(id: UUID) {
        guard bubbles.contains(where: { $0.id == id }) else { return }
        bubbles.removeAll { $0.id == id }
        score += 1
        // Pops used to go unrecorded, so the streak needed for a difficulty
        // bump could never be reached.
        recentResults.append(true)
        if recentResults.count > 20 { recentResults.removeFirst(recentResults.count - 20) }
        checkAdaptiveDifficulty()
    }
}

#Preview { BubblePopView() }

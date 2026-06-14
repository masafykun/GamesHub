import SwiftUI

enum IfHpPhase { case start, playing, over }

struct IfHpPlatform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 14
}

struct InfinityHopView: View {
    @State private var phase: IfHpPhase = .start
    @State private var playerX: CGFloat = 0.5
    @State private var playerY: CGFloat = 0.6
    @State private var platforms: [IfHpPlatform] = []
    @State private var score: Int = 0
    @State private var velocityX: CGFloat = 0
    @State private var velocityY: CGFloat = 0
    @State private var isFalling: Bool = false
    @State private var timer: Timer?
    @State private var highScore: Int = 0

    private let playerRadius: CGFloat = 16
    private let gravity: CGFloat = 0.018
    private let hopStrength: CGFloat = -0.032
    private let horizontalSpeed: CGFloat = 0.035
    private let platformScrollSpeed: CGFloat = 0.003

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemIndigo).ignoresSafeArea()

                if phase == .start {
                    startScreen
                } else if phase == .playing {
                    gameScreen(geo: geo)
                } else {
                    overScreen
                }
            }
            .onAppear { setupPlatforms(geo: geo) }
        }
    }

    private var startScreen: some View {
        VStack(spacing: 24) {
            Text("INFINITY HOP").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Tap left or right to hop onto platforms").font(.subheadline).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center).padding(.horizontal)
            Text("High Score: \(highScore)").font(.headline).foregroundColor(.yellow)
            Button("START") { startGame() }
                .font(.title2.bold()).foregroundColor(.indigo)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.white).clipShape(Capsule())
        }
    }

    private func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(platforms) { p in
                RoundedRectangle(cornerRadius: 6)
                    .fill(platformColor(score: score))
                    .frame(width: p.width * geo.size.width, height: p.height)
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }

            Circle()
                .fill(Color.yellow)
                .frame(width: playerRadius * 2, height: playerRadius * 2)
                .position(x: playerX * geo.size.width, y: playerY * geo.size.height)

            VStack {
                HStack {
                    Text("SCORE: \(score)").font(.headline.bold()).foregroundColor(.white).padding()
                    Spacer()
                }
                Spacer()
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    let isLeft = value.location.x < geo.size.width / 2
                    hop(left: isLeft)
                })
        }
    }

    private var overScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Score: \(score)").font(.title2).foregroundColor(.yellow)
            Text("Best: \(highScore)").font(.headline).foregroundColor(.white.opacity(0.8))
            Button("PLAY AGAIN") { startGame() }
                .font(.title2.bold()).foregroundColor(.indigo)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.white).clipShape(Capsule())
            Button("MENU") { phase = .start }
                .font(.headline).foregroundColor(.white.opacity(0.7))
        }
    }

    private func platformColor(score: Int) -> Color {
        score < 10 ? .green : score < 25 ? .orange : .red
    }

    private func setupPlatforms(geo: GeometryProxy) {
        platforms = []
        let startWidth: CGFloat = 0.35
        for i in 0..<8 {
            platforms.append(IfHpPlatform(x: CGFloat.random(in: 0.2...0.8), y: CGFloat(i) * 0.14 + 0.2, width: startWidth))
        }
    }

    private func startGame() {
        score = 0
        playerX = 0.5
        playerY = 0.6
        velocityX = 0
        velocityY = 0
        isFalling = false
        platforms = []
        for i in 0..<8 {
            platforms.append(IfHpPlatform(x: CGFloat.random(in: 0.2...0.8), y: CGFloat(i) * 0.14 + 0.2, width: 0.35))
        }
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in tick() }
    }

    private func hop(left: Bool) {
        velocityX = left ? -horizontalSpeed : horizontalSpeed
        velocityY = hopStrength
        isFalling = true
    }

    private func tick() {
        guard phase == .playing else { timer?.invalidate(); return }

        velocityY += gravity
        playerX += velocityX
        playerY += velocityY
        velocityX *= 0.92

        playerX = max(0.02, min(0.98, playerX))

        for i in platforms.indices {
            platforms[i].y += platformScrollSpeed
        }

        platforms.removeAll { $0.y > 1.1 }
        while platforms.count < 8 {
            let w = max(0.12, 0.35 - CGFloat(score) * 0.004)
            platforms.append(IfHpPlatform(x: CGFloat.random(in: 0.15...0.85), y: -0.05, width: w))
        }

        checkLanding()

        if playerY > 1.05 {
            endGame()
        }
    }

    private func checkLanding() {
        guard velocityY > 0 else { return }
        for p in platforms {
            let pw = p.width
            let left = p.x - pw / 2
            let right = p.x + pw / 2
            let top = p.y - (p.height / 600)
            let bottom = p.y + (p.height / 600)
            if playerX > left && playerX < right && playerY + 0.025 > top && playerY + 0.025 < bottom + 0.02 {
                playerY = top - 0.025
                velocityY = 0
                isFalling = false
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

#Preview { InfinityHopView() }

import SwiftUI

enum InfinityHopPhase { case start, playing, over }

struct InfinityHopPlatform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 14
}

struct InfinityHopView: View {
    @State private var phase: InfinityHopPhase = .start
    @State private var playerX: CGFloat = 0.5
    @State private var playerY: CGFloat = 0.6
    @State private var platforms: [InfinityHopPlatform] = []
    @State private var score: Int = 0
    @State private var velocityX: CGFloat = 0
    @State private var velocityY: CGFloat = 0
    @State private var timer: Timer?
    @State private var highScore: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var showDifficultyBump: Bool = false

    private let baseGravity: CGFloat = 0.018
    private let baseHopStrength: CGFloat = -0.032
    private let baseScrollSpeed: CGFloat = 0.003
    private let horizontalSpeed: CGFloat = 0.035

    private var gravity: CGFloat { baseGravity * CGFloat(difficultyMultiplier) }
    private var hopStrength: CGFloat { baseHopStrength }
    private var scrollSpeed: CGFloat { baseScrollSpeed * CGFloat(difficultyMultiplier) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.3), Color(red: 0.3, green: 0.05, blue: 0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                if phase == .start {
                    startScreen
                } else if phase == .playing {
                    gameScreen(geo: geo)
                } else {
                    overScreen
                }
            }
        }
    }

    private var startScreen: some View {
        VStack(spacing: 28) {
            Text("INFINITY HOP").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Tap left or right to hop\nonto platforms").font(.subheadline).foregroundColor(.white.opacity(0.75)).multilineTextAlignment(.center)
            VStack(spacing: 6) {
                Text("High Score: \(highScore)").font(.headline).foregroundColor(.yellow)
                if difficultyMultiplier > 1.0 {
                    Text("Speed x\(String(format: "%.1f", difficultyMultiplier))").font(.caption).foregroundColor(.orange)
                }
            }
            Button("START") { startGame() }
                .font(.title2.bold()).foregroundColor(.white)
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    private func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            ForEach(platforms) { p in
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(.white.opacity(0.5), lineWidth: 1))
                    .frame(width: p.width * geo.size.width, height: p.height)
                    .position(x: p.x * geo.size.width, y: p.y * geo.size.height)
            }

            Circle()
                .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 32, height: 32)
                .shadow(color: .yellow.opacity(0.6), radius: 8)
                .position(x: playerX * geo.size.width, y: playerY * geo.size.height)

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                        Text("\(score)").font(.title.bold()).foregroundColor(.white)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                    .padding()
                    Spacer()
                    if showDifficultyBump {
                        Text("SPEED UP!")
                            .font(.caption.bold()).foregroundColor(.orange)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(.orange.opacity(0.5), lineWidth: 1))
                            .padding()
                            .transition(.opacity)
                    }
                }
                Spacer()
            }

            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                    hop(left: value.location.x < geo.size.width / 2)
                })
        }
    }

    private var overScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.largeTitle.bold()).foregroundColor(.white)
            VStack(spacing: 8) {
                Text("Score: \(score)").font(.title2.bold()).foregroundColor(.yellow)
                Text("Best: \(highScore)").font(.headline).foregroundColor(.white.opacity(0.7))
                Text("Speed x\(String(format: "%.1f", difficultyMultiplier))").font(.caption).foregroundColor(.orange)
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

            VStack(spacing: 12) {
                Button("PLAY AGAIN") { startGame() }
                    .font(.title2.bold()).foregroundColor(.white)
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                Button("MENU") { phase = .start }
                    .font(.headline).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    private func startGame() {
        score = 0
        playerX = 0.5
        playerY = 0.6
        velocityX = 0
        velocityY = 0
        platforms = []
        for i in 0..<8 {
            platforms.append(InfinityHopPlatform(x: CGFloat.random(in: 0.2...0.8), y: CGFloat(i) * 0.14 + 0.2, width: 0.35))
        }
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in tick() }
    }

    private func hop(left: Bool) {
        velocityX = left ? -horizontalSpeed : horizontalSpeed
        velocityY = hopStrength
    }

    private func tick() {
        guard phase == .playing else { timer?.invalidate(); return }

        velocityY += gravity
        playerX += velocityX
        playerY += velocityY
        velocityX *= 0.92
        playerX = max(0.02, min(0.98, playerX))

        for i in platforms.indices { platforms[i].y += scrollSpeed }
        platforms.removeAll { $0.y > 1.1 }
        while platforms.count < 8 {
            let w = max(0.12, 0.35 - CGFloat(score) * 0.004)
            platforms.append(InfinityHopPlatform(x: CGFloat.random(in: 0.15...0.85), y: -0.05, width: w))
        }

        checkLanding()
        if playerY > 1.05 { endGame() }
    }

    private func checkLanding() {
        guard velocityY > 0 else { return }
        for p in platforms {
            let left = p.x - p.width / 2
            let right = p.x + p.width / 2
            let top = p.y - 0.012
            let bottom = p.y + 0.012
            if playerX > left && playerX < right && playerY + 0.025 > top && playerY + 0.025 < bottom + 0.02 {
                playerY = top - 0.025
                velocityY = 0
                score += 1
                recordResult(success: true)
                return
            }
        }
    }

    private func recordResult(success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
            recentResults = []
            withAnimation { showDifficultyBump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showDifficultyBump = false }
            }
        }
    }

    private func endGame() {
        timer?.invalidate()
        if score > highScore { highScore = score }
        recentResults.append(false)
        phase = .over
    }
}

#Preview { InfinityHopView() }

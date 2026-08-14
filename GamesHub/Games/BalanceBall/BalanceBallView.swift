import SwiftUI

enum BalanceBallGamePhase {
    case start, playing, gameOver
}

struct BalanceBallView: View {
    @State private var phase: BalanceBallGamePhase = .start
    @AppStorage("balanceBallBestScore") private var bestScore: Int = 0
    @State private var platformAngle: Double = 0.0
    @State private var ballX: Double = 0.0
    @State private var ballVelocity: Double = 0.0
    @State private var lives: Int = 3
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    let platformWidth: Double = 240
    let platformHeight: Double = 16
    let ballRadius: Double = 14
    let baseTiltAngle: Double = 12.0
    let baseGravity: Double = 0.6

    var effectiveTiltAngle: Double { baseTiltAngle * difficultyMultiplier }
    var effectiveGravity: Double { baseGravity * difficultyMultiplier }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.1, green: 0.1, blue: 0.35), Color(red: 0.25, green: 0.05, blue: 0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()

                if phase == .start {
                    startScreen
                } else if phase == .playing {
                    gameScreen(geo: geo)
                } else {
                    gameOverScreen
                }
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BALANCE BALL")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)

            Text("Tap left/right to tilt the platform\nKeep the ball balanced!")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            if difficultyMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0f%%", difficultyMultiplier * 100))")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
            }

            Button(action: startGame) {
                Text("START GAME")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 32, weight: .black))
                .foregroundColor(.red.opacity(0.9))

            Text("Final Score")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)

            Text("\(score)")
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)

            Text("Difficulty: \(String(format: "%.0f%%", difficultyMultiplier * 100))")
                .font(.caption)
                .foregroundColor(.yellow.opacity(0.8))

            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color.purple, Color.blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Tap zones
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tiltLeft() }
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { tiltRight() }
            }

            // HUD
            VStack {
                HStack {
                    // Lives panel
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(i < lives ? Color.red : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))

                    Spacer()

                    // Score panel
                    Text("\(score)")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                }
                .padding()

                if difficultyMultiplier > 1.0 {
                    Text("SPEED x\(String(format: "%.1f", difficultyMultiplier))")
                        .font(.caption2.bold())
                        .foregroundColor(.yellow)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.yellow.opacity(0.3), lineWidth: 1))
                }

                Spacer()
            }

            // Platform and ball
            VStack {
                Spacer()
                ZStack {
                    // Ball with glow
                    Circle()
                        .fill(
                            RadialGradient(colors: [.white, .yellow, .orange], center: .topLeading, startRadius: 2, endRadius: ballRadius * 2)
                        )
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .shadow(color: .yellow.opacity(0.6), radius: 8)
                        .offset(x: ballX, y: -(platformHeight / 2 + ballRadius))

                    // Platform
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.ultraThinMaterial)
                        .frame(width: platformWidth, height: platformHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.5), lineWidth: 1)
                        )
                        .shadow(color: .white.opacity(0.1), radius: 4)
                }
                .rotationEffect(.degrees(platformAngle))
                Spacer().frame(height: geo.size.height * 0.25)
            }

            // Tap hints
            VStack {
                Spacer()
                HStack {
                    Text("◀ LEFT")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.caption)
                    Spacer()
                    Text("RIGHT ▶")
                        .foregroundColor(.white.opacity(0.4))
                        .font(.caption)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    func startGame() {
        ballX = 0
        ballVelocity = 0
        platformAngle = 0
        lives = 3
        score = 0
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            updatePhysics()
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if phase == .playing {
                score += 1
            } else {
                t.invalidate()
            }
        }
    }

    func tiltLeft() {
        guard phase == .playing else { return }
        platformAngle = -effectiveTiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func tiltRight() {
        guard phase == .playing else { return }
        platformAngle = effectiveTiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func updatePhysics() {
        let angleRad = platformAngle * .pi / 180.0
        let accel = effectiveGravity * sin(angleRad)
        ballVelocity += accel
        ballVelocity *= 0.98
        ballX += ballVelocity

        let halfPlatform = platformWidth / 2 - ballRadius
        if abs(ballX) > halfPlatform {
            ballFell()
        }
    }

    func ballFell() {
        let survived = score > 5
        recentResults.append(survived)
        if recentResults.count > 5 { recentResults.removeFirst() }

        // If last 5 results have >4 trues, increase difficulty by ~20%
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
            recentResults = []
        }

        ballX = 0
        ballVelocity = 0
        platformAngle = 0
        lives -= 1
        if lives <= 0 {
            gameTimer?.invalidate()
            bestScore = max(bestScore, score)
            phase = .gameOver
        }
    }
}

#Preview { BalanceBallView() }

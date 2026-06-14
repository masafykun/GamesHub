import SwiftUI

enum BlBlGamePhase {
    case start, playing, gameOver
}

struct BalanceBallView: View {
    @State private var phase: BlBlGamePhase = .start
    @State private var platformAngle: Double = 0.0
    @State private var ballX: Double = 0.0
    @State private var ballVelocity: Double = 0.0
    @State private var lives: Int = 3
    @State private var score: Int = 0
    @State private var gameTimer: Timer? = nil

    let platformWidth: Double = 240
    let platformHeight: Double = 16
    let ballRadius: Double = 14
    let tiltAngle: Double = 12.0
    let gravity: Double = 0.6

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("BALANCE BALL")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
            Text("Tap left/right to tilt the platform\nKeep the ball balanced!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button(action: startGame) {
                Text("START")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.red)
            Text("Score: \(score)")
                .font(.title)
                .foregroundColor(.white)
            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .cornerRadius(12)
            }
        }
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
                    Text("Lives: \(String(repeating: "❤️", count: lives))")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Score: \(score)")
                        .font(.headline)
                        .foregroundColor(.yellow)
                }
                .padding()
                Spacer()
            }

            // Platform and ball
            VStack {
                Spacer()
                ZStack {
                    // Ball
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: ballRadius * 2, height: ballRadius * 2)
                        .offset(x: ballX, y: -(platformHeight / 2 + ballRadius))

                    // Platform
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white)
                        .frame(width: platformWidth, height: platformHeight)
                }
                .rotationEffect(.degrees(platformAngle))
                Spacer().frame(height: geo.size.height * 0.25)
            }

            // Tap hint arrows
            VStack {
                Spacer()
                HStack {
                    Text("◀ Tilt Left")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Spacer()
                    Text("Tilt Right ▶")
                        .foregroundColor(.gray)
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
        platformAngle = -tiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func tiltRight() {
        guard phase == .playing else { return }
        platformAngle = tiltAngle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.2)) { platformAngle = 0 }
        }
    }

    func updatePhysics() {
        let angleRad = platformAngle * .pi / 180.0
        let accel = gravity * sin(angleRad)
        ballVelocity += accel
        ballVelocity *= 0.98
        ballX += ballVelocity

        let halfPlatform = platformWidth / 2 - ballRadius
        if abs(ballX) > halfPlatform {
            ballFell()
        }
    }

    func ballFell() {
        ballX = 0
        ballVelocity = 0
        platformAngle = 0
        lives -= 1
        if lives <= 0 {
            gameTimer?.invalidate()
            phase = .gameOver
        }
    }
}

#Preview { BalanceBallView() }

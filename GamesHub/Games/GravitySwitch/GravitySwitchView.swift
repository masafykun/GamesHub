import SwiftUI

// MARK: - Models

struct GravitySwitchObstacle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var gapY: CGFloat
    var gapHeight: CGFloat
}

enum GravitySwitchState {
    case waiting
    case playing
    case dead
}

// MARK: - ViewModel

class GravitySwitchViewModel: ObservableObject {
    @Published var playerY: CGFloat = 0
    @Published var playerVelocityY: CGFloat = 0
    @Published var gravityUp: Bool = false
    @Published var obstacles: [GravitySwitchObstacle] = []
    @Published var score: Int = 0
    @Published var highScore: Int = 0
    @Published var gameState: GravitySwitchState = .waiting
    @Published var speed: CGFloat = 150

    var canvasWidth: CGFloat = 390
    var canvasHeight: CGFloat = 844

    let playerX: CGFloat = 80
    let playerSize: CGFloat = 28
    let obstacleWidth: CGFloat = 22
    let obstacleSpacing: CGFloat = 230
    let baseSpeed: CGFloat = 150
    let gravity: CGFloat = 900
    let flipImpulse: CGFloat = 400

    private var timer: Timer?
    private var distanceTraveled: CGFloat = 0
    private var timePlayed: CGFloat = 0
    private var nextObstacleX: CGFloat = 0

    func setup(width: CGFloat, height: CGFloat) {
        canvasWidth = width
        canvasHeight = height
        playerY = height / 2
        nextObstacleX = width + 100
        obstacles = []
    }

    func startGame() {
        playerY = canvasHeight / 2
        playerVelocityY = 0
        gravityUp = false
        obstacles = []
        score = 0
        speed = baseSpeed
        distanceTraveled = 0
        timePlayed = 0
        nextObstacleX = canvasWidth + 100
        gameState = .playing
        startTimer()
    }

    func flipGravity() {
        guard gameState == .playing else { return }
        gravityUp.toggle()
        playerVelocityY = gravityUp ? -flipImpulse : flipImpulse
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        if let t = timer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func update() {
        guard gameState == .playing else { return }

        let dt: CGFloat = 1.0 / 60.0
        timePlayed += dt

        // Increase speed over time
        speed = baseSpeed + timePlayed * 18

        // Apply gravity
        let gravityDir: CGFloat = gravityUp ? -1 : 1
        playerVelocityY += gravityDir * gravity * dt
        playerVelocityY = max(-900, min(900, playerVelocityY))
        playerY += playerVelocityY * dt

        // Clamp player to screen bounds (collision with top/bottom walls)
        let halfPlayer = playerSize / 2
        if playerY - halfPlayer <= 0 || playerY + halfPlayer >= canvasHeight {
            triggerDeath()
            return
        }

        // Move obstacles
        let dx = speed * dt
        distanceTraveled += dx

        for i in obstacles.indices {
            obstacles[i].x -= dx
        }

        // Spawn new obstacles
        if nextObstacleX - distanceTraveled < canvasWidth + 50 {
            spawnObstacle(atX: nextObstacleX - distanceTraveled + canvasWidth)
            nextObstacleX += obstacleSpacing
        }

        // Remove off-screen obstacles
        obstacles.removeAll { $0.x < -obstacleWidth - 10 }

        // Collision detection
        for obs in obstacles {
            if checkCollision(obs) {
                triggerDeath()
                return
            }
        }

        // Update score
        score = Int(distanceTraveled / 10)
    }

    private func spawnObstacle(atX x: CGFloat) {
        let minGap: CGFloat = 130
        let maxGap: CGFloat = 200
        let gapH = CGFloat.random(in: minGap...maxGap)
        let minY = gapH / 2 + 20
        let maxY = canvasHeight - gapH / 2 - 20
        let gapY = CGFloat.random(in: minY...maxY)
        obstacles.append(GravitySwitchObstacle(x: x, gapY: gapY, gapHeight: gapH))
    }

    private func checkCollision(_ obs: GravitySwitchObstacle) -> Bool {
        let pLeft = playerX - playerSize / 2
        let pRight = playerX + playerSize / 2
        let pTop = playerY - playerSize / 2
        let pBottom = playerY + playerSize / 2

        let oLeft = obs.x - obstacleWidth / 2
        let oRight = obs.x + obstacleWidth / 2

        guard pRight > oLeft && pLeft < oRight else { return false }

        // Top bar: from 0 to (gapY - gapHeight/2)
        let topBarBottom = obs.gapY - obs.gapHeight / 2
        // Bottom bar: from (gapY + gapHeight/2) to canvasHeight
        let bottomBarTop = obs.gapY + obs.gapHeight / 2

        if pTop < topBarBottom || pBottom > bottomBarTop {
            return true
        }
        return false
    }

    private func triggerDeath() {
        gameState = .dead
        if score > highScore {
            highScore = score
        }
        stopTimer()
    }
}

// MARK: - Main View

struct GravitySwitchView: View {
    @StateObject private var vm = GravitySwitchViewModel()
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color(red: 0.1, green: 0.0, blue: 0.25)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                if vm.gameState == .waiting {
                    GravitySwitchStartScreen()
                        .onTapGesture {
                            vm.setup(width: geo.size.width, height: geo.size.height)
                            vm.startGame()
                        }
                } else {
                    // Game canvas
                    GravitySwitchCanvas(vm: vm)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { _ in
                                    if vm.gameState == .playing {
                                        vm.flipGravity()
                                    }
                                }
                        )

                    // HUD
                    VStack {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SCORE")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(vm.score)")
                                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("BEST")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("\(vm.highScore)")
                                    .font(.system(size: 22, weight: .heavy, design: .monospaced))
                                    .foregroundColor(Color(red: 0.6, green: 0.9, blue: 1.0))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        Spacer()
                    }

                    // Death overlay
                    if vm.gameState == .dead {
                        GravitySwitchDeathOverlay(vm: vm)
                    }
                }
            }
            .onAppear {
                canvasSize = geo.size
                vm.setup(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Canvas

struct GravitySwitchCanvas: View {
    @ObservedObject var vm: GravitySwitchViewModel

    var body: some View {
        Canvas { ctx, size in
            // Draw obstacles
            for obs in vm.obstacles {
                let topBarHeight = obs.gapY - obs.gapHeight / 2
                let bottomBarTop = obs.gapY + obs.gapHeight / 2
                let bottomBarHeight = size.height - bottomBarTop

                // Top bar
                let topRect = CGRect(x: obs.x - vm.obstacleWidth / 2, y: 0, width: vm.obstacleWidth, height: topBarHeight)
                ctx.fill(Path(topRect), with: .color(Color(red: 0.9, green: 0.3, blue: 0.5)))

                // Bottom bar
                let botRect = CGRect(x: obs.x - vm.obstacleWidth / 2, y: bottomBarTop, width: vm.obstacleWidth, height: bottomBarHeight)
                ctx.fill(Path(botRect), with: .color(Color(red: 0.9, green: 0.3, blue: 0.5)))

                // Highlight edges
                let topEdge = CGRect(x: obs.x - vm.obstacleWidth / 2, y: topBarHeight - 3, width: vm.obstacleWidth, height: 3)
                ctx.fill(Path(topEdge), with: .color(Color(red: 1.0, green: 0.5, blue: 0.7)))

                let botEdge = CGRect(x: obs.x - vm.obstacleWidth / 2, y: bottomBarTop, width: vm.obstacleWidth, height: 3)
                ctx.fill(Path(botEdge), with: .color(Color(red: 1.0, green: 0.5, blue: 0.7)))
            }

            // Draw player
            let pRect = CGRect(
                x: vm.playerX - vm.playerSize / 2,
                y: vm.playerY - vm.playerSize / 2,
                width: vm.playerSize,
                height: vm.playerSize
            )
            // Glow effect (slightly larger, transparent)
            let glowRect = pRect.insetBy(dx: -6, dy: -6)
            ctx.fill(RoundedRectangle(cornerRadius: 8).path(in: glowRect), with: .color(Color(red: 0.3, green: 0.8, blue: 1.0).opacity(0.25)))

            ctx.fill(RoundedRectangle(cornerRadius: 5).path(in: pRect), with: .color(Color(red: 0.3, green: 0.9, blue: 1.0)))

            // Gravity arrow indicator
            let arrowY = vm.gravityUp
                ? vm.playerY - vm.playerSize / 2 - 16
                : vm.playerY + vm.playerSize / 2 + 16
            let arrowPath = Path { p in
                if vm.gravityUp {
                    p.move(to: CGPoint(x: vm.playerX, y: arrowY))
                    p.addLine(to: CGPoint(x: vm.playerX - 6, y: arrowY + 9))
                    p.addLine(to: CGPoint(x: vm.playerX + 6, y: arrowY + 9))
                    p.closeSubpath()
                } else {
                    p.move(to: CGPoint(x: vm.playerX, y: arrowY))
                    p.addLine(to: CGPoint(x: vm.playerX - 6, y: arrowY - 9))
                    p.addLine(to: CGPoint(x: vm.playerX + 6, y: arrowY - 9))
                    p.closeSubpath()
                }
            }
            ctx.fill(arrowPath, with: .color(Color.white.opacity(0.7)))

            // Floor & ceiling lines
            let ceiling = Path { p in
                p.move(to: CGPoint(x: 0, y: 2))
                p.addLine(to: CGPoint(x: size.width, y: 2))
            }
            ctx.stroke(ceiling, with: .color(Color.white.opacity(0.25)), lineWidth: 2)

            let floor = Path { p in
                p.move(to: CGPoint(x: 0, y: size.height - 2))
                p.addLine(to: CGPoint(x: size.width, y: size.height - 2))
            }
            ctx.stroke(floor, with: .color(Color.white.opacity(0.25)), lineWidth: 2)
        }
    }
}

// MARK: - Start Screen

struct GravitySwitchStartScreen: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            VStack(spacing: 8) {
                Text("GRAVITY")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("SWITCH")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
            }

            Text("Tap to flip gravity\nAvoid the obstacles")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()

            Text("TAP TO START")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            Spacer()
        }
    }
}

// MARK: - Death Overlay

struct GravitySwitchDeathOverlay: View {
    @ObservedObject var vm: GravitySwitchViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("GAME OVER")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.5))

                VStack(spacing: 8) {
                    Text("SCORE: \(vm.score)")
                        .font(.system(size: 28, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("BEST: \(vm.highScore)")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.6, green: 0.9, blue: 1.0))
                }

                Button {
                    vm.startGame()
                } label: {
                    Text("PLAY AGAIN")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.3, green: 0.9, blue: 1.0))
                        )
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(red: 0.1, green: 0.05, blue: 0.2))
                    .shadow(color: .black.opacity(0.5), radius: 20)
            )
            .padding(.horizontal, 40)
        }
    }
}

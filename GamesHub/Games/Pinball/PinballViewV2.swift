import SwiftUI

// MARK: - Models
struct PnBV2Bumper {
    var position: CGPoint
    var isLit: Bool = false
}

enum PnBV2Phase {
    case start, playing, gameOver
}

// MARK: - PinballViewV2 (Glassmorphism + Adaptive Difficulty)
struct PinballViewV2: View {
    @State private var phase: PnBV2Phase = .start
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = CGPoint(x: 2.5, y: -5.0)
    @State private var leftFlipper: Bool = false
    @State private var rightFlipper: Bool = false
    @State private var score: Int = 0
    @State private var ballsLeft: Int = 3
    @State private var bumpers: [PnBV2Bumper] = []
    @State private var gameTimer: Timer? = nil
    @State private var fieldSize: CGSize = .zero
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    let ballRadius: CGFloat = 10
    let flipperWidth: CGFloat = 72
    let flipperHeight: CGFloat = 12
    let bumperRadius: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25),
                                        Color(red: 0.15, green: 0.05, blue: 0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .gameOver:
                    gameOverScreen
                }
            }
            .onAppear { fieldSize = geo.size }
            .onChange(of: geo.size) { fieldSize = $0 }
        }
    }

    // MARK: - Glass Panel Helper
    func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            Text("PINBALL")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .purple, radius: 12)
            glassPanel {
                VStack(spacing: 8) {
                    Text("3 Balls · 6 Bumpers (+100 each)").foregroundColor(.white.opacity(0.9))
                    Text("Tap left/right to flip").foregroundColor(.white.opacity(0.7)).font(.subheadline)
                    if !recentResults.isEmpty {
                        Text("Difficulty: \(speedMultiplier > 1.2 ? "Hard" : speedMultiplier > 1.05 ? "Medium" : "Normal")")
                            .foregroundColor(.yellow).font(.caption).bold()
                    }
                }.padding(20)
            }
            Button { startGame() } label: {
                Text("PLAY")
                    .font(.headline).bold()
                    .padding(.horizontal, 50).padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1))
                    .foregroundColor(.white)
            }
        }.padding(30)
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 38, weight: .black)).foregroundColor(.red)
                .shadow(color: .red, radius: 8)
            glassPanel {
                VStack(spacing: 6) {
                    Text("Score: \(score)").font(.title2).bold().foregroundColor(.white)
                    Text("Speed x\(String(format: "%.2f", speedMultiplier))").foregroundColor(.yellow).font(.caption)
                }.padding(20)
            }
            Button { startGame() } label: {
                Text("PLAY AGAIN")
                    .font(.headline).bold()
                    .padding(.horizontal, 40).padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.5), lineWidth: 1))
                    .foregroundColor(.white)
            }
        }.padding(30)
    }

    // MARK: - Game Screen
    func gameScreen(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let flipY = h - 62
        let leftX = w * 0.25
        let rightX = w * 0.75

        return ZStack {
            // Bumpers
            ForEach(bumpers.indices, id: \.self) { i in
                Circle()
                    .fill(bumpers[i].isLit
                          ? LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                          : LinearGradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                    .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1.5))
                    .frame(width: bumperRadius * 2, height: bumperRadius * 2)
                    .shadow(color: bumpers[i].isLit ? .yellow : .purple, radius: 6)
                    .position(bumpers[i].position)
            }
            // Ball
            Circle()
                .fill(RadialGradient(colors: [.white, .cyan.opacity(0.8)], center: .topLeading, startRadius: 1, endRadius: ballRadius * 2))
                .frame(width: ballRadius * 2, height: ballRadius * 2)
                .shadow(color: .cyan, radius: 6)
                .position(ballPos)
            // Flippers
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .frame(width: flipperWidth, height: flipperHeight)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.4), lineWidth: 1))
                .rotationEffect(.degrees(leftFlipper ? -30 : 20), anchor: .leading)
                .position(x: leftX + flipperWidth / 2, y: flipY)
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                .frame(width: flipperWidth, height: flipperHeight)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.4), lineWidth: 1))
                .rotationEffect(.degrees(rightFlipper ? 30 : -20), anchor: .trailing)
                .position(x: rightX - flipperWidth / 2, y: flipY)
            // HUD
            VStack {
                glassPanel {
                    HStack(spacing: 20) {
                        Label("\(score)", systemImage: "star.fill").foregroundColor(.yellow)
                        Spacer()
                        Label("\(ballsLeft)", systemImage: "circle.fill").foregroundColor(.cyan)
                    }.padding(.horizontal, 16).padding(.vertical, 8)
                }
                .padding(.horizontal, 16).padding(.top, 50)
                Spacer()
            }
            // Tap zones
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in leftFlipper = true }
                        .onEnded { _ in leftFlipper = false })
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in rightFlipper = true }
                        .onEnded { _ in rightFlipper = false })
            }
        }
    }

    // MARK: - Game Logic
    func startGame() {
        // Adaptive difficulty from last 5 results
        if recentResults.count >= 5 {
            let last5 = recentResults.suffix(5)
            let wins = last5.filter { $0 }.count
            if wins > 4 { speedMultiplier = min(speedMultiplier * 1.2, 2.5) }
        }
        score = 0
        ballsLeft = 3
        phase = .playing
        setupBumpers()
        launchBall()
    }

    func setupBumpers() {
        let w = fieldSize.width
        let h = fieldSize.height
        bumpers = [
            PnBV2Bumper(position: CGPoint(x: w * 0.25, y: h * 0.18)),
            PnBV2Bumper(position: CGPoint(x: w * 0.75, y: h * 0.18)),
            PnBV2Bumper(position: CGPoint(x: w * 0.50, y: h * 0.26)),
            PnBV2Bumper(position: CGPoint(x: w * 0.20, y: h * 0.36)),
            PnBV2Bumper(position: CGPoint(x: w * 0.80, y: h * 0.36)),
            PnBV2Bumper(position: CGPoint(x: w * 0.50, y: h * 0.44)),
        ]
    }

    func launchBall() {
        let w = fieldSize.width
        let h = fieldSize.height
        ballPos = CGPoint(x: w / 2, y: h * 0.58)
        let spd = speedMultiplier
        ballVel = CGPoint(x: CGFloat.random(in: -1.5...1.5) * spd, y: -5.0 * spd)
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            updateGame()
        }
    }

    func updateGame() {
        let w = fieldSize.width
        let h = fieldSize.height
        var vx = ballVel.x
        var vy = ballVel.y
        var px = ballPos.x + vx
        var py = ballPos.y + vy

        if px - ballRadius < 0 { px = ballRadius; vx = abs(vx) }
        if px + ballRadius > w { px = w - ballRadius; vx = -abs(vx) }
        if py - ballRadius < 0 { py = ballRadius; vy = abs(vy) }

        let flipY = h - 62
        let leftX = w * 0.25
        let rightX = w * 0.75

        if checkFlipperV2(px: px, py: py, flipX: leftX, flipY: flipY, angle: leftFlipper ? -30 : 20, side: .left) {
            vy = -abs(vy) * speedMultiplier - 1
            vx += leftFlipper ? -1.5 : 0
            py = flipY - ballRadius - 2
        }
        if checkFlipperV2(px: px, py: py, flipX: rightX, flipY: flipY, angle: rightFlipper ? 30 : -20, side: .right) {
            vy = -abs(vy) * speedMultiplier - 1
            vx += rightFlipper ? 1.5 : 0
            py = flipY - ballRadius - 2
        }

        for i in bumpers.indices {
            let dx = px - bumpers[i].position.x
            let dy = py - bumpers[i].position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < ballRadius + bumperRadius {
                score += 100
                bumpers[i].isLit = true
                let nx = dx / dist; let ny = dy / dist
                let dot = vx * nx + vy * ny
                vx -= 2 * dot * nx * speedMultiplier
                vy -= 2 * dot * ny * speedMultiplier
                vy -= 1
                px = bumpers[i].position.x + nx * (ballRadius + bumperRadius + 1)
                py = bumpers[i].position.y + ny * (ballRadius + bumperRadius + 1)
                let idx = i
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if idx < bumpers.count { bumpers[idx].isLit = false }
                }
            }
        }

        if py > h + ballRadius {
            gameTimer?.invalidate()
            ballsLeft -= 1
            if ballsLeft <= 0 {
                recentResults.append(score >= 500)
                if recentResults.count > 20 { recentResults.removeFirst() }
                phase = .gameOver
            } else {
                launchBall()
            }
            return
        }

        ballPos = CGPoint(x: px, y: py)
        ballVel = CGPoint(x: vx, y: vy)
    }

    enum PnBV2Side { case left, right }

    func checkFlipperV2(px: CGFloat, py: CGFloat, flipX: CGFloat, flipY: CGFloat, angle: Double, side: PnBV2Side) -> Bool {
        let rad = angle * .pi / 180
        let dx = px - flipX; let dy = py - flipY
        let lx = dx * cos(-rad) - dy * sin(-rad)
        let ly = dx * sin(-rad) + dy * cos(-rad)
        let rangeMin: CGFloat = side == .left ? 0 : -flipperWidth
        let rangeMax: CGFloat = side == .left ? flipperWidth : 0
        return lx >= rangeMin && lx <= rangeMax && ly >= -ballRadius - flipperHeight && ly <= ballRadius
    }
}

#Preview { PinballViewV2() }

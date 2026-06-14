import SwiftUI

// MARK: - Models
struct PnBBumper {
    var position: CGPoint
    var isLit: Bool = false
}

enum PnBGamePhase {
    case start, playing, gameOver
}

// MARK: - PinballView
struct PinballView: View {
    @State private var phase: PnBGamePhase = .start
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = CGPoint(x: 2.5, y: 4.0)
    @State private var leftFlipper: Bool = false
    @State private var rightFlipper: Bool = false
    @State private var score: Int = 0
    @State private var ballsLeft: Int = 3
    @State private var bumpers: [PnBBumper] = []
    @State private var timer: Timer? = nil
    @State private var fieldSize: CGSize = .zero

    let ballRadius: CGFloat = 10
    let flipperWidth: CGFloat = 70
    let flipperHeight: CGFloat = 12
    let bumperRadius: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
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

    // MARK: Start Screen
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("PINBALL").font(.largeTitle).bold().foregroundColor(.yellow)
            Text("3 Balls · 6 Bumpers").foregroundColor(.gray)
            Text("Tap left/right side\nto control flippers").multilineTextAlignment(.center).foregroundColor(.white)
            Button("PLAY") { startGame() }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.yellow).foregroundColor(.black).cornerRadius(12)
        }
    }

    // MARK: Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.largeTitle).bold().foregroundColor(.red)
            Text("Score: \(score)").font(.title2).foregroundColor(.white)
            Button("PLAY AGAIN") { startGame() }
                .font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.yellow).foregroundColor(.black).cornerRadius(12)
        }
    }

    // MARK: Game Screen
    func gameScreen(geo: GeometryProxy) -> some View {
        let w = geo.size.width
        let h = geo.size.height
        let flipY = h - 60
        let leftX = w * 0.25
        let rightX = w * 0.75

        return ZStack {
            // Bumpers
            ForEach(bumpers.indices, id: \.self) { i in
                Circle()
                    .fill(bumpers[i].isLit ? Color.yellow : Color.orange.opacity(0.7))
                    .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                    .frame(width: bumperRadius * 2, height: bumperRadius * 2)
                    .position(bumpers[i].position)
            }
            // Ball
            Circle()
                .fill(Color.white)
                .frame(width: ballRadius * 2, height: ballRadius * 2)
                .position(ballPos)
            // Left Flipper
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.cyan)
                .frame(width: flipperWidth, height: flipperHeight)
                .rotationEffect(.degrees(leftFlipper ? -30 : 20), anchor: .leading)
                .position(x: leftX + flipperWidth / 2, y: flipY)
            // Right Flipper
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.cyan)
                .frame(width: flipperWidth, height: flipperHeight)
                .rotationEffect(.degrees(rightFlipper ? 30 : -20), anchor: .trailing)
                .position(x: rightX - flipperWidth / 2, y: flipY)
            // HUD
            VStack {
                HStack {
                    Text("Score: \(score)").foregroundColor(.white).font(.headline)
                    Spacer()
                    Text("Balls: \(ballsLeft)").foregroundColor(.white).font(.headline)
                }.padding(.horizontal, 20).padding(.top, 50)
                Spacer()
            }
            // Tap zones
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in leftFlipper = true }
                        .onEnded { _ in leftFlipper = false })
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in rightFlipper = true }
                        .onEnded { _ in rightFlipper = false })
            }
        }
    }

    // MARK: Game Logic
    func startGame() {
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
            PnBBumper(position: CGPoint(x: w * 0.25, y: h * 0.20)),
            PnBBumper(position: CGPoint(x: w * 0.75, y: h * 0.20)),
            PnBBumper(position: CGPoint(x: w * 0.50, y: h * 0.28)),
            PnBBumper(position: CGPoint(x: w * 0.20, y: h * 0.38)),
            PnBBumper(position: CGPoint(x: w * 0.80, y: h * 0.38)),
            PnBBumper(position: CGPoint(x: w * 0.50, y: h * 0.46)),
        ]
    }

    func launchBall() {
        let w = fieldSize.width
        let h = fieldSize.height
        ballPos = CGPoint(x: w / 2, y: h * 0.6)
        ballVel = CGPoint(x: CGFloat.random(in: -2...2), y: -5)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
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

        // Wall bounces
        if px - ballRadius < 0 { px = ballRadius; vx = abs(vx) }
        if px + ballRadius > w { px = w - ballRadius; vx = -abs(vx) }
        if py - ballRadius < 0 { py = ballRadius; vy = abs(vy) }

        // Flipper collisions
        let flipY = h - 60
        let leftX = w * 0.25
        let rightX = w * 0.75
        let leftAngle = leftFlipper ? -30.0 : 20.0
        let rightAngle = rightFlipper ? 30.0 : -20.0
        if checkFlipper(px: px, py: py, flipX: leftX, flipY: flipY, angle: leftAngle, side: .left) {
            vy = -abs(vy) - 1; vx += leftFlipper ? -1.5 : 0
            py = flipY - ballRadius - 2
        }
        if checkFlipper(px: px, py: py, flipX: rightX, flipY: flipY, angle: rightAngle, side: .right) {
            vy = -abs(vy) - 1; vx += rightFlipper ? 1.5 : 0
            py = flipY - ballRadius - 2
        }

        // Bumper collisions
        for i in bumpers.indices {
            let dx = px - bumpers[i].position.x
            let dy = py - bumpers[i].position.y
            let dist = sqrt(dx * dx + dy * dy)
            if dist < ballRadius + bumperRadius {
                score += 100
                bumpers[i].isLit = true
                let nx = dx / dist; let ny = dy / dist
                let dot = vx * nx + vy * ny
                vx -= 2 * dot * nx; vy -= 2 * dot * ny
                vy -= 1
                px = bumpers[i].position.x + nx * (ballRadius + bumperRadius + 1)
                py = bumpers[i].position.y + ny * (ballRadius + bumperRadius + 1)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { if i < bumpers.count { bumpers[i].isLit = false } }
            }
        }

        // Ball lost
        if py > h + ballRadius {
            timer?.invalidate()
            ballsLeft -= 1
            if ballsLeft <= 0 { phase = .gameOver } else { launchBall() }
            return
        }

        ballPos = CGPoint(x: px, y: py)
        ballVel = CGPoint(x: vx, y: vy)
    }

    enum PnBSide { case left, right }

    func checkFlipper(px: CGFloat, py: CGFloat, flipX: CGFloat, flipY: CGFloat, angle: Double, side: PnBSide) -> Bool {
        let rad = angle * .pi / 180
        let anchorX: CGFloat = side == .left ? flipX : flipX
        let dx = px - anchorX
        let dy = py - flipY
        let lx = dx * cos(-rad) - dy * sin(-rad)
        let ly = dx * sin(-rad) + dy * cos(-rad)
        let rangeMin: CGFloat = side == .left ? 0 : -flipperWidth
        let rangeMax: CGFloat = side == .left ? flipperWidth : 0
        return lx >= rangeMin && lx <= rangeMax && ly >= -ballRadius - flipperHeight && ly <= ballRadius
    }
}

#Preview { PinballView() }

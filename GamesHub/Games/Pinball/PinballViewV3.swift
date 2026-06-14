import SwiftUI

// MARK: - LCG Seeded RNG
struct PnBLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models
struct PnBV3Bumper {
    var position: CGPoint
    var isLit: Bool = false
    var color: Color
}

enum PnBV3Phase {
    case start, playing, gameOver
}

// MARK: - PinballViewV3 (Neumorphism + Seeded Generation)
struct PinballViewV3: View {
    @State private var phase: PnBV3Phase = .start
    @State private var ballPos: CGPoint = .zero
    @State private var ballVel: CGPoint = CGPoint(x: 2.0, y: -5.0)
    @State private var leftFlipper: Bool = false
    @State private var rightFlipper: Bool = false
    @State private var score: Int = 0
    @State private var ballsLeft: Int = 3
    @State private var bumpers: [PnBV3Bumper] = []
    @State private var gameTimer: Timer? = nil
    @State private var fieldSize: CGSize = .zero
    @State private var seedInt: Int = 1

    let ballRadius: CGFloat = 10
    let flipperWidth: CGFloat = 72
    let flipperHeight: CGFloat = 12
    let bumperRadius: CGFloat = 18

    let bumperColors: [Color] = [.orange, .pink, .purple, .blue, .green, .red]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
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

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            Text("PINBALL")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(Color(.darkGray))
            VStack(spacing: 10) {
                Text("3 Balls · 6 Bumpers").foregroundColor(.secondary)
                Text("Tap left/right to flip").font(.subheadline).foregroundColor(.secondary)
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            Button { startGame() } label: {
                Text("PLAY")
                    .font(.headline).bold()
                    .foregroundColor(Color(.darkGray))
                    .padding(.horizontal, 50).padding(.vertical, 16)
            }
            .neumorphicCard(radius: 14)
        }.padding(30)
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(Color(.darkGray))
            VStack(spacing: 8) {
                Text("Score: \(score)").font(.title2).bold().foregroundColor(Color(.darkGray))
                Text("SEED: #\(seedInt - 1)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            Button { startGame() } label: {
                Text("PLAY AGAIN")
                    .font(.headline).bold()
                    .foregroundColor(Color(.darkGray))
                    .padding(.horizontal, 40).padding(.vertical, 16)
            }
            .neumorphicCard(radius: 14)
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
                ZStack {
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: bumperRadius * 2 + 6, height: bumperRadius * 2 + 6)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 3, y: 3)
                        .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                    Circle()
                        .fill(bumpers[i].isLit ? bumpers[i].color : bumpers[i].color.opacity(0.4))
                        .frame(width: bumperRadius * 2, height: bumperRadius * 2)
                }
                .position(bumpers[i].position)
            }
            // Ball
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: ballRadius * 2 + 4, height: ballRadius * 2 + 4)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.9), radius: 3, x: -2, y: -2)
                Circle()
                    .fill(Color(.darkGray))
                    .frame(width: ballRadius * 2, height: ballRadius * 2)
            }
            .position(ballPos)
            // Flippers
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .frame(width: flipperWidth + 4, height: flipperHeight + 4)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                RoundedRectangle(cornerRadius: 6)
                    .fill(leftFlipper ? Color.blue.opacity(0.7) : Color(.systemGray4))
                    .frame(width: flipperWidth, height: flipperHeight)
            }
            .rotationEffect(.degrees(leftFlipper ? -30 : 20), anchor: .leading)
            .position(x: leftX + flipperWidth / 2, y: flipY)

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray6))
                    .frame(width: flipperWidth + 4, height: flipperHeight + 4)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                RoundedRectangle(cornerRadius: 6)
                    .fill(rightFlipper ? Color.blue.opacity(0.7) : Color(.systemGray4))
                    .frame(width: flipperWidth, height: flipperHeight)
            }
            .rotationEffect(.degrees(rightFlipper ? 30 : -20), anchor: .trailing)
            .position(x: rightX - flipperWidth / 2, y: flipY)

            // HUD
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Score: \(score)").font(.headline).foregroundColor(Color(.darkGray))
                        Text("SEED: #\(seedInt)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Text("Balls: \(ballsLeft)").font(.headline).foregroundColor(Color(.darkGray))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .neumorphicCard(radius: 12)
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
        score = 0
        ballsLeft = 3
        phase = .playing
        setupBumpers(seed: seedInt)
        launchBall(seed: seedInt)
        seedInt += 1
    }

    func setupBumpers(seed: Int) {
        var rng = PnBLCG(seed: seed)
        let w = fieldSize.width
        let h = fieldSize.height
        let cols: [CGFloat] = [0.20, 0.50, 0.80]
        let rows: [CGFloat] = [0.18, 0.30, 0.40]
        var positions: [CGPoint] = []
        for row in rows {
            for col in cols {
                positions.append(CGPoint(x: w * col, y: h * row))
            }
        }
        // Shuffle positions with LCG and pick 6
        for i in stride(from: positions.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            positions.swapAt(i, j)
        }
        bumpers = (0..<6).map { i in
            let colorIdx = rng.nextInt(bumperColors.count)
            return PnBV3Bumper(position: positions[i], color: bumperColors[colorIdx])
        }
    }

    func launchBall(seed: Int) {
        var rng = PnBLCG(seed: seed &+ 999)
        let w = fieldSize.width
        let h = fieldSize.height
        ballPos = CGPoint(x: w / 2, y: h * 0.58)
        let vxSign = rng.nextDouble() > 0.5 ? 1.0 : -1.0
        let vxMag = 1.0 + rng.nextDouble() * 2.0
        ballVel = CGPoint(x: vxSign * vxMag, y: -5.0)
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

        if checkFlipperV3(px: px, py: py, flipX: leftX, flipY: flipY, angle: leftFlipper ? -30 : 20, isLeft: true) {
            vy = -abs(vy) - 1
            vx += leftFlipper ? -1.5 : 0
            py = flipY - ballRadius - 2
        }
        if checkFlipperV3(px: px, py: py, flipX: rightX, flipY: flipY, angle: rightFlipper ? 30 : -20, isLeft: false) {
            vy = -abs(vy) - 1
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
                vx -= 2 * dot * nx; vy -= 2 * dot * ny
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
                phase = .gameOver
            } else {
                launchBall(seed: seedInt &+ ballsLeft)
            }
            return
        }

        ballPos = CGPoint(x: px, y: py)
        ballVel = CGPoint(x: vx, y: vy)
    }

    func checkFlipperV3(px: CGFloat, py: CGFloat, flipX: CGFloat, flipY: CGFloat, angle: Double, isLeft: Bool) -> Bool {
        let rad = angle * .pi / 180
        let dx = px - flipX; let dy = py - flipY
        let lx = dx * cos(-rad) - dy * sin(-rad)
        let ly = dx * sin(-rad) + dy * cos(-rad)
        let rangeMin: CGFloat = isLeft ? 0 : -flipperWidth
        let rangeMax: CGFloat = isLeft ? flipperWidth : 0
        return lx >= rangeMin && lx <= rangeMax && ly >= -ballRadius - flipperHeight && ly <= ballRadius
    }
}

#Preview { PinballViewV3() }

import SwiftUI

struct AHkLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum AHkV3Phase { case start, playing, over }

struct AHkV3State {
    var puckPos: CGPoint = .zero
    var puckVel: CGPoint = CGPoint(x: 3, y: 4)
    var playerX: CGFloat = 0
    var aiX: CGFloat = 0
    var playerScore: Int = 0
    var aiScore: Int = 0
    var phase: AHkV3Phase = .start
    var winner: String = ""
    // LCG-seeded game params
    var initVelX: CGFloat = 3
    var initVelY: CGFloat = 4
    var aiReactionZone: CGFloat = 0.5  // fraction of field where AI engages
    var obstacleX: CGFloat = 0         // optional mid-field bump zone x
}

struct AirHockeyViewV3: View {
    @State private var gs = AHkV3State()
    @State private var timer: Timer? = nil
    @State private var seedInt: Int = 1

    let fieldW: CGFloat = 320
    let fieldH: CGFloat = 460
    let puckR: CGFloat = 15
    let paddleR: CGFloat = 26
    let goalW: CGFloat = 100

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch gs.phase {
            case .start: startView
            case .playing: gameView
            case .over: overView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 28) {
            Text("AIR HOCKEY").font(.largeTitle).bold().foregroundColor(Color(.label))
            Text("Drag the bottom paddle.\nFirst to 5 goals wins!").multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
            Button("START") { startGame() }
                .font(.title2).bold().padding(.horizontal, 44).padding(.vertical, 14)
                .background(Color(.systemGray5))
                .foregroundColor(Color(.label))
                .clipShape(Capsule())
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(40)
    }

    var overView: some View {
        VStack(spacing: 24) {
            Text(gs.winner == "Player" ? "YOU WIN!" : "AI WINS").font(.largeTitle).bold()
                .foregroundColor(gs.winner == "Player" ? Color.teal : Color.red)
            Text("\(gs.playerScore) – \(gs.aiScore)").font(.title).foregroundColor(Color(.label))
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
            Button("PLAY AGAIN") { startGame() }
                .font(.title2).bold().padding(.horizontal, 44).padding(.vertical, 14)
                .background(Color(.systemGray5))
                .foregroundColor(Color(.label))
                .clipShape(Capsule())
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding(40)
    }

    var gameView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("AI").font(.caption).foregroundColor(Color(.secondaryLabel))
                    Text("\(gs.aiScore)").font(.title).bold().foregroundColor(.red)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .neumorphicCard(radius: 12)

                Spacer()

                Text("SEED: #\(seedInt)").font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))

                Spacer()

                VStack(spacing: 2) {
                    Text("YOU").font(.caption).foregroundColor(Color(.secondaryLabel))
                    Text("\(gs.playerScore)").font(.title).bold().foregroundColor(.teal)
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                .neumorphicCard(radius: 12)
            }
            .padding(.horizontal, 20)

            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6))
                    .frame(width: fieldW, height: fieldH)
                    .shadow(color: Color.black.opacity(0.18), radius: 8, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(0.75), radius: 8, x: -4, y: -4)

                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray4), lineWidth: 1).frame(width: fieldW, height: fieldH)

                Rectangle().fill(Color(.systemGray4)).frame(width: fieldW * 0.8, height: 1)
                Circle().stroke(Color(.systemGray4), lineWidth: 1).frame(width: 80, height: 80)

                // Obstacle bump
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray4))
                    .frame(width: 8, height: 30)
                    .position(x: fieldW/2 + gs.obstacleX, y: fieldH/2)

                // Goal markers
                Rectangle().fill(Color.red.opacity(0.25)).frame(width: goalW, height: 6)
                    .position(x: fieldW/2, y: 3)
                Rectangle().fill(Color.teal.opacity(0.25)).frame(width: goalW, height: 6)
                    .position(x: fieldW/2, y: fieldH - 3)

                // AI paddle
                Circle().fill(
                    RadialGradient(colors: [Color(.systemGray5), Color(.systemGray3)],
                                   center: .topLeading, startRadius: 0, endRadius: paddleR*2))
                    .frame(width: paddleR*2, height: paddleR*2)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                    .overlay(Circle().fill(Color.red.opacity(0.35)).frame(width: paddleR, height: paddleR))
                    .position(x: fieldW/2 + gs.aiX, y: paddleR + 10)

                // Player paddle
                Circle().fill(
                    RadialGradient(colors: [Color(.systemGray5), Color(.systemGray3)],
                                   center: .topLeading, startRadius: 0, endRadius: paddleR*2))
                    .frame(width: paddleR*2, height: paddleR*2)
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.8), radius: 4, x: -2, y: -2)
                    .overlay(Circle().fill(Color.teal.opacity(0.45)).frame(width: paddleR, height: paddleR))
                    .position(x: fieldW/2 + gs.playerX, y: fieldH - paddleR - 10)

                // Puck
                Circle().fill(
                    RadialGradient(colors: [Color(.systemGray2), Color(.systemGray)],
                                   center: .topLeading, startRadius: 0, endRadius: puckR*2))
                    .frame(width: puckR*2, height: puckR*2)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 2, x: -1, y: -1)
                    .position(x: fieldW/2 + gs.puckPos.x, y: fieldH/2 + gs.puckPos.y)
            }
            .frame(width: fieldW, height: fieldH)
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let newX = v.location.x - fieldW/2
                    gs.playerX = min(max(newX, -fieldW/2 + paddleR), fieldW/2 - paddleR)
                })
        }
    }

    func startGame() {
        var lcg = AHkLCG(seed: seedInt)
        let velX = CGFloat(lcg.nextDouble() * 6 - 3)
        let velY: CGFloat = lcg.nextInt(2) == 0 ? 4 : -4
        let obstX = CGFloat(lcg.nextDouble() * 80 - 40)
        let aiZone = CGFloat(0.4 + lcg.nextDouble() * 0.3)

        var newState = AHkV3State()
        newState.phase = .playing
        newState.initVelX = velX
        newState.initVelY = velY
        newState.obstacleX = obstX
        newState.aiReactionZone = aiZone
        newState.puckVel = CGPoint(x: velX, y: velY)
        gs = newState

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in update() }
    }

    func update() {
        guard gs.phase == .playing else { return }
        var p = gs.puckPos
        var v = gs.puckVel

        // AI: more aggressive when puck in its zone
        let puckInAIZone = p.y < -fieldH * gs.aiReactionZone / 2
        let aiSpeed: CGFloat = puckInAIZone ? 0.10 : 0.04
        gs.aiX += (p.x - gs.aiX) * aiSpeed

        p.x += v.x
        p.y += v.y

        let halfW = fieldW/2 - puckR
        let halfH = fieldH/2 - puckR

        if p.x > halfW { p.x = halfW; v.x = -abs(v.x) }
        if p.x < -halfW { p.x = -halfW; v.x = abs(v.x) }

        // Obstacle bump (mid-field)
        let odx = p.x - gs.obstacleX
        let ody = p.y - 0.0
        if abs(odx) < puckR + 4 && abs(ody) < puckR + 15 {
            v.x = odx > 0 ? abs(v.x) : -abs(v.x)
        }

        // Player paddle
        let pdx = p.x - gs.playerX
        let pdy = p.y - (fieldH/2 - paddleR - 10)
        if sqrt(pdx*pdx + pdy*pdy) < puckR + paddleR {
            v.y = -abs(v.y) - 0.5
            v.x += pdx * 0.15
            p.y = (fieldH/2 - paddleR - 10) - puckR - paddleR - 1
        }

        // AI paddle
        let aiAbsY = -(fieldH/2 - paddleR - 10)
        let adx = p.x - gs.aiX
        let ady = p.y - aiAbsY
        if sqrt(adx*adx + ady*ady) < puckR + paddleR {
            v.y = abs(v.y) + 0.5
            v.x += adx * 0.15
            p.y = aiAbsY + puckR + paddleR + 1
        }

        let mag = sqrt(v.x*v.x + v.y*v.y)
        if mag > 8 { v.x *= 8/mag; v.y *= 8/mag }
        if mag < 2 { v.x *= 2/mag; v.y *= 2/mag }

        if p.y < -halfH {
            if abs(p.x) < goalW/2 {
                gs.playerScore += 1; resetPuck(dir: 1); checkWin(); return
            } else { p.y = -halfH; v.y = abs(v.y) }
        }
        if p.y > halfH {
            if abs(p.x) < goalW/2 {
                gs.aiScore += 1; resetPuck(dir: -1); checkWin(); return
            } else { p.y = halfH; v.y = -abs(v.y) }
        }

        gs.puckPos = p; gs.puckVel = v
    }

    func resetPuck(dir: CGFloat) {
        var lcg = AHkLCG(seed: seedInt &+ gs.playerScore &+ gs.aiScore)
        let rx = CGFloat(lcg.nextDouble() * 4 - 2)
        gs.puckPos = .zero
        gs.puckVel = CGPoint(x: rx, y: dir * 4)
    }

    func checkWin() {
        if gs.playerScore >= 5 {
            gs.winner = "Player"; gs.phase = .over; timer?.invalidate()
            seedInt += 1
        } else if gs.aiScore >= 5 {
            gs.winner = "AI"; gs.phase = .over; timer?.invalidate()
            seedInt += 1
        }
    }
}

#Preview { AirHockeyViewV3() }

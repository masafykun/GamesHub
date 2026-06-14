import SwiftUI

enum AHkV2Phase { case start, playing, over }

struct AHkV2State {
    var puckPos: CGPoint = .zero
    var puckVel: CGPoint = CGPoint(x: 3, y: 4)
    var playerX: CGFloat = 0
    var aiX: CGFloat = 0
    var playerScore: Int = 0
    var aiScore: Int = 0
    var phase: AHkV2Phase = .start
    var winner: String = ""
}

struct AirHockeyViewV2: View {
    @State private var gs = AHkV2State()
    @State private var timer: Timer? = nil
    @State private var recentResults: [Bool] = []

    let fieldW: CGFloat = 320
    let fieldH: CGFloat = 460
    let puckR: CGFloat = 15
    let paddleR: CGFloat = 26
    let goalW: CGFloat = 100

    var difficultyMultiplier: CGFloat {
        guard recentResults.count >= 5 else { return 1.0 }
        let last5 = recentResults.suffix(5)
        let wins = last5.filter { $0 }.count
        return wins > 4 ? 1.2 : 1.0
    }

    var baseSpeed: CGFloat { 5.0 * difficultyMultiplier }
    var aiLag: CGFloat { max(0.04, 0.07 / difficultyMultiplier) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25),
                                    Color(red: 0.15, green: 0.05, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch gs.phase {
            case .start: startView
            case .playing: gameView
            case .over: overView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 28) {
            Text("AIR HOCKEY").font(.largeTitle).bold().foregroundColor(.white)
            Text("Drag the bottom paddle.\nFirst to 5 goals wins!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            if difficultyMultiplier > 1.0 {
                Text("HARD MODE ACTIVE").font(.caption).foregroundColor(.yellow)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .overlay(Capsule().stroke(.yellow.opacity(0.4), lineWidth: 1))
            }
            Button("START") { startGame() }
                .font(.title2).bold().padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial).foregroundColor(.white).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    var overView: some View {
        VStack(spacing: 24) {
            Text(gs.winner == "Player" ? "YOU WIN!" : "AI WINS").font(.largeTitle).bold()
                .foregroundColor(gs.winner == "Player" ? Color.cyan : Color.red)
            Text("\(gs.playerScore) – \(gs.aiScore)").foregroundColor(.white).font(.title)
            if difficultyMultiplier > 1.0 {
                Text("(Hard Mode)").font(.caption).foregroundColor(.yellow)
            }
            Button("PLAY AGAIN") { startGame() }
                .font(.title2).bold().padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial).foregroundColor(.white).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }
        .padding(32)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(40)
    }

    var gameView: some View {
        VStack(spacing: 10) {
            HStack(spacing: 32) {
                scoreChip(label: "AI", score: gs.aiScore, color: .red)
                if difficultyMultiplier > 1.0 {
                    Text("HARD").font(.caption2).bold().foregroundColor(.yellow)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial).clipShape(Capsule())
                        .overlay(Capsule().stroke(.yellow.opacity(0.4), lineWidth: 1))
                }
                scoreChip(label: "YOU", score: gs.playerScore, color: .cyan)
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04)).frame(width: fieldW, height: fieldH)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.white.opacity(0.2), lineWidth: 1.5).frame(width: fieldW, height: fieldH)
                Rectangle().fill(.white.opacity(0.1)).frame(width: fieldW, height: 1)
                Circle().stroke(.white.opacity(0.1), lineWidth: 1).frame(width: 80, height: 80)
                // Goal markers
                Rectangle().fill(Color.red.opacity(0.3)).frame(width: goalW, height: 6)
                    .position(x: fieldW/2, y: 3)
                Rectangle().fill(Color.cyan.opacity(0.3)).frame(width: goalW, height: 6)
                    .position(x: fieldW/2, y: fieldH - 3)
                // AI paddle
                Circle().fill(
                    RadialGradient(colors: [Color.red.opacity(0.9), Color.red.opacity(0.5)],
                                   center: .topLeading, startRadius: 0, endRadius: paddleR*2))
                    .frame(width: paddleR*2, height: paddleR*2)
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    .position(x: fieldW/2 + gs.aiX, y: paddleR + 10)
                // Player paddle
                Circle().fill(
                    RadialGradient(colors: [Color.cyan.opacity(0.95), Color.cyan.opacity(0.55)],
                                   center: .topLeading, startRadius: 0, endRadius: paddleR*2))
                    .frame(width: paddleR*2, height: paddleR*2)
                    .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
                    .position(x: fieldW/2 + gs.playerX, y: fieldH - paddleR - 10)
                // Puck
                Circle().fill(RadialGradient(colors: [.white, Color(white: 0.7)],
                                             center: .topLeading, startRadius: 0, endRadius: puckR*2))
                    .frame(width: puckR*2, height: puckR*2)
                    .shadow(color: .white.opacity(0.6), radius: 4)
                    .position(x: fieldW/2 + gs.puckPos.x, y: fieldH/2 + gs.puckPos.y)
            }
            .frame(width: fieldW, height: fieldH)
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.2), lineWidth: 1))
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    let newX = v.location.x - fieldW/2
                    gs.playerX = min(max(newX, -fieldW/2 + paddleR), fieldW/2 - paddleR)
                })
        }
    }

    func scoreChip(label: String, score: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundColor(color.opacity(0.8))
            Text("\(score)").font(.title).bold().foregroundColor(color)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
    }

    func startGame() {
        gs = AHkV2State()
        gs.phase = .playing
        gs.puckVel = CGPoint(x: CGFloat.random(in: -3...3), y: 4)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in update() }
    }

    func update() {
        guard gs.phase == .playing else { return }
        var p = gs.puckPos
        var v = gs.puckVel
        let spd = baseSpeed

        gs.aiX += (p.x - gs.aiX) * aiLag

        p.x += v.x * spd / 5
        p.y += v.y * spd / 5

        let halfW = fieldW/2 - puckR
        let halfH = fieldH/2 - puckR

        if p.x > halfW { p.x = halfW; v.x = -abs(v.x) }
        if p.x < -halfW { p.x = -halfW; v.x = abs(v.x) }

        // Player paddle
        let pdx = p.x - gs.playerX
        let pdy = p.y - (fieldH/2 - paddleR - 10)
        if sqrt(pdx*pdx + pdy*pdy) < puckR + paddleR {
            v.y = -(abs(v.y) + 0.5) * difficultyMultiplier
            v.x += pdx * 0.15
            p.y = (fieldH/2 - paddleR - 10) - puckR - paddleR - 1
        }

        // AI paddle
        let aiAbsY = -(fieldH/2 - paddleR - 10)
        let adx = p.x - gs.aiX
        let ady = p.y - aiAbsY
        if sqrt(adx*adx + ady*ady) < puckR + paddleR {
            v.y = (abs(v.y) + 0.5) * difficultyMultiplier
            v.x += adx * 0.15
            p.y = aiAbsY + puckR + paddleR + 1
        }

        let mag = sqrt(v.x*v.x + v.y*v.y)
        let maxSpd: CGFloat = 8 * difficultyMultiplier
        if mag > maxSpd { v.x *= maxSpd/mag; v.y *= maxSpd/mag }
        if mag < 2 { v.x *= 2/mag; v.y *= 2/mag }

        if p.y < -halfH {
            if abs(p.x) < goalW/2 {
                gs.playerScore += 1
                recentResults.append(true)
                resetPuck(dir: 1); checkWin(); return
            } else { p.y = -halfH; v.y = abs(v.y) }
        }
        if p.y > halfH {
            if abs(p.x) < goalW/2 {
                gs.aiScore += 1
                recentResults.append(false)
                resetPuck(dir: -1); checkWin(); return
            } else { p.y = halfH; v.y = -abs(v.y) }
        }

        gs.puckPos = p; gs.puckVel = v
    }

    func resetPuck(dir: CGFloat) {
        gs.puckPos = .zero
        gs.puckVel = CGPoint(x: CGFloat.random(in: -3...3), y: dir * 4)
    }

    func checkWin() {
        if gs.playerScore >= 5 { gs.winner = "Player"; gs.phase = .over; timer?.invalidate() }
        else if gs.aiScore >= 5 { gs.winner = "AI"; gs.phase = .over; timer?.invalidate() }
    }
}

#Preview { AirHockeyViewV2() }

import SwiftUI

enum AHkPhase { case start, playing, over }

struct AHkGameState {
    var puckPos: CGPoint = .zero
    var puckVel: CGPoint = CGPoint(x: 3, y: 4)
    var playerX: CGFloat = 0
    var aiX: CGFloat = 0
    var playerScore: Int = 0
    var aiScore: Int = 0
    var phase: AHkPhase = .start
    var winner: String = ""
}

struct AirHockeyView: View {
    @State private var gs = AHkGameState()
    @State private var timer: Timer? = nil

    let fieldW: CGFloat = 320
    let fieldH: CGFloat = 480
    let puckR: CGFloat = 16
    let paddleR: CGFloat = 28
    let goalW: CGFloat = 100
    let speed: CGFloat = 5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch gs.phase {
            case .start: startView
            case .playing: gameView
            case .over: overView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 24) {
            Text("AIR HOCKEY").font(.largeTitle).bold().foregroundColor(.white)
            Text("Drag the bottom paddle.\nFirst to 5 goals wins!").multilineTextAlignment(.center).foregroundColor(.gray)
            Button("START") { startGame() }
                .font(.title2).bold().padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.cyan).foregroundColor(.black).clipShape(Capsule())
        }
    }

    var overView: some View {
        VStack(spacing: 24) {
            Text(gs.winner == "Player" ? "YOU WIN!" : "AI WINS").font(.largeTitle).bold()
                .foregroundColor(gs.winner == "Player" ? .cyan : .red)
            Text("Score: \(gs.playerScore) – \(gs.aiScore)").foregroundColor(.white).font(.title2)
            Button("PLAY AGAIN") { startGame() }
                .font(.title2).bold().padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.cyan).foregroundColor(.black).clipShape(Capsule())
        }
    }

    var gameView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 40) {
                Text("AI: \(gs.aiScore)").foregroundColor(.red).font(.title2).bold()
                Text("YOU: \(gs.playerScore)").foregroundColor(.cyan).font(.title2).bold()
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(white: 0.12)).frame(width: fieldW, height: fieldH)
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 2).frame(width: fieldW, height: fieldH)
                // Center line
                Rectangle().fill(Color.white.opacity(0.15)).frame(width: fieldW, height: 1)
                // Center circle
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 1).frame(width: 80, height: 80)
                // Goal areas
                goalMarkers
                // AI paddle (top)
                Circle().fill(Color.red.opacity(0.85)).frame(width: paddleR*2, height: paddleR*2)
                    .position(x: fieldW/2 + gs.aiX, y: paddleR + 10)
                // Player paddle (bottom)
                Circle().fill(Color.cyan.opacity(0.9)).frame(width: paddleR*2, height: paddleR*2)
                    .position(x: fieldW/2 + gs.playerX, y: fieldH - paddleR - 10)
                // Puck
                Circle().fill(Color.white).frame(width: puckR*2, height: puckR*2)
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

    var goalMarkers: some View {
        ZStack {
            // Top goal
            Rectangle().fill(Color.red.opacity(0.25)).frame(width: goalW, height: 8)
                .position(x: fieldW/2, y: 4)
            // Bottom goal
            Rectangle().fill(Color.cyan.opacity(0.25)).frame(width: goalW, height: 8)
                .position(x: fieldW/2, y: fieldH - 4)
        }
    }

    func startGame() {
        gs = AHkGameState()
        gs.phase = .playing
        gs.puckPos = CGPoint(x: 0, y: 0)
        gs.puckVel = CGPoint(x: CGFloat.random(in: -3...3), y: 4)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in update() }
    }

    func update() {
        guard gs.phase == .playing else { return }
        var p = gs.puckPos
        var v = gs.puckVel

        // AI follows puck x with lag
        let aiDiff = p.x - gs.aiX
        gs.aiX += aiDiff * 0.07

        // Move puck
        p.x += v.x * speed / 5
        p.y += v.y * speed / 5

        let halfW = fieldW / 2 - puckR
        let halfH = fieldH / 2 - puckR

        // Wall bounce X
        if p.x > halfW { p.x = halfW; v.x = -abs(v.x) }
        if p.x < -halfW { p.x = -halfW; v.x = abs(v.x) }

        // Player paddle collision (bottom)
        let playerAbsX = gs.playerX
        let playerAbsY = fieldH/2 - paddleR - 10
        let dpx = p.x - playerAbsX
        let dpy = p.y - playerAbsY
        if sqrt(dpx*dpx + dpy*dpy) < puckR + paddleR {
            v.y = -abs(v.y) - 1
            v.x += dpx * 0.15
            p.y = playerAbsY - puckR - paddleR - 1
        }

        // AI paddle collision (top)
        let aiAbsY = -(fieldH/2 - paddleR - 10)
        let dax = p.x - gs.aiX
        let day = p.y - aiAbsY
        if sqrt(dax*dax + day*day) < puckR + paddleR {
            v.y = abs(v.y) + 1
            v.x += dax * 0.15
            p.y = aiAbsY + puckR + paddleR + 1
        }

        // Cap velocity
        let mag = sqrt(v.x*v.x + v.y*v.y)
        if mag > 8 { v.x *= 8/mag; v.y *= 8/mag }
        if mag < 3 { v.x *= 3/mag; v.y *= 3/mag }

        // Goal check top (AI goal)
        if p.y < -halfH {
            if abs(p.x) < goalW/2 {
                gs.playerScore += 1
                resetPuck(dir: 1)
                checkWin()
                return
            } else {
                p.y = -halfH; v.y = abs(v.y)
            }
        }
        // Goal check bottom (player goal)
        if p.y > halfH {
            if abs(p.x) < goalW/2 {
                gs.aiScore += 1
                resetPuck(dir: -1)
                checkWin()
                return
            } else {
                p.y = halfH; v.y = -abs(v.y)
            }
        }

        gs.puckPos = p
        gs.puckVel = v
    }

    func resetPuck(dir: CGFloat) {
        gs.puckPos = CGPoint(x: 0, y: 0)
        gs.puckVel = CGPoint(x: CGFloat.random(in: -3...3), y: dir * 4)
    }

    func checkWin() {
        if gs.playerScore >= 5 { gs.winner = "Player"; gs.phase = .over; timer?.invalidate() }
        else if gs.aiScore >= 5 { gs.winner = "AI"; gs.phase = .over; timer?.invalidate() }
    }
}

#Preview { AirHockeyView() }

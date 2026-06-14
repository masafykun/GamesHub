import SwiftUI

enum DtGamePhase { case start, playing, gameOver }

struct DtDart: Identifiable {
    let id = UUID()
    let position: CGPoint
    let score: Int
}

struct DartsView: View {
    @State private var phase: DtGamePhase = .start
    @State private var crosshairPos: CGPoint = CGPoint(x: 150, y: 150)
    @State private var dartsThrown: [DtDart] = []
    @State private var currentRound: Int = 1
    @State private var dartsInRound: Int = 0
    @State private var totalScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var wobbleAngle: Double = 0
    @State private var wobbleRadius: Double = 30

    let boardSize: CGFloat = 300
    let totalRounds = 5
    let dartsPerRound = 3

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("DARTS").font(.system(size: 48, weight: .black)).foregroundColor(.white)
            Text("Tap the board to throw!\n3 darts × 5 rounds").multilineTextAlignment(.center).foregroundColor(.gray)
            Button("PLAY") {
                startGame()
            }
            .font(.headline).foregroundColor(.black)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.green).cornerRadius(12)
        }
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Round \(currentRound)/\(totalRounds)").foregroundColor(.white).font(.headline)
                Spacer()
                Text("Score: \(totalScore)").foregroundColor(.yellow).font(.headline)
                Spacer()
                Text("Darts: \(dartsPerRound - dartsInRound)").foregroundColor(.green).font(.headline)
            }.padding(.horizontal)

            ZStack {
                boardView
                    .frame(width: boardSize, height: boardSize)
                    .onTapGesture { throwDart() }

                ForEach(dartsThrown) { dart in
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(.yellow).font(.system(size: 10))
                        .position(dart.position)
                }

                Circle().fill(Color.red).frame(width: 12, height: 12)
                    .position(crosshairPos)
                    .shadow(color: .red, radius: 4)
            }
            .frame(width: boardSize, height: boardSize)
            .background(Color(.systemGray6).opacity(0.1))
            .cornerRadius(16)

            if let last = dartsThrown.last {
                Text("+\(last.score) pts").font(.title2.bold()).foregroundColor(.orange)
                    .transition(.scale.combined(with: .opacity))
            }
        }.padding()
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Final Score").foregroundColor(.gray)
            Text("\(totalScore)").font(.system(size: 72, weight: .black)).foregroundColor(.yellow)
            Text(scoreRating).font(.title3).foregroundColor(.green)
            Button("PLAY AGAIN") { resetGame() }
                .font(.headline).foregroundColor(.black)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.green).cornerRadius(12)
        }
    }

    var boardView: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            let rings: [(CGFloat, Color)] = [
                (1.0, Color(hue: 0.33, saturation: 0.6, brightness: 0.4)),
                (0.75, Color(hue: 0.0, saturation: 0.6, brightness: 0.5)),
                (0.5, Color(hue: 0.33, saturation: 0.8, brightness: 0.6)),
                (0.25, Color(hue: 0.0, saturation: 0.8, brightness: 0.7)),
                (0.1, Color.green),
                (0.05, Color.red),
            ]
            for (frac, color) in rings.reversed() {
                let r = maxR * frac
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.3)), lineWidth: 1)
            }
        }
    }

    var scoreRating: String {
        switch totalScore {
        case 500...: return "Legendary!"
        case 350...: return "Excellent!"
        case 200...: return "Good Job!"
        case 100...: return "Keep Practicing"
        default: return "Better Luck Next Time"
        }
    }

    func scoreForPosition(_ pos: CGPoint) -> Int {
        let cx = boardSize / 2
        let cy = boardSize / 2
        let dx = pos.x - cx
        let dy = pos.y - cy
        let dist = sqrt(dx * dx + dy * dy)
        let maxR = boardSize / 2
        let frac = dist / maxR
        if frac <= 0.05 { return 50 }
        if frac <= 0.1 { return 25 }
        if frac <= 0.25 { return 20 }
        if frac <= 0.5 { return 10 }
        if frac <= 0.75 { return 5 }
        return 0
    }

    func startGame() {
        totalScore = 0
        currentRound = 1
        dartsInRound = 0
        dartsThrown = []
        crosshairPos = CGPoint(x: boardSize / 2, y: boardSize / 2)
        phase = .playing
        startWobble()
    }

    func resetGame() { phase = .start; stopWobble() }

    func throwDart() {
        guard phase == .playing else { return }
        let score = scoreForPosition(crosshairPos)
        let dart = DtDart(position: crosshairPos, score: score)
        withAnimation { dartsThrown.append(dart) }
        totalScore += score
        dartsInRound += 1
        if dartsInRound >= dartsPerRound {
            dartsInRound = 0
            if currentRound >= totalRounds {
                stopWobble()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .gameOver }
            } else {
                currentRound += 1
                dartsThrown = []
            }
        }
    }

    func startWobble() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            wobbleAngle += 0.12
            let cx = boardSize / 2
            let cy = boardSize / 2
            let x = cx + CGFloat(cos(wobbleAngle) * wobbleRadius + cos(wobbleAngle * 2.3) * wobbleRadius * 0.4)
            let y = cy + CGFloat(sin(wobbleAngle * 1.5) * wobbleRadius + sin(wobbleAngle * 0.7) * wobbleRadius * 0.5)
            crosshairPos = CGPoint(x: x, y: y)
        }
    }

    func stopWobble() { timer?.invalidate(); timer = nil }
}

#Preview { DartsView() }

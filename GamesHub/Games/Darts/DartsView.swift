import SwiftUI

enum DartsPhase { case start, playing, gameOver }

struct DartsDart: Identifiable {
    let id = UUID()
    let position: CGPoint
    let score: Int
}

struct DartsView: View {
    @State private var phase: DartsPhase = .start
    @AppStorage("dartsBestScore") private var bestScore: Int = 0
    @State private var crosshairPos: CGPoint = CGPoint(x: 150, y: 150)
    @State private var dartsThrown: [DartsDart] = []
    @State private var currentRound: Int = 1
    @State private var dartsInRound: Int = 0
    @State private var totalScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var wobbleAngle: Double = 0
    @State private var wobbleSpeed: Double = 0.12
    @State private var wobbleRadius: Double = 32
    @State private var recentResults: [Bool] = []
    @State private var lastScoreText: String = ""
    @State private var showScore: Bool = false

    let boardSize: CGFloat = 300
    let totalRounds = 5
    let dartsPerRound = 3

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hue: 0.6, saturation: 0.8, brightness: 0.3),
                                    Color(hue: 0.85, saturation: 0.7, brightness: 0.2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("DARTS").font(.system(size: 52, weight: .black)).foregroundColor(.white)
                .shadow(color: .purple, radius: 10)
            Text("3 darts per round • 5 rounds\nTap the board to throw!").multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
            Button("START GAME") { startGame() }
                .font(.headline.bold()).foregroundColor(.white)
                .padding(.horizontal, 44).padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("ROUND").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(currentRound)/\(totalRounds)").font(.title2.bold()).foregroundColor(.white)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

                Spacer()

                VStack {
                    Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(totalScore)").font(.title2.bold()).foregroundColor(.yellow)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))

                Spacer()

                VStack(alignment: .trailing) {
                    Text("DARTS").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(dartsPerRound - dartsInRound)").font(.title2.bold()).foregroundColor(.green)
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }.padding(.horizontal)

            ZStack {
                boardView.frame(width: boardSize, height: boardSize)
                    .onTapGesture { throwDart() }

                ForEach(dartsThrown) { dart in
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(.yellow).font(.system(size: 10))
                        .position(dart.position)
                }

                Circle().fill(Color.cyan).frame(width: 14, height: 14)
                    .shadow(color: .cyan, radius: 6)
                    .position(crosshairPos)
            }
            .frame(width: boardSize, height: boardSize)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            if showScore {
                Text(lastScoreText).font(.title.bold()).foregroundColor(.orange)
                    .transition(.scale.combined(with: .opacity))
            }

            difficultyIndicator
        }.padding()
    }

    var difficultyIndicator: some View {
        let level = difficultyLevel
        return HStack(spacing: 6) {
            Text("DIFFICULTY:").font(.caption).foregroundColor(.white.opacity(0.6))
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(i < level ? Color.orange : Color.white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var difficultyLevel: Int {
        let baseSpeed = 0.12
        let ratio = wobbleSpeed / baseSpeed
        if ratio < 1.1 { return 1 }
        if ratio < 1.3 { return 2 }
        if ratio < 1.5 { return 3 }
        if ratio < 1.8 { return 4 }
        return 5
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("GAME OVER").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            VStack(spacing: 8) {
                Text("FINAL SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                Text("\(totalScore)").font(.system(size: 80, weight: .black)).foregroundColor(.yellow)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            Text(scoreRating).font(.title3.bold()).foregroundColor(.green)
            Text("Best: \(bestScore)").font(.caption).foregroundColor(.white.opacity(0.6))

            Button("PLAY AGAIN") { resetGame() }
                .font(.headline.bold()).foregroundColor(.white)
                .padding(.horizontal, 44).padding(.vertical, 16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
        }.padding()
    }

    var boardView: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            let rings: [(CGFloat, Color)] = [
                (1.0, Color(hue: 0.33, saturation: 0.5, brightness: 0.35)),
                (0.75, Color(hue: 0.0, saturation: 0.5, brightness: 0.45)),
                (0.5, Color(hue: 0.33, saturation: 0.7, brightness: 0.55)),
                (0.25, Color(hue: 0.0, saturation: 0.7, brightness: 0.65)),
                (0.1, Color(hue: 0.35, saturation: 0.9, brightness: 0.7)),
                (0.05, Color(hue: 0.0, saturation: 0.9, brightness: 0.85)),
            ]
            for (frac, color) in rings.reversed() {
                let r = maxR * frac
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.4)), lineWidth: 1.5)
            }
        }
    }

    var scoreRating: String {
        switch totalScore {
        case 500...: return "Legendary!"
        case 350...: return "Excellent!"
        case 200...: return "Good Job!"
        default: return "Keep Practicing!"
        }
    }

    func scoreForPosition(_ pos: CGPoint) -> Int {
        let cx = boardSize / 2
        let cy = boardSize / 2
        let dist = sqrt(pow(pos.x - cx, 2) + pow(pos.y - cy, 2))
        let frac = dist / (boardSize / 2)
        if frac <= 0.05 { return 50 }
        if frac <= 0.1 { return 25 }
        if frac <= 0.25 { return 20 }
        if frac <= 0.5 { return 10 }
        if frac <= 0.75 { return 5 }
        return 0
    }

    func startGame() {
        totalScore = 0; currentRound = 1; dartsInRound = 0
        dartsThrown = []; recentResults = []
        wobbleSpeed = 0.12; wobbleRadius = 32
        crosshairPos = CGPoint(x: boardSize / 2, y: boardSize / 2)
        phase = .playing
        startWobble()
    }

    func resetGame() { phase = .start; stopWobble() }

    func throwDart() {
        guard phase == .playing else { return }
        let score = scoreForPosition(crosshairPos)
        let dart = DartsDart(position: crosshairPos, score: score)
        withAnimation { dartsThrown.append(dart) }
        totalScore += score
        dartsInRound += 1
        lastScoreText = score > 0 ? "+\(score) pts" : "Miss!"
        withAnimation { showScore = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showScore = false } }

        if dartsInRound >= dartsPerRound {
            let roundGood = score >= 15
            recentResults.append(roundGood)
            if recentResults.count > 5 { recentResults.removeFirst() }
            if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
                wobbleSpeed *= 1.2
                wobbleRadius *= 1.1
            }
            dartsInRound = 0
            if currentRound >= totalRounds {
                stopWobble()
                bestScore = max(bestScore, totalScore)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { phase = .gameOver }
            } else {
                currentRound += 1
                dartsThrown = []
            }
        }
    }

    func startWobble() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            wobbleAngle += wobbleSpeed
            let cx = boardSize / 2; let cy = boardSize / 2
            let x = cx + CGFloat(cos(wobbleAngle) * wobbleRadius + cos(wobbleAngle * 2.3) * wobbleRadius * 0.4)
            let y = cy + CGFloat(sin(wobbleAngle * 1.5) * wobbleRadius + sin(wobbleAngle * 0.7) * wobbleRadius * 0.5)
            crosshairPos = CGPoint(x: x, y: y)
        }
    }

    func stopWobble() { timer?.invalidate(); timer = nil }
}

#Preview { DartsView() }

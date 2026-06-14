import SwiftUI

enum DtV3Phase { case start, playing, gameOver }

struct DtV3Dart: Identifiable {
    let id = UUID()
    let position: CGPoint
    let score: Int
}

struct DtLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct DartsViewV3: View {
    @State private var phase: DtV3Phase = .start
    @State private var crosshairPos: CGPoint = CGPoint(x: 150, y: 150)
    @State private var dartsThrown: [DtV3Dart] = []
    @State private var currentRound: Int = 1
    @State private var dartsInRound: Int = 0
    @State private var totalScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var wobbleAngle: Double = 0
    @State private var wobbleRadiusX: Double = 30
    @State private var wobbleRadiusY: Double = 25
    @State private var wobbleSpeedX: Double = 0.11
    @State private var wobbleSpeedY: Double = 0.13
    @State private var seedInt: Int = 1
    @State private var lastScoreText: String = ""
    @State private var showScore: Bool = false

    let boardSize: CGFloat = 300
    let totalRounds = 5
    let dartsPerRound = 3

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 32) {
            Text("DARTS").font(.system(size: 52, weight: .black)).foregroundColor(.primary)
            Text("3 darts per round\n5 rounds total\nTap the board to throw!").multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("START GAME") { startGame() }
                .font(.headline.bold()).foregroundColor(.primary)
                .padding(.horizontal, 44).padding(.vertical, 16)
                .neumorphicCard(radius: 16)
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUND").font(.caption).foregroundColor(.secondary)
                    Text("\(currentRound)/\(totalRounds)").font(.title2.bold()).foregroundColor(.primary)
                }
                .padding()
                .neumorphicCard(radius: 14)

                Spacer()

                VStack(spacing: 2) {
                    Text("SCORE").font(.caption).foregroundColor(.secondary)
                    Text("\(totalScore)").font(.title2.bold()).foregroundColor(.accentColor)
                }
                .padding()
                .neumorphicCard(radius: 14)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("DARTS").font(.caption).foregroundColor(.secondary)
                    Text("\(dartsPerRound - dartsInRound)").font(.title2.bold()).foregroundColor(.green)
                }
                .padding()
                .neumorphicCard(radius: 14)
            }.padding(.horizontal)

            ZStack {
                boardView.frame(width: boardSize, height: boardSize)
                    .onTapGesture { throwDart() }

                ForEach(dartsThrown) { dart in
                    Image(systemName: "arrowtriangle.down.fill")
                        .foregroundColor(.orange).font(.system(size: 10))
                        .position(dart.position)
                }

                Circle().fill(Color.red).frame(width: 14, height: 14)
                    .shadow(color: .red.opacity(0.5), radius: 4)
                    .position(crosshairPos)
            }
            .frame(width: boardSize, height: boardSize)
            .neumorphicCard(radius: 20)

            if showScore {
                Text(lastScoreText).font(.title.bold()).foregroundColor(.orange)
                    .transition(.scale.combined(with: .opacity))
            }

            Text("SEED: #\(seedInt)").font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)
        }.padding()
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("GAME OVER").font(.system(size: 40, weight: .black)).foregroundColor(.primary)
            VStack(spacing: 8) {
                Text("FINAL SCORE").font(.caption).foregroundColor(.secondary)
                Text("\(totalScore)").font(.system(size: 80, weight: .black)).foregroundColor(.accentColor)
                Text(scoreRating).font(.title3.bold()).foregroundColor(.green)
            }
            .padding(32)
            .neumorphicCard(radius: 20)

            Text("SEED: #\(seedInt)").font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.gray)

            Button("PLAY AGAIN") { resetGame() }
                .font(.headline.bold()).foregroundColor(.primary)
                .padding(.horizontal, 44).padding(.vertical, 16)
                .neumorphicCard(radius: 16)
        }.padding()
    }

    var boardView: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxR = min(size.width, size.height) / 2
            let rings: [(CGFloat, Color)] = [
                (1.0, Color(.systemGray4)),
                (0.75, Color(.systemGray3)),
                (0.5, Color(.systemGray4)),
                (0.25, Color(.systemGray3)),
                (0.1, Color(hue: 0.33, saturation: 0.6, brightness: 0.6)),
                (0.05, Color(hue: 0.0, saturation: 0.7, brightness: 0.7)),
            ]
            for (frac, color) in rings.reversed() {
                let r = maxR * frac
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)), lineWidth: 1)
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
        let cx = boardSize / 2; let cy = boardSize / 2
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
        totalScore = 0; currentRound = 1; dartsInRound = 0; dartsThrown = []
        var lcg = DtLCG(seed: seedInt)
        wobbleRadiusX = 20.0 + lcg.nextDouble() * 25.0
        wobbleRadiusY = 18.0 + lcg.nextDouble() * 22.0
        wobbleSpeedX = 0.08 + lcg.nextDouble() * 0.08
        wobbleSpeedY = 0.09 + lcg.nextDouble() * 0.08
        let startOffsetX = lcg.nextDouble() * .pi * 2
        let startOffsetY = lcg.nextDouble() * .pi * 2
        wobbleAngle = 0
        let cx = boardSize / 2; let cy = boardSize / 2
        crosshairPos = CGPoint(
            x: cx + CGFloat(cos(startOffsetX) * wobbleRadiusX),
            y: cy + CGFloat(sin(startOffsetY) * wobbleRadiusY)
        )
        phase = .playing
        startWobble()
    }

    func resetGame() {
        stopWobble()
        seedInt += 1
        phase = .start
    }

    func throwDart() {
        guard phase == .playing else { return }
        let score = scoreForPosition(crosshairPos)
        let dart = DtV3Dart(position: crosshairPos, score: score)
        withAnimation { dartsThrown.append(dart) }
        totalScore += score
        dartsInRound += 1
        lastScoreText = score > 0 ? "+\(score) pts" : "Miss!"
        withAnimation { showScore = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { withAnimation { showScore = false } }

        if dartsInRound >= dartsPerRound {
            dartsInRound = 0
            if currentRound >= totalRounds {
                stopWobble()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { phase = .gameOver }
            } else {
                currentRound += 1
                dartsThrown = []
                var lcg = DtLCG(seed: seedInt &+ currentRound)
                wobbleRadiusX = 20.0 + lcg.nextDouble() * 28.0
                wobbleRadiusY = 18.0 + lcg.nextDouble() * 25.0
                wobbleSpeedX = 0.09 + lcg.nextDouble() * 0.10
                wobbleSpeedY = 0.10 + lcg.nextDouble() * 0.09
            }
        }
    }

    func startWobble() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            wobbleAngle += wobbleSpeedX
            let cx = boardSize / 2; let cy = boardSize / 2
            let x = cx + CGFloat(cos(wobbleAngle) * wobbleRadiusX + cos(wobbleAngle * 2.1) * wobbleRadiusX * 0.35)
            let y = cy + CGFloat(sin(wobbleAngle * (wobbleSpeedY / wobbleSpeedX)) * wobbleRadiusY
                                 + sin(wobbleAngle * 0.8) * wobbleRadiusY * 0.4)
            crosshairPos = CGPoint(x: x, y: y)
        }
    }

    func stopWobble() { timer?.invalidate(); timer = nil }
}

#Preview { DartsViewV3() }

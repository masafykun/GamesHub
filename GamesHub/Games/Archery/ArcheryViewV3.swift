import SwiftUI

struct AcLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum AcV3Phase {
    case start, playing, gameOver
}

struct AcV3Ring {
    let radius: CGFloat
    let color: Color
    let points: Int
}

struct AcV3ArrowMark {
    let offset: CGFloat
    let ringHit: Int
}

struct ArcheryViewV3: View {
    @State private var phase: AcV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var lcg: AcLCG = AcLCG(seed: 1)
    @State private var aimAngle: Double = 0.0
    @State private var aimDirection: Double = 1.0
    @State private var arrowsLeft: Int = 10
    @State private var totalScore: Int = 0
    @State private var arrowMarks: [AcV3ArrowMark] = []
    @State private var timer: Timer? = nil
    @State private var lastHitPoints: Int? = nil
    @State private var windOffset: CGFloat = 0.0
    @State private var targetXShift: CGFloat = 0.0

    let rings: [AcV3Ring] = [
        AcV3Ring(radius: 100, color: .white,  points: 2),
        AcV3Ring(radius: 80,  color: .black,  points: 4),
        AcV3Ring(radius: 60,  color: .blue,   points: 6),
        AcV3Ring(radius: 40,  color: .red,    points: 8),
        AcV3Ring(radius: 20,  color: .yellow, points: 10),
    ]

    var oscillationSpeed: Double {
        let arrowsFired = 10 - arrowsLeft
        let level = arrowsFired / 3
        return 1.5 + Double(level) * 0.6
    }

    var aimOffset: CGFloat {
        CGFloat(sin(aimAngle) * 90) + windOffset
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start:
                startView
            case .playing:
                gameView
            case .gameOver:
                gameOverView
            }
        }
    }

    var startView: some View {
        VStack(spacing: 28) {
            Text("ARCHERY").font(.largeTitle).bold().foregroundStyle(.primary)
            Text("10 arrows. Tap FIRE at\nthe right moment.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(28)
        .neumorphicCard(radius: 16)
        .padding()
    }

    var gameView: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Arrows: \(arrowsLeft)").font(.headline)
                    Text("Score: \(totalScore)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.gray)
                    if windOffset != 0 {
                        Text("Wind: \(windOffset > 0 ? "+" : "")\(Int(windOffset))")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding()
            .neumorphicCard(radius: 12)
            .padding(.horizontal)

            ZStack {
                ForEach(0..<rings.count, id: \.self) { i in
                    Circle()
                        .fill(rings[i].color)
                        .frame(width: rings[i].radius * 2, height: rings[i].radius * 2)
                }
                ForEach(0..<arrowMarks.count, id: \.self) { i in
                    Image(systemName: "arrow.down")
                        .foregroundStyle(arrowMarks[i].ringHit >= 3 ? Color.purple : Color.gray)
                        .font(.system(size: 14, weight: .bold))
                        .offset(x: arrowMarks[i].offset + targetXShift, y: 0)
                }
                Capsule()
                    .fill(Color.green.opacity(0.9))
                    .frame(width: 4, height: 28)
                    .shadow(color: .green.opacity(0.4), radius: 4)
                    .offset(x: aimOffset, y: -112)
            }
            .frame(width: 220, height: 260)
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            if let pts = lastHitPoints {
                Text(pts > 0 ? "+\(pts)" : "Miss!")
                    .font(.title2).bold()
                    .foregroundStyle(pts >= 8 ? .yellow : pts > 0 ? .green : .red)
                    .transition(.scale.combined(with: .opacity))
            }

            Button("FIRE") { fireArrow() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .disabled(arrowsLeft == 0)
        }
        .padding(.vertical)
    }

    var gameOverView: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.largeTitle).bold()
            VStack(spacing: 8) {
                Text("Final Score").foregroundStyle(.secondary)
                Text("\(totalScore)")
                    .font(.system(size: 72, weight: .black))
                    .foregroundStyle(totalScore >= 70 ? .green : totalScore >= 40 ? .orange : .red)
                Text("out of 100").foregroundStyle(.secondary)
            }
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.gray)
            Button("Play Again") {
                seedInt += 1
                phase = .start
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .neumorphicCard(radius: 16)
        .padding()
    }

    func startGame() {
        arrowsLeft = 10
        totalScore = 0
        arrowMarks = []
        lastHitPoints = nil
        aimAngle = 0
        lcg = AcLCG(seed: seedInt)
        let rawWind = lcg.nextDouble() * 2.0 - 1.0
        windOffset = CGFloat(rawWind * 20.0)
        let rawShift = lcg.nextDouble() * 2.0 - 1.0
        targetXShift = CGFloat(rawShift * 10.0)
        phase = .playing
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { _ in
            aimAngle += 0.033 * oscillationSpeed
        }
    }

    func fireArrow() {
        guard arrowsLeft > 0 else { return }
        let offset = aimOffset
        let dist = abs(offset - targetXShift)
        var pts = 0
        var ringIdx = -1
        for (i, ring) in rings.enumerated().reversed() {
            if dist <= ring.radius {
                pts = ring.points
                ringIdx = rings.count - 1 - i
                break
            }
        }
        arrowsLeft -= 1
        totalScore += pts
        arrowMarks.append(AcV3ArrowMark(offset: offset - targetXShift, ringHit: ringIdx))

        let noiseDouble = lcg.nextDouble()
        let noiseShift = (noiseDouble * 2.0 - 1.0) * 8.0
        windOffset += CGFloat(noiseShift)
        windOffset = max(-30, min(30, windOffset))

        withAnimation { lastHitPoints = pts }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation { lastHitPoints = nil }
        }

        if arrowsLeft == 0 {
            timer?.invalidate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                phase = .gameOver
            }
        }
    }
}

#Preview { ArcheryViewV3() }

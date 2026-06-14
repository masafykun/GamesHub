import SwiftUI

struct SpTLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum SpTv3Phase { case start, playing, over }

struct SpTv3SegmentDef {
    let color: Color
    let label: String
    let points: Int
}

struct SpTv3GameConfig {
    let segmentOrder: [Int]
    let initialSpeed: Double
    let speedVariance: Double
}

struct SpinTargetViewV3: View {
    @State private var phase: SpTv3Phase = .start
    @State private var angle: Double = 0
    @State private var speed: Double = 180
    @State private var throwsLeft: Int = 5
    @State private var totalScore: Int = 0
    @State private var lastPoints: Int? = nil
    @State private var timer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var gameConfig: SpTv3GameConfig = SpTv3GameConfig(segmentOrder: [0,1,2,3,4,5], initialSpeed: 180, speedVariance: 1.0)
    @AppStorage("SpTv3BestScore") private var bestScore: Int = 0

    let baseDefs: [SpTv3SegmentDef] = [
        SpTv3SegmentDef(color: .red, label: "10", points: 10),
        SpTv3SegmentDef(color: .orange, label: "8", points: 8),
        SpTv3SegmentDef(color: .yellow, label: "6", points: 6),
        SpTv3SegmentDef(color: .green, label: "5", points: 5),
        SpTv3SegmentDef(color: .blue, label: "3", points: 3),
        SpTv3SegmentDef(color: .purple, label: "1", points: 1),
    ]

    var orderedSegments: [SpTv3SegmentDef] {
        gameConfig.segmentOrder.map { baseDefs[$0] }
    }

    var currentSegmentIndex: Int {
        let normalized = (360.0 - angle.truncatingRemainder(dividingBy: 360.0)).truncatingRemainder(dividingBy: 360.0)
        return Int(normalized / 60.0) % 6
    }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start:
                SpTv3StartScreen(seedInt: seedInt, onStart: startGame)
            case .playing:
                SpTv3PlayScreen(
                    segments: orderedSegments,
                    angle: angle,
                    throwsLeft: throwsLeft,
                    totalScore: totalScore,
                    lastPoints: lastPoints,
                    seedInt: seedInt,
                    onThrow: throwAction
                )
            case .over:
                SpTv3ResultScreen(totalScore: totalScore, bestScore: bestScore, seedInt: seedInt, onRestart: resetGame)
            }
        }
    }

    func generateConfig(seed: Int) -> SpTv3GameConfig {
        var rng = SpTLCG(seed: seed)
        var order = [0, 1, 2, 3, 4, 5]
        for i in stride(from: order.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            order.swapAt(i, j)
        }
        let speedBase = 140.0 + rng.nextDouble() * 100.0
        let variance = 0.5 + rng.nextDouble() * 1.0
        return SpTv3GameConfig(segmentOrder: order, initialSpeed: speedBase, speedVariance: variance)
    }

    func startGame() {
        gameConfig = generateConfig(seed: seedInt)
        totalScore = 0
        throwsLeft = 5
        lastPoints = nil
        speed = gameConfig.initialSpeed
        phase = .playing
        startSpinning()
    }

    func resetGame() {
        seedInt += 1
        phase = .start
    }

    func startSpinning() {
        timer?.invalidate()
        let base = gameConfig.initialSpeed
        let variance = gameConfig.speedVariance
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            angle += speed * 0.016
            speed = base + base * variance * abs(sin(angle * .pi / 180 * 0.3))
        }
    }

    func throwAction() {
        timer?.invalidate()
        let pts = orderedSegments[currentSegmentIndex].points
        totalScore += pts
        lastPoints = pts
        throwsLeft -= 1
        if throwsLeft == 0 {
            if totalScore > bestScore { bestScore = totalScore }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { phase = .over }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { startSpinning() }
        }
    }
}

struct SpTv3StartScreen: View {
    let seedInt: Int
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("SPIN TARGET").font(.system(size: 34, weight: .black)).foregroundColor(.primary)
            Text("Tap THROW to stop the spinning wheel.\nEach seed shuffles the wheel layout!")
                .multilineTextAlignment(.center).foregroundColor(.secondary).font(.subheadline)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button(action: onStart) {
                Text("START").font(.headline).foregroundColor(.white)
                    .frame(width: 160, height: 50).background(Color.blue).cornerRadius(12)
            }
        }
        .padding(28)
        .neumorphicCard(radius: 20)
        .padding()
    }
}

struct SpTv3PlayScreen: View {
    let segments: [SpTv3SegmentDef]
    let angle: Double
    let throwsLeft: Int
    let totalScore: Int
    let lastPoints: Int?
    let seedInt: Int
    let onThrow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption2.bold()).foregroundColor(.secondary)
                    Text("\(totalScore)").font(.title.bold()).foregroundColor(.primary)
                }
                .padding(12).neumorphicCard(radius: 12)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("THROWS").font(.caption2.bold()).foregroundColor(.secondary)
                    Text("\(throwsLeft)").font(.title.bold()).foregroundColor(.blue)
                }
                .padding(12).neumorphicCard(radius: 12)
            }
            .padding(.horizontal, 20)

            ZStack {
                SpTv3WheelView(segments: segments, angle: angle).frame(width: 280, height: 280)
                SpTv3ArrowView().frame(width: 30, height: 80).offset(y: -160)
            }

            Group {
                if let pts = lastPoints {
                    Text("+\(pts) pts").font(.title.bold()).foregroundColor(.blue)
                } else {
                    Text(" ").font(.title.bold())
                }
            }

            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced)).foregroundColor(.gray)

            Button(action: onThrow) {
                Text("THROW").font(.system(size: 22, weight: .black)).foregroundColor(.white)
                    .frame(width: 180, height: 60).background(Color.blue).cornerRadius(16)
            }
        }
        .padding()
    }
}

struct SpTv3WheelView: View {
    let segments: [SpTv3SegmentDef]
    let angle: Double
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                SpTv3Wedge(index: i, total: 6).fill(segments[i].color)
                SpTv3WedgeLabel(index: i, total: 6, label: segments[i].label)
            }
            Circle().stroke(Color(.systemGray4), lineWidth: 3)
            Circle().fill(Color(.systemGray6)).frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.9), radius: 4, x: -2, y: -2)
        }
        .rotationEffect(.degrees(angle))
    }
}

struct SpTv3Wedge: Shape {
    let index: Int
    let total: Int
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let slice = 360.0 / Double(total)
        let start = Angle.degrees(Double(index) * slice - 90)
        let end = Angle.degrees(Double(index + 1) * slice - 90)
        var p = Path()
        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct SpTv3WedgeLabel: View {
    let index: Int
    let total: Int
    let label: String
    var body: some View {
        let deg = Double(index) * 360.0 / Double(total) + 360.0 / Double(total) / 2 - 90
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 * 0.65
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .shadow(radius: 2)
                .position(x: cx + r * cos(deg * .pi / 180), y: cy + r * sin(deg * .pi / 180))
        }
    }
}

struct SpTv3ArrowView: View {
    var body: some View {
        SpTv3Triangle()
            .fill(Color(.systemGray6))
            .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
            .shadow(color: .white.opacity(0.9), radius: 3, x: -2, y: -2)
    }
}

struct SpTv3Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct SpTv3ResultScreen: View {
    let totalScore: Int
    let bestScore: Int
    let seedInt: Int
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 30, weight: .black)).foregroundColor(.primary)
            VStack(spacing: 4) {
                Text("FINAL SCORE").font(.caption.bold()).foregroundColor(.secondary)
                Text("\(totalScore)").font(.system(size: 52, weight: .black)).foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity).padding(20).neumorphicCard(radius: 16)
            Text("Best: \(bestScore)").font(.headline).foregroundColor(.secondary)
            if totalScore >= bestScore && totalScore > 0 {
                Text("New Best!").font(.headline.bold()).foregroundColor(.green)
            }
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button(action: onRestart) {
                Text("NEXT SEED").font(.headline.bold()).foregroundColor(.white)
                    .frame(width: 180, height: 52).background(Color.blue).cornerRadius(14)
            }
        }
        .padding(28)
        .neumorphicCard(radius: 20)
        .padding()
    }
}

#Preview { SpinTargetViewV3() }

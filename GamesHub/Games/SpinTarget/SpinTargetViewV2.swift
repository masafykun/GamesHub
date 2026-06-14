import SwiftUI

enum SpTv2Phase { case start, playing, over }

struct SpTv2Segment {
    let color: Color
    let label: String
    let points: Int
}

struct SpinTargetViewV2: View {
    @State private var phase: SpTv2Phase = .start
    @State private var angle: Double = 0
    @State private var speed: Double = 180
    @State private var throwsLeft: Int = 5
    @State private var totalScore: Int = 0
    @State private var lastPoints: Int? = nil
    @State private var timer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @AppStorage("SpTv2BestScore") private var bestScore: Int = 0

    let segments: [SpTv2Segment] = [
        SpTv2Segment(color: .red, label: "10", points: 10),
        SpTv2Segment(color: .orange, label: "8", points: 8),
        SpTv2Segment(color: .yellow, label: "6", points: 6),
        SpTv2Segment(color: .green, label: "5", points: 5),
        SpTv2Segment(color: .blue, label: "3", points: 3),
        SpTv2Segment(color: .purple, label: "1", points: 1),
    ]

    let baseSpeed: Double = 180
    @State private var difficultyMultiplier: Double = 1.0

    var currentSegmentIndex: Int {
        let normalized = (360.0 - angle.truncatingRemainder(dividingBy: 360.0)).truncatingRemainder(dividingBy: 360.0)
        return Int(normalized / 60.0) % 6
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.18), Color(red: 0.15, green: 0.05, blue: 0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: SpTv2StartScreen { startGame() }
            case .playing:
                SpTv2PlayScreen(
                    segments: segments,
                    angle: angle,
                    throwsLeft: throwsLeft,
                    totalScore: totalScore,
                    lastPoints: lastPoints,
                    difficultyMultiplier: difficultyMultiplier,
                    onThrow: throwAction
                )
            case .over:
                SpTv2ResultScreen(totalScore: totalScore, bestScore: bestScore, onRestart: { phase = .start })
            }
        }
    }

    func startGame() {
        totalScore = 0
        throwsLeft = 5
        lastPoints = nil
        recentResults = []
        difficultyMultiplier = 1.0
        phase = .playing
        startSpinning()
    }

    func startSpinning() {
        timer?.invalidate()
        let effectiveBase = baseSpeed * difficultyMultiplier
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            angle += speed * 0.016
            speed = effectiveBase + effectiveBase * 0.7 * abs(sin(angle * .pi / 180 * 0.3))
        }
    }

    func throwAction() {
        timer?.invalidate()
        let seg = segments[currentSegmentIndex]
        let pts = seg.points
        totalScore += pts
        lastPoints = pts

        let isHigh = pts >= 8
        recentResults.append(isHigh)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
        }

        throwsLeft -= 1
        if throwsLeft == 0 {
            if totalScore > bestScore { bestScore = totalScore }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { phase = .over }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { startSpinning() }
        }
    }
}

struct SpTv2StartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Text("SPIN TARGET").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Tap THROW to stop the wheel!\nScore from 1-10 per throw. 5 throws total.")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7)).font(.subheadline)
            Text("Adaptive Difficulty: Land high scores\nand the wheel speeds up!")
                .multilineTextAlignment(.center).foregroundColor(.yellow.opacity(0.8)).font(.caption)
            Button(action: onStart) {
                Text("START GAME").font(.headline.bold()).foregroundColor(.white)
                    .frame(width: 180, height: 52)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }
}

struct SpTv2PlayScreen: View {
    let segments: [SpTv2Segment]
    let angle: Double
    let throwsLeft: Int
    let totalScore: Int
    let lastPoints: Int?
    let difficultyMultiplier: Double
    let onThrow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(totalScore)").font(.title.bold()).foregroundColor(.white)
                }
                .padding(12)
                .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("THROWS").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(throwsLeft)").font(.title.bold()).foregroundColor(.yellow)
                }
                .padding(12)
                .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 20)

            if difficultyMultiplier > 1.0 {
                Text("SPEED x\(String(format: "%.1f", difficultyMultiplier))")
                    .font(.caption.bold()).foregroundColor(.orange)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .overlay(Capsule().stroke(.orange.opacity(0.5), lineWidth: 1))
            }

            ZStack {
                SpTv2WheelView(segments: segments, angle: angle).frame(width: 280, height: 280)
                SpTv2ArrowView().frame(width: 30, height: 80).offset(y: -160)
            }

            Group {
                if let pts = lastPoints {
                    Text("+\(pts) pts").font(.title.bold()).foregroundColor(.yellow)
                } else {
                    Text(" ").font(.title.bold())
                }
            }

            Button(action: onThrow) {
                Text("THROW").font(.system(size: 22, weight: .black)).foregroundColor(.white)
                    .frame(width: 180, height: 60)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.4), lineWidth: 1.5))
            }
        }
        .padding()
    }
}

struct SpTv2WheelView: View {
    let segments: [SpTv2Segment]
    let angle: Double
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                SpTv2Wedge(index: i, total: 6).fill(segments[i].color.opacity(0.9))
                SpTv2WedgeLabel(index: i, total: 6, label: segments[i].label)
            }
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 3)
            Circle().fill(.ultraThinMaterial).frame(width: 32, height: 32)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
        }
        .rotationEffect(.degrees(angle))
    }
}

struct SpTv2Wedge: Shape {
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

struct SpTv2WedgeLabel: View {
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
                .position(x: cx + r * cos(deg * .pi / 180), y: cy + r * sin(deg * .pi / 180))
        }
    }
}

struct SpTv2ArrowView: View {
    var body: some View {
        SpTv2Triangle().fill(Color.white.opacity(0.9))
            .overlay(SpTv2Triangle().stroke(Color.black.opacity(0.3), lineWidth: 1))
    }
}

struct SpTv2Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct SpTv2ResultScreen: View {
    let totalScore: Int
    let bestScore: Int
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 32, weight: .black)).foregroundColor(.white)
            VStack(spacing: 8) {
                Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                Text("\(totalScore)").font(.system(size: 56, weight: .black)).foregroundColor(.yellow)
            }
            .frame(maxWidth: .infinity).padding(20)
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            Text("Best: \(bestScore)").font(.headline).foregroundColor(.white.opacity(0.7))
            if totalScore >= bestScore && totalScore > 0 {
                Text("New Best!").font(.headline.bold()).foregroundColor(.green)
            }
            Button(action: onRestart) {
                Text("PLAY AGAIN").font(.headline.bold()).foregroundColor(.white)
                    .frame(width: 180, height: 52)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }
}

#Preview { SpinTargetViewV2() }

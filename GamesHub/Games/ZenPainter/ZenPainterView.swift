import SwiftUI

// MARK: - Patterns

/// The shipped versions were a free-draw canvas with a countdown — no goal and
/// no result. This keeps the calm brush feel but turns it into a game: trace
/// the ink pattern as completely and as accurately as you can.
struct ZenPainterPattern {
    let name: String
    /// Points in unit space (0...1); the tracing target.
    let points: [CGPoint]

    static func circle(turns: Double = 1) -> [CGPoint] {
        stride(from: 0.0, through: 1.0, by: 0.004).map { t in
            let a = t * .pi * 2 * turns - .pi / 2
            return CGPoint(x: 0.5 + cos(a) * 0.34, y: 0.5 + sin(a) * 0.34)
        }
    }

    static func spiral() -> [CGPoint] {
        stride(from: 0.0, through: 1.0, by: 0.003).map { t in
            let a = t * .pi * 5
            let r = 0.08 + t * 0.3
            return CGPoint(x: 0.5 + cos(a) * r, y: 0.5 + sin(a) * r)
        }
    }

    static func wave() -> [CGPoint] {
        stride(from: 0.0, through: 1.0, by: 0.003).map { t in
            CGPoint(x: 0.1 + t * 0.8, y: 0.5 + sin(t * .pi * 4) * 0.22)
        }
    }

    static func star() -> [CGPoint] {
        var pts: [CGPoint] = []
        let order = [0, 2, 4, 1, 3, 0]
        for i in 0..<(order.count - 1) {
            let a1 = Double(order[i]) * 2 * .pi / 5 - .pi / 2
            let a2 = Double(order[i + 1]) * 2 * .pi / 5 - .pi / 2
            let p1 = CGPoint(x: 0.5 + cos(a1) * 0.34, y: 0.5 + sin(a1) * 0.34)
            let p2 = CGPoint(x: 0.5 + cos(a2) * 0.34, y: 0.5 + sin(a2) * 0.34)
            for s in stride(from: 0.0, through: 1.0, by: 0.01) {
                pts.append(CGPoint(x: p1.x + (p2.x - p1.x) * s, y: p1.y + (p2.y - p1.y) * s))
            }
        }
        return pts
    }

    static func infinity() -> [CGPoint] {
        stride(from: 0.0, through: 1.0, by: 0.003).map { t in
            let a = t * .pi * 2
            return CGPoint(x: 0.5 + sin(a) * 0.33, y: 0.5 + sin(a * 2) * 0.18)
        }
    }

    static let all: [ZenPainterPattern] = [
        ZenPainterPattern(name: "Enso", points: circle()),
        ZenPainterPattern(name: "Wave", points: wave()),
        ZenPainterPattern(name: "Spiral", points: spiral()),
        ZenPainterPattern(name: "Star", points: star()),
        ZenPainterPattern(name: "Infinity", points: infinity()),
    ]
}

struct ZenPainterStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var hue: Double
}

enum ZenPainterPhase { case start, drawing, complete }

// MARK: - View

struct ZenPainterView: View {
    @State private var phase: ZenPainterPhase = .start
    @State private var round: Int = 1
    @State private var patternIndex: Int = 0
    @State private var covered: Set<Int> = []
    @State private var strayPoints: Int = 0
    @State private var totalPoints: Int = 0
    @State private var strokes: [ZenPainterStroke] = []
    @State private var currentStroke: ZenPainterStroke? = nil
    @State private var hue: Double = 0
    @State private var timeRemaining: Int = 30
    @State private var timer: Timer? = nil
    @State private var roundScores: [Int] = []
    @State private var canvasSize: CGSize = .zero

    @AppStorage("zenPainterBestScore") private var bestScore: Int = 0

    private let totalRounds = 3

    private var pattern: ZenPainterPattern { ZenPainterPattern.all[patternIndex] }
    private var coverage: Double {
        pattern.points.isEmpty ? 0 : Double(covered.count) / Double(pattern.points.count)
    }
    private var accuracy: Double {
        totalPoints == 0 ? 1 : max(0, 1 - Double(strayPoints) / Double(totalPoints))
    }
    private var roundScore: Int { Int(coverage * 100 * (0.5 + accuracy * 0.5)) }
    private var runScore: Int { roundScores.reduce(0, +) }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.75, saturation: 0.6, brightness: 0.22),
                         Color(hue: 0.55, saturation: 0.5, brightness: 0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch phase {
            case .start:    startScreen
            case .drawing:  drawingScreen
            case .complete: completeScreen
            }
        }
        .onDisappear { timer?.invalidate() }
        .preferredColorScheme(.dark)
    }

    // MARK: Screens

    private var startScreen: some View {
        VStack(spacing: 26) {
            Text("Zen Painter")
                .font(.system(size: 42, weight: .thin, design: .serif))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                Text("Trace the ink pattern with one calm stroke.")
                    .foregroundColor(.white.opacity(0.85))
                Text("Coverage fills the score, straying from the line costs accuracy.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                if bestScore > 0 {
                    Text("Best: \(bestScore)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

            Button(action: startRun) {
                Text("Begin")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 46)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(30)
    }

    private var drawingScreen: some View {
        VStack(spacing: 12) {
            HStack {
                label("ROUND", "\(round)/\(totalRounds)")
                Spacer()
                label("PATTERN", pattern.name)
                Spacer()
                label("TRACED", "\(Int(coverage * 100))%")
                Spacer()
                label("TIME", "\(timeRemaining)s")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 12)

            GeometryReader { geo in
                ZStack {
                    Canvas { ctx, size in
                        // Target pattern: faint where untraced, glowing where traced.
                        for (i, p) in pattern.points.enumerated() {
                            let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
                            let rect = CGRect(x: pt.x - 3, y: pt.y - 3, width: 6, height: 6)
                            let done = covered.contains(i)
                            ctx.fill(
                                Path(ellipseIn: rect),
                                with: .color(done
                                             ? Color(hue: 0.5, saturation: 0.5, brightness: 1).opacity(0.9)
                                             : Color.white.opacity(0.13))
                            )
                        }

                        for stroke in strokes + (currentStroke.map { [$0] } ?? []) {
                            guard stroke.points.count > 1 else { continue }
                            var path = Path()
                            path.move(to: stroke.points[0])
                            for p in stroke.points.dropFirst() { path.addLine(to: p) }
                            ctx.stroke(
                                path,
                                with: .color(Color(hue: stroke.hue, saturation: 0.55, brightness: 1).opacity(0.75)),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                    .background(Color.white.opacity(0.03))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in handleDraw(value.location, in: geo.size) }
                            .onEnded { _ in
                                if let stroke = currentStroke { strokes.append(stroke) }
                                currentStroke = nil
                            }
                    )
                }
                .onAppear { canvasSize = geo.size }
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
    }

    private var completeScreen: some View {
        VStack(spacing: 22) {
            Text(round > totalRounds ? "Session Complete" : "Round \(round)")
                .font(.system(size: 30, weight: .thin, design: .serif))
                .foregroundColor(.white)

            VStack(spacing: 10) {
                statRow("Traced", "\(Int(coverage * 100))%")
                statRow("Accuracy", "\(Int(accuracy * 100))%")
                statRow("Round score", "\(roundScore)")
                statRow("Run total", "\(runScore)")
                statRow("Best", "\(bestScore)")
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

            Button(action: advance) {
                Text(round > totalRounds ? "Paint Again" : "Next Pattern")
                    .font(.title3.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(30)
    }

    private func label(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value).foregroundColor(.white).bold()
        }
        .font(.subheadline)
        .frame(width: 220)
    }

    // MARK: Flow

    private func startRun() {
        round = 1
        roundScores = []
        beginRound(patternIndex: Int.random(in: 0..<ZenPainterPattern.all.count))
    }

    private func beginRound(patternIndex index: Int) {
        patternIndex = index
        covered = []
        strayPoints = 0
        totalPoints = 0
        strokes = []
        currentStroke = nil
        hue = Double.random(in: 0...1)
        timeRemaining = 30
        phase = .drawing

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                finishRound()
            }
        }
    }

    private func finishRound() {
        timer?.invalidate()
        timer = nil
        roundScores.append(roundScore)
        bestScore = max(bestScore, runScore)
        phase = .complete
    }

    private func advance() {
        if round >= totalRounds {
            startRun()
        } else {
            round += 1
            let next = (patternIndex + Int.random(in: 1..<ZenPainterPattern.all.count)) % ZenPainterPattern.all.count
            beginRound(patternIndex: next)
        }
    }

    // MARK: Drawing

    private func handleDraw(_ location: CGPoint, in size: CGSize) {
        guard phase == .drawing else { return }

        if currentStroke == nil {
            currentStroke = ZenPainterStroke(points: [location], hue: hue)
        } else {
            currentStroke?.points.append(location)
        }
        hue = (hue + 0.004).truncatingRemainder(dividingBy: 1)

        totalPoints += 1

        // Mark every target sample within the brush radius as traced.
        let tolerance: CGFloat = 26
        var hit = false
        for (i, p) in pattern.points.enumerated() {
            let pt = CGPoint(x: p.x * size.width, y: p.y * size.height)
            if abs(pt.x - location.x) < tolerance && abs(pt.y - location.y) < tolerance {
                let dx = pt.x - location.x
                let dy = pt.y - location.y
                if dx * dx + dy * dy < tolerance * tolerance {
                    covered.insert(i)
                    hit = true
                }
            }
        }
        if !hit { strayPoints += 1 }

        if coverage >= 0.98 { finishRound() }
    }
}

#Preview {
    ZenPainterView()
}

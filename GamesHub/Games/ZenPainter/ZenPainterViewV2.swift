import SwiftUI

struct ZnPtV2Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

enum ZnPtV2Phase {
    case start, drawing, complete
}

struct ZenPainterViewV2: View {
    @State private var phase: ZnPtV2Phase = .start
    @State private var strokes: [ZnPtV2Stroke] = []
    @State private var currentStroke: ZnPtV2Stroke? = nil
    @State private var hue: Double = 0.0
    @State private var timeRemaining: Int = 60
    @State private var sessionDuration: Int = 60
    @State private var timer: Timer? = nil
    @State private var lastPoint: CGPoint? = nil
    @State private var lastTime: Date = Date()
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    var gradientBG: some View {
        LinearGradient(
            colors: [Color(hue: 0.75, saturation: 0.6, brightness: 0.25),
                     Color(hue: 0.55, saturation: 0.5, brightness: 0.15)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ).ignoresSafeArea()
    }

    var body: some View {
        ZStack {
            gradientBG

            switch phase {
            case .start:
                startScreen
            case .drawing:
                drawingScreen
            case .complete:
                completeScreen
            }
        }
    }

    var glassCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("ZenPainter")
                .font(.system(size: 44, weight: .thin, design: .serif))
                .foregroundColor(.white)
            Text("A meditative canvas.\nLet color guide your hand.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.75))
                .padding()
                .background(glassCard)
                .padding(.horizontal, 32)
            if speedMultiplier > 1.05 {
                Text("Challenge Mode x\(String(format: "%.1f", speedMultiplier))")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
            }
            Button(action: startSession) {
                Text("Begin Session")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding()
    }

    var drawingScreen: some View {
        ZStack(alignment: .top) {
            canvasView
            HStack(spacing: 12) {
                Text("\(timeRemaining)s")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
                Spacer()
                Text("\(strokes.count) strokes")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                Spacer()
                Button("Clear") { resetSession() }
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
        }
    }

    var canvasView: some View {
        Canvas { context, size in
            for stroke in strokes {
                guard stroke.points.count > 1 else { continue }
                var path = Path()
                path.move(to: stroke.points[0])
                for pt in stroke.points.dropFirst() {
                    path.addLine(to: pt)
                }
                context.stroke(path, with: .color(stroke.color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
            }
            if let s = currentStroke, s.points.count > 1 {
                var path = Path()
                path.move(to: s.points[0])
                for pt in s.points.dropFirst() {
                    path.addLine(to: pt)
                }
                context.stroke(path, with: .color(s.color), style: StrokeStyle(lineWidth: s.lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color.black.opacity(0.6))
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let now = Date()
                let dt = now.timeIntervalSince(lastTime)
                let speed: Double
                if let lp = lastPoint {
                    let dx = value.location.x - lp.x
                    let dy = value.location.y - lp.y
                    let dist = sqrt(dx*dx + dy*dy)
                    speed = dt > 0 ? dist / dt : 0
                } else {
                    speed = 0
                }
                let lineWidth = max(1.5, min(16.0, 16.0 - speed * 0.04))
                hue = fmod(hue + 0.004 * speedMultiplier, 1.0)
                let color = Color(hue: hue, saturation: 0.9, brightness: 1.0)

                if value.translation == .zero {
                    currentStroke = ZnPtV2Stroke(points: [value.location], color: color, lineWidth: lineWidth)
                } else {
                    currentStroke?.points.append(value.location)
                }
                lastPoint = value.location
                lastTime = now
            }
            .onEnded { _ in
                if let s = currentStroke {
                    strokes.append(s)
                    currentStroke = nil
                }
                lastPoint = nil
            }
        )
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Text("Session Complete")
                .font(.system(size: 34, weight: .thin, design: .serif))
                .foregroundColor(.white)
            VStack(spacing: 8) {
                Text("\(strokes.count)")
                    .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.white)
                Text("strokes created")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(28)
            .background(glassCard)
            if speedMultiplier > 1.05 {
                Text("Challenge Mode Active")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.85))
            }
            Button(action: finishAndAdapt) {
                Text("New Canvas")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding()
    }

    func finishAndAdapt() {
        let isProductive = strokes.count > 15
        recentResults.append(isProductive)
        if recentResults.count > 5 { recentResults.removeFirst() }
        let trueCount = recentResults.filter { $0 }.count
        if recentResults.count == 5 && trueCount > 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
            sessionDuration = max(30, Int(Double(sessionDuration) * 0.85))
        }
        resetSession()
    }

    func startSession() {
        strokes = []
        currentStroke = nil
        hue = 0.0
        timeRemaining = sessionDuration
        phase = .drawing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                timer?.invalidate()
                phase = .complete
            }
        }
    }

    func resetSession() {
        timer?.invalidate()
        strokes = []
        currentStroke = nil
        hue = 0.0
        timeRemaining = sessionDuration
        phase = .start
    }
}

#Preview { ZenPainterViewV2() }

import SwiftUI

struct ZnPtStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

enum ZnPtPhase {
    case start, drawing, complete
}

struct ZenPainterView: View {
    @State private var phase: ZnPtPhase = .start
    @State private var strokes: [ZnPtStroke] = []
    @State private var currentStroke: ZnPtStroke? = nil
    @State private var hue: Double = 0.0
    @State private var timeRemaining: Int = 60
    @State private var timer: Timer? = nil
    @State private var lastPoint: CGPoint? = nil
    @State private var lastTime: Date = Date()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("ZenPainter")
                .font(.system(size: 42, weight: .thin, design: .serif))
                .foregroundColor(.white)
            Text("Draw freely.\nColors flow as you create.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button(action: startSession) {
                Text("Begin")
                    .font(.title2)
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    var drawingScreen: some View {
        ZStack(alignment: .top) {
            canvasView
            HStack {
                Text("\(timeRemaining)s")
                    .font(.system(size: 18, weight: .light, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(strokes.count) strokes")
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Button("Clear") {
                    resetSession()
                }
                .font(.system(size: 16, weight: .light))
                .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
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
        .background(Color.black)
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
                let lineWidth = max(2.0, min(14.0, 14.0 - speed * 0.04))
                hue = fmod(hue + 0.003, 1.0)
                let color = Color(hue: hue, saturation: 0.85, brightness: 0.95)

                if value.translation == .zero {
                    currentStroke = ZnPtStroke(points: [value.location], color: color, lineWidth: lineWidth)
                } else {
                    if currentStroke != nil {
                        currentStroke!.points.append(value.location)
                    }
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
        VStack(spacing: 28) {
            Text("Artwork Complete")
                .font(.system(size: 36, weight: .thin, design: .serif))
                .foregroundColor(.white)
            Text("\(strokes.count)")
                .font(.system(size: 72, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.white)
            Text("strokes")
                .font(.title3)
                .foregroundColor(.gray)
            Button(action: resetSession) {
                Text("New Canvas")
                    .font(.title2)
                    .foregroundColor(.black)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    func startSession() {
        strokes = []
        currentStroke = nil
        hue = 0.0
        timeRemaining = 60
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
        timeRemaining = 60
        phase = .start
    }
}

#Preview { ZenPainterView() }

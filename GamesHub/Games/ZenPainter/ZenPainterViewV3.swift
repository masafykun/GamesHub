import SwiftUI

struct ZnPtLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

struct ZnPtV3Stroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

struct ZnPtGuidePoint: Identifiable {
    let id = UUID()
    var position: CGPoint
    var hue: Double
    var radius: CGFloat
}

enum ZnPtV3Phase {
    case start, drawing, complete
}

struct ZenPainterViewV3: View {
    @State private var phase: ZnPtV3Phase = .start
    @State private var strokes: [ZnPtV3Stroke] = []
    @State private var currentStroke: ZnPtV3Stroke? = nil
    @State private var hue: Double = 0.0
    @State private var timeRemaining: Int = 60
    @State private var timer: Timer? = nil
    @State private var lastPoint: CGPoint? = nil
    @State private var lastTime: Date = Date()
    @State private var seedInt: Int = 1
    @State private var guidePoints: [ZnPtGuidePoint] = []
    @State private var canvasSize: CGSize = .zero

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("ZenPainter")
                    .font(.system(size: 40, weight: .thin, design: .serif))
                    .foregroundColor(Color(.label))
                Text("Meditative canvas drawing")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(28)
            .neumorphicCard(radius: 16)

            VStack(spacing: 6) {
                Text("Drag to paint.")
                    .font(.body)
                    .foregroundColor(Color(.label))
                Text("Hue shifts with each stroke.\nSpeed shapes the line.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal, 32)

            Button(action: startSession) {
                Text("Begin")
                    .font(.title2)
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
            }
            .neumorphicCard(radius: 28)

            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding()
    }

    var drawingScreen: some View {
        ZStack(alignment: .top) {
            GeometryReader { geo in
                ZStack {
                    Color(.systemGray6)
                    canvasView
                        .onAppear { canvasSize = geo.size }
                    ForEach(guidePoints) { gp in
                        Circle()
                            .fill(Color(hue: gp.hue, saturation: 0.5, brightness: 0.7).opacity(0.25))
                            .frame(width: gp.radius * 2, height: gp.radius * 2)
                            .position(gp.position)
                            .allowsHitTesting(false)
                    }
                }
            }

            HStack(spacing: 10) {
                Text("\(timeRemaining)s")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 16)

                Spacer()

                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))

                Spacer()

                Button("Clear") { resetSession() }
                    .font(.system(size: 15))
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .neumorphicCard(radius: 16)
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
                for i in 1..<stroke.points.count {
                    let prev = stroke.points[i - 1]
                    let curr = stroke.points[i]
                    let mid = CGPoint(x: (prev.x + curr.x) / 2, y: (prev.y + curr.y) / 2)
                    path.addQuadCurve(to: mid, control: prev)
                }
                if let last = stroke.points.last, stroke.points.count > 1 {
                    path.addLine(to: last)
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
                hue = fmod(hue + 0.004, 1.0)
                let color = Color(hue: hue, saturation: 0.8, brightness: 0.6)

                if value.translation == .zero {
                    currentStroke = ZnPtV3Stroke(points: [value.location], color: color, lineWidth: lineWidth)
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
        VStack(spacing: 28) {
            Text("Artwork Complete")
                .font(.system(size: 34, weight: .thin, design: .serif))
                .foregroundColor(Color(.label))

            VStack(spacing: 6) {
                Text("\(strokes.count)")
                    .font(.system(size: 68, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(Color(.label))
                Text("strokes")
                    .font(.title3)
                    .foregroundColor(Color(.secondaryLabel))
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                    .padding(.top, 4)
            }
            .padding(28)
            .neumorphicCard(radius: 16)

            Button(action: resetSession) {
                Text("New Canvas")
                    .font(.title2)
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 14)
            }
            .neumorphicCard(radius: 28)
        }
        .padding()
    }

    func generateGuidePoints(size: CGSize) {
        var lcg = ZnPtLCG(seed: seedInt)
        let count = 5 + lcg.nextInt(6)
        guidePoints = (0..<count).map { _ in
            let x = CGFloat(lcg.nextDouble()) * size.width
            let y = CGFloat(lcg.nextDouble()) * size.height
            let h = lcg.nextDouble()
            let r = CGFloat(20 + lcg.nextInt(30))
            return ZnPtGuidePoint(position: CGPoint(x: x, y: y), hue: h, radius: r)
        }
        var tmpLcg = ZnPtLCG(seed: seedInt); hue = tmpLcg.nextDouble()
    }

    func startSession() {
        strokes = []
        currentStroke = nil
        timeRemaining = 60
        phase = .drawing
        let size = canvasSize == .zero ? CGSize(width: 390, height: 700) : canvasSize
        generateGuidePoints(size: size)
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
        timeRemaining = 60
        seedInt += 1
        guidePoints = []
        phase = .start
    }
}

#Preview { ZenPainterViewV3() }

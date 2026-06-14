import SwiftUI

enum SpTGamePhase { case start, playing, over }

struct SpTSegment {
    let color: Color
    let label: String
    let points: Int
}

struct SpinTargetView: View {
    @State private var phase: SpTGamePhase = .start
    @State private var angle: Double = 0
    @State private var speed: Double = 180
    @State private var throwsLeft: Int = 5
    @State private var totalScore: Int = 0
    @State private var lastPoints: Int? = nil
    @State private var timer: Timer? = nil
    @AppStorage("SpTBestScore") private var bestScore: Int = 0

    let segments: [SpTSegment] = [
        SpTSegment(color: .red, label: "10", points: 10),
        SpTSegment(color: .orange, label: "8", points: 8),
        SpTSegment(color: .yellow, label: "6", points: 6),
        SpTSegment(color: .green, label: "5", points: 5),
        SpTSegment(color: .blue, label: "3", points: 3),
        SpTSegment(color: .purple, label: "1", points: 1),
    ]

    var currentSegmentIndex: Int {
        let normalized = (360.0 - angle.truncatingRemainder(dividingBy: 360.0)).truncatingRemainder(dividingBy: 360.0)
        return Int(normalized / 60.0) % 6
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start:
                SpTStartScreen { startGame() }
            case .playing:
                SpTPlayScreen(
                    segments: segments,
                    angle: angle,
                    throwsLeft: throwsLeft,
                    totalScore: totalScore,
                    lastPoints: lastPoints,
                    onThrow: throwAction
                )
            case .over:
                SpTResultScreen(
                    totalScore: totalScore,
                    bestScore: bestScore,
                    onRestart: { phase = .start }
                )
            }
        }
    }

    func startGame() {
        totalScore = 0
        throwsLeft = 5
        lastPoints = nil
        speed = 180
        phase = .playing
        startSpinning()
    }

    func startSpinning() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            angle += speed * 0.016
            speed = 120 + 120 * abs(sin(angle * .pi / 180 * 0.3))
        }
    }

    func throwAction() {
        timer?.invalidate()
        let pts = segments[currentSegmentIndex].points
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

struct SpTStartScreen: View {
    let onStart: () -> Void
    var body: some View {
        VStack(spacing: 28) {
            Text("SPIN TARGET").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Tap THROW to stop the wheel!\nScore depends on where the arrow lands.")
                .multilineTextAlignment(.center).foregroundColor(.gray).font(.subheadline)
            Button(action: onStart) {
                Text("START").font(.headline).foregroundColor(.black)
                    .frame(width: 160, height: 50)
                    .background(Color.white).cornerRadius(12)
            }
        }.padding()
    }
}

struct SpTPlayScreen: View {
    let segments: [SpTSegment]
    let angle: Double
    let throwsLeft: Int
    let totalScore: Int
    let lastPoints: Int?
    let onThrow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Score: \(totalScore)").foregroundColor(.white).font(.title2.bold())
                Spacer()
                Text("Throws: \(throwsLeft)").foregroundColor(.gray).font(.headline)
            }.padding(.horizontal, 24)

            ZStack {
                SpTWheelView(segments: segments, angle: angle)
                    .frame(width: 280, height: 280)
                SpTArrowView()
                    .frame(width: 30, height: 80)
                    .offset(y: -160)
            }

            if let pts = lastPoints {
                Text("+\(pts) pts").font(.title.bold()).foregroundColor(.yellow)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Text(" ").font(.title.bold())
            }

            Button(action: onThrow) {
                Text("THROW").font(.system(size: 22, weight: .black)).foregroundColor(.black)
                    .frame(width: 180, height: 60).background(Color.yellow).cornerRadius(16)
            }
        }.padding()
    }
}

struct SpTWheelView: View {
    let segments: [SpTSegment]
    let angle: Double
    var body: some View {
        ZStack {
            ForEach(0..<6) { i in
                SpTWedge(index: i, total: 6)
                    .fill(segments[i].color)
                SpTWedgeLabel(index: i, total: 6, label: segments[i].label)
            }
            Circle().stroke(Color.white, lineWidth: 3)
            Circle().fill(Color.black).frame(width: 30, height: 30)
        }
        .rotationEffect(.degrees(angle))
    }
}

struct SpTWedge: Shape {
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

struct SpTWedgeLabel: View {
    let index: Int
    let total: Int
    let label: String
    var body: some View {
        let angle = Double(index) * 360.0 / Double(total) + 360.0 / Double(total) / 2 - 90
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2 * 0.65
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let x = cx + r * cos(angle * .pi / 180)
            let y = cy + r * sin(angle * .pi / 180)
            Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                .position(x: x, y: y)
        }
    }
}

struct SpTArrowView: View {
    var body: some View {
        Triangle().fill(Color.white)
            .overlay(Triangle().stroke(Color.black, lineWidth: 1))
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

struct SpTResultScreen: View {
    let totalScore: Int
    let bestScore: Int
    let onRestart: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 32, weight: .black)).foregroundColor(.white)
            Text("Score: \(totalScore)").font(.title.bold()).foregroundColor(.yellow)
            Text("Best: \(bestScore)").font(.headline).foregroundColor(.gray)
            if totalScore >= bestScore {
                Text("New Best!").font(.subheadline.bold()).foregroundColor(.green)
            }
            Button(action: onRestart) {
                Text("PLAY AGAIN").font(.headline).foregroundColor(.black)
                    .frame(width: 160, height: 50).background(Color.white).cornerRadius(12)
            }
        }
    }
}

#Preview { SpinTargetView() }

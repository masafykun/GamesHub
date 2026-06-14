import SwiftUI

enum AcGamePhase {
    case start, playing, gameOver
}

struct AcRingConfig {
    let radius: CGFloat
    let color: Color
    let points: Int
}

struct ArcheryView: View {
    @State private var phase: AcGamePhase = .start
    @State private var aimAngle: Double = 0.0
    @State private var aimDirection: Double = 1.0
    @State private var arrowsLeft: Int = 10
    @State private var totalScore: Int = 0
    @State private var arrowPositions: [(CGFloat, CGFloat)] = []
    @State private var timer: Timer? = nil
    @State private var lastHitPoints: Int? = nil

    let rings: [AcRingConfig] = [
        AcRingConfig(radius: 100, color: .white,  points: 2),
        AcRingConfig(radius: 80,  color: .black,  points: 4),
        AcRingConfig(radius: 60,  color: .blue,   points: 6),
        AcRingConfig(radius: 40,  color: .red,    points: 8),
        AcRingConfig(radius: 20,  color: .yellow, points: 10),
    ]

    var oscillationSpeed: Double {
        let arrowsFired = 10 - arrowsLeft
        let level = arrowsFired / 3
        return 1.5 + Double(level) * 0.6
    }

    var aimOffset: CGFloat {
        CGFloat(sin(aimAngle) * 90)
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
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
        VStack(spacing: 24) {
            Text("ARCHERY").font(.largeTitle).bold()
            Text("10 arrows. Tap FIRE\nto release at the right moment.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Start Game") {
                startGame()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    var gameView: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Arrows: \(arrowsLeft)").font(.headline)
                Spacer()
                Text("Score: \(totalScore)").font(.headline)
            }
            .padding(.horizontal)

            ZStack {
                ForEach(0..<rings.count, id: \.self) { i in
                    Circle()
                        .fill(rings[i].color)
                        .frame(width: rings[i].radius * 2, height: rings[i].radius * 2)
                }
                ForEach(0..<arrowPositions.count, id: \.self) { i in
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.purple)
                        .font(.system(size: 14, weight: .bold))
                        .offset(x: arrowPositions[i].0, y: arrowPositions[i].1)
                }
                Rectangle()
                    .fill(Color.green.opacity(0.8))
                    .frame(width: 3, height: 30)
                    .offset(x: aimOffset, y: -110)
            }
            .frame(width: 220, height: 260)

            if let pts = lastHitPoints {
                Text(pts > 0 ? "+\(pts)" : "Miss!")
                    .font(.title2).bold()
                    .foregroundStyle(pts > 0 ? .green : .red)
                    .transition(.scale)
            }

            Button("FIRE") {
                fireArrow()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(arrowsLeft == 0)
        }
        .padding()
    }

    var gameOverView: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.largeTitle).bold()
            Text("Final Score").font(.title3).foregroundStyle(.secondary)
            Text("\(totalScore)").font(.system(size: 72, weight: .black))
            Text("out of 100").foregroundStyle(.secondary)
            Button("Play Again") {
                phase = .start
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }

    func startGame() {
        arrowsLeft = 10
        totalScore = 0
        arrowPositions = []
        lastHitPoints = nil
        aimAngle = 0
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
        let dist = abs(offset)
        var pts = 0
        for ring in rings.reversed() {
            if dist <= ring.radius {
                pts = ring.points
                break
            }
        }
        arrowsLeft -= 1
        totalScore += pts
        arrowPositions.append((offset, 0))
        withAnimation {
            lastHitPoints = pts
        }
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

#Preview { ArcheryView() }

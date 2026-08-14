import SwiftUI

enum ArcheryPhase {
    case start, playing, gameOver
}

struct ArcheryRing {
    let radius: CGFloat
    let color: Color
    let points: Int
}

struct ArcheryView: View {
    @State private var phase: ArcheryPhase = .start
    @AppStorage("archeryBestScore") private var bestScore: Int = 0
    @State private var aimAngle: Double = 0.0
    @State private var arrowsLeft: Int = 10
    @State private var totalScore: Int = 0
    @State private var arrowOffsets: [CGFloat] = []
    @State private var timer: Timer? = nil
    @State private var lastHitPoints: Int? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    let rings: [ArcheryRing] = [
        ArcheryRing(radius: 100, color: .white,  points: 2),
        ArcheryRing(radius: 80,  color: .black,  points: 4),
        ArcheryRing(radius: 60,  color: .blue,   points: 6),
        ArcheryRing(radius: 40,  color: .red,    points: 8),
        ArcheryRing(radius: 20,  color: .yellow, points: 10),
    ]

    var oscillationSpeed: Double {
        let arrowsFired = 10 - arrowsLeft
        let distanceLevel = arrowsFired / 3
        let baseSpeed = 1.5 + Double(distanceLevel) * 0.6
        return baseSpeed * difficultyMultiplier
    }

    var aimOffset: CGFloat {
        CGFloat(sin(aimAngle) * 90)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.2, blue: 0.5), Color(red: 0.4, green: 0.1, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

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

    var glassCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.white.opacity(0.3), lineWidth: 1)
            )
    }

    var startView: some View {
        VStack(spacing: 28) {
            Text("ARCHERY").font(.largeTitle).bold().foregroundStyle(.white)
            Text("10 arrows. Tap FIRE at the right moment.\nDifficulty adapts to your skill!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            Button("Start Game") { startGame() }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
                .controlSize(.large)
        }
        .padding(28)
        .background(glassCard)
        .padding()
    }

    var gameView: some View {
        VStack(spacing: 20) {
            HStack {
                Label("\(arrowsLeft) arrows", systemImage: "arrow.up")
                    .foregroundStyle(.white)
                Spacer()
                Text("Score: \(totalScore)")
                    .foregroundStyle(.white)
                    .bold()
            }
            .padding()
            .background(glassCard)
            .padding(.horizontal)

            if difficultyMultiplier > 1.05 {
                Text("ADAPTIVE: +\(Int((difficultyMultiplier - 1) * 100))% speed")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            ZStack {
                ForEach(0..<rings.count, id: \.self) { i in
                    Circle()
                        .fill(rings[i].color)
                        .frame(width: rings[i].radius * 2, height: rings[i].radius * 2)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                ForEach(0..<arrowOffsets.count, id: \.self) { i in
                    Image(systemName: "arrow.down")
                        .foregroundStyle(.purple)
                        .font(.system(size: 14, weight: .bold))
                        .offset(x: arrowOffsets[i], y: 0)
                }
                Capsule()
                    .fill(Color.green)
                    .frame(width: 4, height: 28)
                    .offset(x: aimOffset, y: -112)
            }
            .frame(width: 220, height: 260)
            .padding()
            .background(glassCard)
            .padding(.horizontal)

            if let pts = lastHitPoints {
                Text(pts > 0 ? "+\(pts) pts!" : "Miss!")
                    .font(.title2).bold()
                    .foregroundStyle(pts > 0 ? .green : .orange)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Button("FIRE") { fireArrow() }
                .buttonStyle(.borderedProminent)
                .tint(.red.opacity(0.85))
                .controlSize(.large)
                .disabled(arrowsLeft == 0)
        }
        .padding(.vertical)
    }

    var gameOverView: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.largeTitle).bold().foregroundStyle(.white)
            VStack(spacing: 8) {
                Text("Final Score").foregroundStyle(.white.opacity(0.7))
                Text("\(totalScore)").font(.system(size: 72, weight: .black)).foregroundStyle(.yellow)
                Text("out of 100 · best \(bestScore)").foregroundStyle(.white.opacity(0.7))
            }
            if difficultyMultiplier > 1.05 {
                Text("Adaptive difficulty peaked at \(Int((difficultyMultiplier - 1) * 100))% extra speed")
                    .font(.caption).foregroundStyle(.white.opacity(0.6))
            }
            Button("Play Again") { phase = .start }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.25))
                .controlSize(.large)
        }
        .padding(28)
        .background(glassCard)
        .padding()
    }

    func startGame() {
        arrowsLeft = 10
        totalScore = 0
        arrowOffsets = []
        lastHitPoints = nil
        aimAngle = 0
        recentResults = []
        difficultyMultiplier = 1.0
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
        arrowOffsets.append(offset)

        let hit = pts >= 6
        recentResults.append(hit)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 {
            let trues = recentResults.filter { $0 }.count
            if trues > 4 {
                difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
                recentResults = []
            }
        }

        withAnimation { lastHitPoints = pts }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation { lastHitPoints = nil }
        }

        if arrowsLeft == 0 {
            timer?.invalidate()
            bestScore = max(bestScore, totalScore)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                phase = .gameOver
            }
        }
    }
}

#Preview { ArcheryView() }

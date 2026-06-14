import SwiftUI

enum BtCkV2Phase { case start, playing, gameOver }

struct BeatClockViewV2: View {
    @State private var phase: BtCkV2Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var handAngle: Double = 0
    @State private var handSpeed: Double = 2.0
    @State private var targetStart: Double = 60
    @State private var zoneMoveTimer: Double = 5
    @State private var flashColor: Color = .clear
    @State private var gameTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyLevel: Int = 1
    @State private var resultBanner: String = ""
    @State private var showBanner: Bool = false

    private let tickInterval = 0.016
    private let targetWidth: Double = 30

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.35),
                                    Color(red: 0.25, green: 0.05, blue: 0.4)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            switch phase {
            case .start:   startScreen
            case .playing: playScreen
            case .gameOver: gameOverScreen
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BEAT CLOCK").font(.system(size: 38, weight: .black)).foregroundColor(.white)
            Text("Tap when the hand enters\nthe highlighted zone!")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8))
            VStack(spacing: 6) {
                Text("Hit +2pts  |  Miss -1pt").foregroundColor(.yellow.opacity(0.9))
                Text("Difficulty adapts to your performance").font(.caption).foregroundColor(.white.opacity(0.5))
            }
            Button(action: startGame) {
                Text("START GAME")
                    .font(.headline).bold()
                    .padding(.horizontal, 44).padding(.vertical, 15)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    .foregroundColor(.white)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var playScreen: some View {
        VStack(spacing: 16) {
            // Header stats
            HStack {
                glassLabel("Score", value: "\(score)")
                Spacer()
                glassLabel("Time", value: String(format: "%.1fs", timeLeft), highlight: timeLeft < 5)
                Spacer()
                glassLabel("Lv", value: "\(difficultyLevel)")
            }.padding(.horizontal, 20)

            // Clock
            ZStack {
                v2ClockFace
                Circle().fill(flashColor.opacity(0.25))
                    .animation(.easeOut(duration: 0.25), value: flashColor)
                if showBanner {
                    Text(resultBanner)
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(resultBanner == "+2" ? .green : .red)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: 290, height: 290)
            .onTapGesture { handleTap() }

            Text("Tap the clock to score!").foregroundColor(.white.opacity(0.5)).font(.caption)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("TIME'S UP").font(.system(size: 32, weight: .black)).foregroundColor(.white)
            Text("\(score)").font(.system(size: 64, weight: .black)).foregroundColor(.yellow)
            Text("pts").font(.caption).foregroundColor(.white.opacity(0.6))
            Text(score >= 20 ? "Incredible timing!" : score >= 10 ? "Nice work!" : "Keep at it!")
                .foregroundColor(.white.opacity(0.7))
            Button(action: resetGame) {
                Text("PLAY AGAIN")
                    .font(.headline).bold()
                    .padding(.horizontal, 44).padding(.vertical, 15)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
                    .foregroundColor(.white)
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    // MARK: - Clock

    var v2ClockFace: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            // Target arc
            BtCkV2ArcShape(startDeg: targetStart, endDeg: targetStart + targetWidth)
                .stroke(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round))
            // Hour marks
            ForEach(0..<12) { i in
                Capsule().fill(.white.opacity(0.4))
                    .frame(width: 2, height: 12)
                    .offset(y: -125)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            // Hand
            Capsule().fill(LinearGradient(colors: [.pink, .red], startPoint: .top, endPoint: .bottom))
                .frame(width: 3, height: 105)
                .offset(y: -52)
                .rotationEffect(.degrees(handAngle))
            Circle().fill(.white).frame(width: 10, height: 10)
        }
    }

    // MARK: - Helpers

    func glassLabel(_ title: String, value: String, highlight: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundColor(.white.opacity(0.5))
            Text(value).font(.headline.bold()).foregroundColor(highlight ? .red : .white)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Logic

    func handleTap() {
        guard phase == .playing else { return }
        let h = ((handAngle.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let end = targetStart + targetWidth
        let inZone = end > 360 ? (h >= targetStart || h <= end - 360) : (h >= targetStart && h <= end)

        if inZone {
            score += 2
            flashColor = .green
            resultBanner = "+2"
            recentResults.append(true)
        } else {
            score -= 1
            flashColor = .red
            resultBanner = "-1"
            recentResults.append(false)
        }
        showBanner = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            flashColor = .clear
            showBanner = false
        }
        // Adaptive difficulty: if last 5 are >4 hits, increase speed
        if recentResults.count >= 5 {
            let last5 = recentResults.suffix(5)
            if last5.filter({ $0 }).count > 4 {
                difficultyLevel += 1
                handSpeed *= 1.2
                recentResults = []
            }
        }
    }

    func startGame() {
        score = 0; timeLeft = 30; handAngle = 0
        handSpeed = 2.0; difficultyLevel = 1
        targetStart = Double.random(in: 0..<330)
        zoneMoveTimer = 5; recentResults = []
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in tick() }
    }

    func tick() {
        handAngle = (handAngle + handSpeed).truncatingRemainder(dividingBy: 360)
        timeLeft -= tickInterval
        zoneMoveTimer -= tickInterval
        // Base speed increase over time
        let baseBoost = (30 - max(timeLeft, 0)) * 0.04
        handSpeed = max(handSpeed, 2.0 * Double(difficultyLevel) + baseBoost)
        if zoneMoveTimer <= 0 {
            targetStart = Double.random(in: 0..<330)
            zoneMoveTimer = 5
        }
        if timeLeft <= 0 { endGame() }
    }

    func endGame() {
        gameTimer?.invalidate(); gameTimer = nil
        phase = .gameOver
    }

    func resetGame() {
        recentResults = []
        phase = .start
    }
}

struct BtCkV2ArcShape: Shape {
    var startDeg: Double
    var endDeg: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: rect.midX, y: rect.midY),
                 radius: min(rect.width, rect.height) / 2,
                 startAngle: .degrees(startDeg - 90),
                 endAngle: .degrees(endDeg - 90), clockwise: false)
        return p
    }
}

#Preview { BeatClockViewV2() }

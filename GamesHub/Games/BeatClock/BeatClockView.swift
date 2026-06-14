import SwiftUI

enum BtCkPhase { case start, playing, gameOver }

struct BeatClockView: View {
    @State private var phase: BtCkPhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var handAngle: Double = 0
    @State private var handSpeed: Double = 2.0  // degrees per tick
    @State private var targetStart: Double = 60
    @State private var zoneMoveTimer: Double = 5
    @State private var flashColor: Color = .clear
    @State private var gameTimer: Timer? = nil

    private let tickInterval = 0.016  // ~60fps
    private let targetWidth: Double = 30

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start:   startScreen
            case .playing: playScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("BEAT CLOCK").font(.system(size: 38, weight: .black)).foregroundColor(.white)
            Text("Tap when the hand enters\nthe highlighted zone!")
                .multilineTextAlignment(.center).foregroundColor(.gray)
            Text("Hit: +2pts   Miss: -1pt").foregroundColor(.yellow)
            Button(action: startGame) {
                Text("START").font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.white).foregroundColor(.black).clipShape(Capsule())
            }
        }
    }

    var playScreen: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Score: \(score)").font(.title2.bold()).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1fs", timeLeft)).font(.title2.bold()).foregroundColor(timeLeft < 5 ? .red : .white)
            }.padding(.horizontal, 24)

            ZStack {
                clockFace
                flashOverlay
            }
            .frame(width: 300, height: 300)
            .onTapGesture { handleTap() }

            Text("Tap anywhere on the clock!").foregroundColor(.gray).font(.subheadline)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 34, weight: .black)).foregroundColor(.white)
            Text("Score: \(score)").font(.system(size: 52, weight: .bold)).foregroundColor(.yellow)
            Text(score >= 20 ? "Excellent rhythm!" : score >= 10 ? "Nice timing!" : "Keep practicing!")
                .foregroundColor(.gray)
            Button(action: resetGame) {
                Text("PLAY AGAIN").font(.headline).padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.white).foregroundColor(.black).clipShape(Capsule())
            }
        }
    }

    // MARK: - Clock Face

    var clockFace: some View {
        ZStack {
            // Outer rim
            Circle().stroke(Color.white.opacity(0.2), lineWidth: 8)
            // Target zone arc
            BtCkArcShape(startDeg: targetStart, endDeg: targetStart + targetWidth)
                .stroke(Color.green.opacity(0.7), lineWidth: 8)
            // Clock face
            Circle().fill(Color.white.opacity(0.05))
            // Hour markers
            ForEach(0..<12) { i in
                Rectangle().fill(Color.white.opacity(0.5))
                    .frame(width: 2, height: 10)
                    .offset(y: -130)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            // Second hand
            Rectangle().fill(Color.red)
                .frame(width: 2, height: 110)
                .offset(y: -55)
                .rotationEffect(.degrees(handAngle))
            // Center dot
            Circle().fill(Color.white).frame(width: 8, height: 8)
        }
    }

    var flashOverlay: some View {
        Circle().fill(flashColor.opacity(0.3))
            .animation(.easeOut(duration: 0.2), value: flashColor)
    }

    // MARK: - Logic

    func handleTap() {
        guard phase == .playing else { return }
        let normalized = handAngle.truncatingRemainder(dividingBy: 360)
        let h = normalized < 0 ? normalized + 360 : normalized
        let end = targetStart + targetWidth
        let inZone: Bool
        if end > 360 {
            inZone = h >= targetStart || h <= end - 360
        } else {
            inZone = h >= targetStart && h <= end
        }
        if inZone {
            score += 2
            flashColor = .green
        } else {
            score -= 1
            flashColor = .red
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { flashColor = .clear }
    }

    func startGame() {
        score = 0; timeLeft = 30; handAngle = 0; handSpeed = 2.0
        targetStart = Double.random(in: 0..<330)
        zoneMoveTimer = 5; phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            tick()
        }
    }

    func tick() {
        handAngle += handSpeed
        if handAngle >= 360 { handAngle -= 360 }
        timeLeft -= tickInterval
        zoneMoveTimer -= tickInterval
        // Increase speed over time
        handSpeed = 2.0 + (30 - max(timeLeft, 0)) * 0.05
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
        phase = .start
    }
}

struct BtCkArcShape: Shape {
    var startDeg: Double
    var endDeg: Double
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        p.addArc(center: center, radius: radius,
                 startAngle: .degrees(startDeg - 90),
                 endAngle: .degrees(endDeg - 90), clockwise: false)
        return p
    }
}

#Preview { BeatClockView() }

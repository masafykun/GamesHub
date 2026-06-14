import SwiftUI

struct BtCkLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum BtCkV3Phase { case start, playing, gameOver }

struct BeatClockViewV3: View {
    @State private var phase: BtCkV3Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Double = 30
    @State private var handAngle: Double = 0
    @State private var handSpeed: Double = 2.0
    @State private var targetStart: Double = 60
    @State private var zoneMoveTimer: Double = 5
    @State private var flashColor: Color = .clear
    @State private var gameTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var lcg: BtCkLCG = BtCkLCG(seed: 1)
    @State private var comboCount: Int = 0
    @State private var comboLabel: String = ""
    @State private var showCombo: Bool = false
    // LCG-driven zone schedule
    @State private var zoneSchedule: [Double] = []
    @State private var zoneIndex: Int = 0

    private let tickInterval = 0.016
    private let targetWidth: Double = 30

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start:   startScreen
            case .playing: playScreen
            case .gameOver: gameOverScreen
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("BEAT CLOCK").font(.system(size: 36, weight: .black)).foregroundColor(.primary)
            Text("Tap when the hand enters\nthe highlighted zone!")
                .multilineTextAlignment(.center).foregroundColor(.secondary)
            VStack(spacing: 4) {
                Text("Hit +2pts  |  Miss -1pt").foregroundColor(.orange)
                Text("Combo bonuses available!").font(.caption).foregroundColor(.secondary)
            }
            Button(action: startGame) {
                Text("START")
                    .font(.headline).bold()
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    var playScreen: some View {
        VStack(spacing: 16) {
            // Stats row
            HStack {
                v3StatBox(title: "SCORE", value: "\(score)")
                Spacer()
                v3StatBox(title: "TIME", value: String(format: "%.1f", timeLeft),
                          accent: timeLeft < 5 ? .red : .orange)
                Spacer()
                v3StatBox(title: "COMBO", value: "x\(comboCount)")
            }.padding(.horizontal, 20)

            // Clock
            ZStack {
                v3ClockFace
                Circle().fill(flashColor.opacity(0.2))
                    .animation(.easeOut(duration: 0.2), value: flashColor)
                if showCombo && !comboLabel.isEmpty {
                    Text(comboLabel)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.orange)
                        .transition(.scale(scale: 0.5).combined(with: .opacity))
                }
            }
            .frame(width: 290, height: 290)
            .onTapGesture { handleTap() }

            // Seed display
            Text("SEED: #\(seedInt)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(.systemGray3))
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("GAME OVER").font(.system(size: 30, weight: .black)).foregroundColor(.primary)
            Text("\(score)").font(.system(size: 60, weight: .black, design: .rounded)).foregroundColor(.orange)
            Text("pts").font(.subheadline).foregroundColor(.secondary)
            Text(score >= 20 ? "Perfect rhythm!" : score >= 10 ? "Good timing!" : "Try again!")
                .foregroundColor(.secondary)
            Text("Seed: #\(seedInt)")
                .font(.system(size: 11, design: .monospaced)).foregroundColor(Color(.systemGray3))
            Button(action: resetGame) {
                Text("PLAY AGAIN")
                    .font(.headline).bold()
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .foregroundColor(.white)
                    .background(Color.orange)
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.3), radius: 8, x: 0, y: 4)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    // MARK: - Clock

    var v3ClockFace: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.18), radius: 10, x: 6, y: 6)
                .shadow(color: Color.white.opacity(0.85), radius: 10, x: -6, y: -6)
            Circle().stroke(Color(.systemGray4), lineWidth: 1)
            // Target zone
            BtCkV3ArcShape(startDeg: targetStart, endDeg: targetStart + targetWidth)
                .stroke(Color.orange.opacity(0.85), style: StrokeStyle(lineWidth: 10, lineCap: .round))
            // Hour marks
            ForEach(0..<12) { i in
                Capsule().fill(Color(.systemGray3))
                    .frame(width: 2.5, height: 12)
                    .offset(y: -124)
                    .rotationEffect(.degrees(Double(i) * 30))
            }
            // Minute marks
            ForEach(0..<60) { i in
                if i % 5 != 0 {
                    Capsule().fill(Color(.systemGray5))
                        .frame(width: 1, height: 6)
                        .offset(y: -127)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
            }
            // Hand
            Capsule().fill(Color.orange)
                .frame(width: 3, height: 100)
                .offset(y: -50)
                .rotationEffect(.degrees(handAngle))
                .shadow(color: .orange.opacity(0.4), radius: 4)
            // Center
            Circle()
                .fill(Color(.systemGray6))
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.8), radius: 3, x: -2, y: -2)
                .frame(width: 14, height: 14)
            Circle().fill(Color.orange).frame(width: 8, height: 8)
        }
    }

    // MARK: - Helpers

    func v3StatBox(title: String, value: String, accent: Color = .orange) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).foregroundColor(accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .neumorphicCard(radius: 12)
    }

    // MARK: - Logic

    func buildZoneSchedule(lcg: inout BtCkLCG) -> [Double] {
        (0..<6).map { _ in Double(lcg.nextInt(330)) }
    }

    func handleTap() {
        guard phase == .playing else { return }
        let h = ((handAngle.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        let end = targetStart + targetWidth
        let inZone = end > 360 ? (h >= targetStart || h <= end - 360) : (h >= targetStart && h <= end)

        if inZone {
            comboCount += 1
            let bonus = comboCount >= 3 ? 1 : 0
            score += 2 + bonus
            flashColor = .green
            if comboCount >= 3 {
                comboLabel = "COMBO x\(comboCount)! +\(2+bonus)"
            } else {
                comboLabel = "+2"
            }
        } else {
            score -= 1
            comboCount = 0
            flashColor = .red
            comboLabel = "-1"
        }
        showCombo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            flashColor = .clear
            showCombo = false
        }
    }

    func startGame() {
        score = 0; timeLeft = 30; handAngle = 0
        handSpeed = 2.0; comboCount = 0; zoneIndex = 0
        var gen = BtCkLCG(seed: seedInt)
        lcg = gen
        zoneSchedule = buildZoneSchedule(lcg: &gen)
        targetStart = zoneSchedule.first ?? 60
        zoneMoveTimer = 5
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in tick() }
    }

    func tick() {
        handAngle = (handAngle + handSpeed).truncatingRemainder(dividingBy: 360)
        timeLeft -= tickInterval
        zoneMoveTimer -= tickInterval
        // Speed ramp
        handSpeed = 2.0 + (30 - max(timeLeft, 0)) * 0.05
        if zoneMoveTimer <= 0 {
            zoneIndex = (zoneIndex + 1) % zoneSchedule.count
            targetStart = zoneSchedule[zoneIndex]
            zoneMoveTimer = 5
        }
        if timeLeft <= 0 { endGame() }
    }

    func endGame() {
        gameTimer?.invalidate(); gameTimer = nil
        phase = .gameOver
    }

    func resetGame() {
        seedInt += 1
        phase = .start
    }
}

struct BtCkV3ArcShape: Shape {
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

#Preview { BeatClockViewV3() }

import SwiftUI

// MARK: - LCG Seeded RNG

struct ClWvLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
    mutating func nextInt(_ n: Int) -> Int {
        guard n > 0 else { return 0 }
        return Int(next() % UInt64(n))
    }
}

// MARK: - Supporting Types

enum ClWvV3Phase {
    case start, playing, gameOver
}

struct ClWvV3Band: Identifiable {
    let id = UUID()
    var hue: Double
    var yOffset: CGFloat
}

// MARK: - V3 View (Neumorphism + Seeded Generation)

struct ColorWaveViewV3: View {
    @State private var phase: ClWvV3Phase = .start
    @State private var score: Int = 0
    @State private var lives: Int = 5
    @State private var bands: [ClWvV3Band] = []
    @State private var targetHue: Double = 0.0
    @State private var speed: Double = 60.0
    @State private var lastUpdate: Date = Date()
    @State private var hitFeedback: String = ""
    @State private var feedbackOpacity: Double = 0
    @State private var seedInt: Int = 1
    @State private var rng: ClWvLCG = ClWvLCG(seed: 1)

    let bandHeight: CGFloat = 80
    let markerY: CGFloat = 300
    let tolerance: Double = 0.12

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("COLOR WAVE")
                .font(.system(size: 38, weight: .black))
                .foregroundColor(Color(.systemGray))

            VStack(spacing: 8) {
                Text("Tap when the matching color")
                    .foregroundColor(Color(.systemGray2))
                Text("passes the marker line")
                    .foregroundColor(Color(.systemGray2))
                Text("Seeded procedural color sequences")
                    .font(.caption).foregroundColor(Color(.systemGray3))
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("PLAY")
                    .font(.title2.bold())
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }
        }.padding(.horizontal)
    }

    var gameScreen: some View {
        ZStack {
            GeometryReader { geo in
                // Band track area (inset for neumorphic feel)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(0.75), radius: 6, x: -4, y: -4)
                    .frame(width: geo.size.width - 32, height: geo.size.height - 200)
                    .position(x: geo.size.width / 2, y: (geo.size.height - 200) / 2 + 80)

                // Bands clipped to track
                ForEach(bands) { band in
                    Rectangle()
                        .fill(Color(hue: band.hue, saturation: 0.75, brightness: 0.88))
                        .frame(width: geo.size.width - 48, height: bandHeight)
                        .cornerRadius(8)
                        .position(x: geo.size.width / 2, y: band.yOffset)
                        .clipped()
                }

                // Marker line
                ZStack {
                    Capsule()
                        .fill(Color(.systemGray3))
                        .frame(width: geo.size.width - 48, height: 4)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                        .shadow(color: .white.opacity(0.8), radius: 2, x: 0, y: -1)
                }.position(x: geo.size.width / 2, y: markerY)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }

            VStack {
                // HUD
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SCORE").font(.caption.bold()).foregroundColor(Color(.systemGray3))
                        Text("\(score)").font(.title2.bold()).foregroundColor(Color(.systemGray))
                    }
                    .padding(12)
                    .neumorphicCard(radius: 12)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("LIVES").font(.caption.bold()).foregroundColor(Color(.systemGray3))
                        HStack(spacing: 4) {
                            ForEach(0..<5, id: \.self) { i in
                                Image(systemName: i < lives ? "heart.fill" : "heart")
                                    .foregroundColor(i < lives ? Color(.systemRed).opacity(0.7) : Color(.systemGray4))
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(12)
                    .neumorphicCard(radius: 12)
                }.padding(.horizontal, 24).padding(.top, 12)

                Spacer()

                // Target + Seed display
                VStack(spacing: 12) {
                    Text(hitFeedback)
                        .font(.title3.bold()).foregroundColor(Color(.systemGray2))
                        .opacity(feedbackOpacity)

                    HStack(spacing: 16) {
                        Text("TARGET").font(.caption.bold()).foregroundColor(Color(.systemGray3))
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hue: targetHue, saturation: 0.75, brightness: 0.88))
                            .frame(width: 64, height: 40)
                            .shadow(color: Color.black.opacity(0.15), radius: 4, x: 2, y: 2)
                            .shadow(color: Color.white.opacity(0.7), radius: 4, x: -2, y: -2)
                    }

                    Text("SEED: #\(seedInt)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(.systemGray4))
                }
                .padding(18)
                .neumorphicCard(radius: 16)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear { lastUpdate = Date() }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            updateBands()
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 28) {
            Text("GAME OVER")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(Color(.systemGray))

            VStack(spacing: 10) {
                Text("Final Score").font(.caption.bold()).foregroundColor(Color(.systemGray3))
                Text("\(score)")
                    .font(.system(size: 52, weight: .black))
                    .foregroundColor(Color(.systemOrange).opacity(0.8))
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(.systemGray4))
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("PLAY AGAIN")
                    .font(.title2.bold())
                    .foregroundColor(Color(.systemGray))
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }

            Button(action: { phase = .start }) {
                Text("Menu").foregroundColor(Color(.systemGray3))
            }
        }.padding(.horizontal)
    }

    // MARK: - Logic

    func startGame() {
        seedInt += 1
        rng = ClWvLCG(seed: seedInt)
        score = 0; lives = 5; speed = 60.0

        // Generate band hues using LCG
        bands = (0..<10).map { i in
            var localRng = rng
            let _ = localRng.next() // advance per band
            let hue = Double(i) / 10.0
            return ClWvV3Band(hue: hue, yOffset: CGFloat(i) * bandHeight)
        }
        // Use LCG to pick initial target hue from a set of 8 spectrum segments
        let hueIndex = rng.nextInt(8)
        targetHue = Double(hueIndex) / 8.0
        lastUpdate = Date()
        phase = .playing
    }

    func updateBands() {
        let now = Date()
        let dt = now.timeIntervalSince(lastUpdate)
        lastUpdate = now
        let move = CGFloat(speed * dt)
        for i in bands.indices {
            bands[i].yOffset -= move
            if bands[i].yOffset < -bandHeight {
                let maxY = bands.map(\.yOffset).max() ?? 0
                bands[i].yOffset = maxY + bandHeight
                // LCG-derived hue for new band
                bands[i].hue = rng.nextDouble()
            }
        }
    }

    func handleTap() {
        let closestBand = bands.min(by: { abs($0.yOffset - markerY) < abs($1.yOffset - markerY) })
        guard let band = closestBand else { return }
        let diff = abs(band.hue - targetHue)
        let hueDiff = min(diff, 1.0 - diff)

        if hueDiff < tolerance {
            score += 2
            speed = min(speed + 6, 220)
            // LCG picks next target from 12 hue slots
            let hueSlot = rng.nextInt(12)
            targetHue = Double(hueSlot) / 12.0
            showFeedback("HIT! +2")
        } else {
            lives -= 1
            showFeedback("MISS")
            if lives <= 0 { phase = .gameOver }
        }
    }

    func showFeedback(_ text: String) {
        hitFeedback = text
        feedbackOpacity = 1
        withAnimation(.easeOut(duration: 0.8)) { feedbackOpacity = 0 }
    }
}

#Preview { ColorWaveViewV3() }

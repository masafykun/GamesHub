import SwiftUI

// MARK: - Supporting Types

enum ColorWavePhase {
    case start, playing, gameOver
}

struct ColorWaveBand: Identifiable {
    let id = UUID()
    var hue: Double
    var yOffset: CGFloat
}

// MARK: -  View (Glassmorphism + Adaptive Difficulty)

struct ColorWaveView: View {
    @State private var phase: ColorWavePhase = .start
    @State private var score: Int = 0
    @State private var lives: Int = 5
    @State private var bands: [ColorWaveBand] = []
    @State private var targetHue: Double = 0.0
    @State private var speed: Double = 60.0
    @State private var lastUpdate: Date = Date()
    @State private var hitFeedback: String = ""
    @State private var feedbackOpacity: Double = 0
    @State private var recentResults: [Bool] = []

    let bandHeight: CGFloat = 80
    let markerY: CGFloat = 300
    let tolerance: Double = 0.12

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hue: 0.62, saturation: 0.7, brightness: 0.3),
                         Color(hue: 0.85, saturation: 0.6, brightness: 0.2)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Glass Panel Helper

    func glassPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 32) {
            Text("COLOR WAVE")
                .font(.system(size: 40, weight: .black))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.4), radius: 8)

            glassPanel {
                VStack(spacing: 8) {
                    Text("Tap when the matching color").foregroundColor(.white.opacity(0.9))
                    Text("passes the marker line").foregroundColor(.white.opacity(0.9))
                    Text("Adaptive difficulty — get better, it gets harder!")
                        .font(.caption).foregroundColor(.white.opacity(0.6))
                }.padding(20)
            }.padding(.horizontal)

            Button(action: startGame) {
                Text("PLAY").font(.title2.bold()).foregroundColor(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.5), lineWidth: 1))
            }
        }
    }

    var gameScreen: some View {
        ZStack {
            GeometryReader { geo in
                ForEach(bands) { band in
                    Rectangle()
                        .fill(Color(hue: band.hue, saturation: 0.85, brightness: 0.95).opacity(0.85))
                        .frame(width: geo.size.width, height: bandHeight)
                        .position(x: geo.size.width / 2, y: band.yOffset)
                }
                // Marker line
                ZStack {
                    Rectangle().fill(.white.opacity(0.9)).frame(width: geo.size.width, height: 3)
                    Text("TAP HERE").font(.caption2.bold()).foregroundColor(.white.opacity(0.7))
                        .offset(x: geo.size.width / 2 - 50, y: -12)
                }.position(x: geo.size.width / 2, y: markerY)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }

            VStack {
                glassPanel {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                            Text("\(score)").font(.title2.bold()).foregroundColor(.white)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LIVES").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                            HStack(spacing: 4) {
                                ForEach(0..<5, id: \.self) { i in
                                    Image(systemName: i < lives ? "heart.fill" : "heart")
                                        .foregroundColor(i < lives ? .red : .gray.opacity(0.5))
                                        .font(.caption)
                                }
                            }
                        }
                    }.padding(.horizontal, 16).padding(.vertical, 10)
                }.padding(.horizontal).padding(.top, 8)

                Spacer()

                glassPanel {
                    VStack(spacing: 10) {
                        Text(hitFeedback).font(.title3.bold()).foregroundColor(.white)
                            .opacity(feedbackOpacity)
                        HStack(spacing: 16) {
                            Text("TARGET").font(.caption.bold()).foregroundColor(.white.opacity(0.7))
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(hue: targetHue, saturation: 0.85, brightness: 0.95))
                                .frame(width: 70, height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.5), lineWidth: 1))
                        }
                        if recentResults.count >= 5 {
                            let streak = recentResults.suffix(5).filter { $0 }.count
                            Text(streak >= 4 ? "On fire! Speed up!" : "Keep going!")
                                .font(.caption2).foregroundColor(.white.opacity(0.5))
                        }
                    }.padding(16)
                }.padding(.horizontal).padding(.bottom, 32)
            }
        }
        .onAppear { lastUpdate = Date() }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            updateBands()
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER")
                .font(.system(size: 36, weight: .black))
                .foregroundColor(.white)
                .shadow(color: .white.opacity(0.3), radius: 6)

            glassPanel {
                VStack(spacing: 12) {
                    Text("Final Score").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                    Text("\(score)").font(.system(size: 48, weight: .black)).foregroundColor(.yellow)
                    let accuracy = recentResults.isEmpty ? 0 :
                        Int(Double(recentResults.filter { $0 }.count) / Double(recentResults.count) * 100)
                    Text("Accuracy: \(accuracy)%").foregroundColor(.white.opacity(0.7))
                }.padding(24)
            }.padding(.horizontal)

            Button(action: startGame) {
                Text("PLAY AGAIN").font(.title2.bold()).foregroundColor(.white)
                    .padding(.horizontal, 48).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 30))
                    .overlay(RoundedRectangle(cornerRadius: 30).stroke(.white.opacity(0.5), lineWidth: 1))
            }
            Button(action: { phase = .start }) {
                Text("Menu").foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0; lives = 5; speed = 60.0; recentResults = []
        bands = (0..<10).map { i in
            ColorWaveBand(hue: Double(i) / 10.0, yOffset: CGFloat(i) * bandHeight)
        }
        targetHue = Double.random(in: 0...1)
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
                bands[i].hue = Double.random(in: 0...1)
            }
        }
    }

    func handleTap() {
        let closestBand = bands.min(by: { abs($0.yOffset - markerY) < abs($1.yOffset - markerY) })
        guard let band = closestBand else { return }
        let diff = abs(band.hue - targetHue)
        let hueDiff = min(diff, 1.0 - diff)
        let isHit = hueDiff < tolerance

        recentResults.append(isHit)
        if recentResults.count > 10 { recentResults.removeFirst() }

        // Adaptive difficulty: if last 5 had >4 hits, increase speed by ~20%
        if recentResults.count >= 5 && recentResults.suffix(5).filter({ $0 }).count > 4 {
            speed = min(speed * 1.2, 250)
        }

        if isHit {
            score += 2
            targetHue = Double.random(in: 0...1)
            showFeedback("HIT! +2")
        } else {
            lives -= 1
            showFeedback("MISS -1")
            if lives <= 0 { phase = .gameOver }
        }
    }

    func showFeedback(_ text: String) {
        hitFeedback = text
        feedbackOpacity = 1
        withAnimation(.easeOut(duration: 0.8)) { feedbackOpacity = 0 }
    }
}

#Preview { ColorWaveView() }

import SwiftUI

// MARK: - Supporting Types

enum ClWvGamePhase {
    case start, playing, gameOver
}

struct ClWvBand: Identifiable {
    let id = UUID()
    var hue: Double
    var yOffset: CGFloat
}

// MARK: - Main View

struct ColorWaveView: View {
    @State private var phase: ClWvGamePhase = .start
    @State private var score: Int = 0
    @State private var lives: Int = 5
    @State private var bands: [ClWvBand] = []
    @State private var targetHue: Double = 0.0
    @State private var speed: Double = 60.0
    @State private var lastUpdate: Date = Date()
    @State private var hitFeedback: String = ""
    @State private var feedbackOpacity: Double = 0

    let bandHeight: CGFloat = 80
    let markerY: CGFloat = 300
    let tolerance: Double = 0.12

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("COLOR WAVE").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            Text("Tap when the matching color\npasses the marker line")
                .multilineTextAlignment(.center).foregroundColor(.gray)
            Button(action: startGame) {
                Text("PLAY").font(.title2.bold())
                    .foregroundColor(.black).padding(.horizontal, 48).padding(.vertical, 14)
                    .background(Color.white).cornerRadius(30)
            }
        }
    }

    var gameScreen: some View {
        ZStack {
            // Scrolling bands
            GeometryReader { geo in
                ForEach(bands) { band in
                    Rectangle()
                        .fill(Color(hue: band.hue, saturation: 0.85, brightness: 0.95))
                        .frame(width: geo.size.width, height: bandHeight)
                        .position(x: geo.size.width / 2, y: band.yOffset)
                }
                // Marker line
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: geo.size.width, height: 3)
                    .position(x: geo.size.width / 2, y: markerY)
                    .shadow(color: .white, radius: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleTap() }

            // HUD
            VStack {
                HStack {
                    Text("Score: \(score)").foregroundColor(.white).bold()
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Image(systemName: i < lives ? "heart.fill" : "heart")
                                .foregroundColor(i < lives ? .red : .gray)
                        }
                    }
                }.padding()
                Spacer()
                // Target swatch + feedback
                VStack(spacing: 8) {
                    Text(hitFeedback).font(.title.bold()).foregroundColor(.white)
                        .opacity(feedbackOpacity)
                    HStack(spacing: 16) {
                        Text("TARGET").foregroundColor(.white.opacity(0.7)).font(.caption.bold())
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(hue: targetHue, saturation: 0.85, brightness: 0.95))
                            .frame(width: 60, height: 40)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2))
                    }
                }.padding(.bottom, 40)
            }
        }
        .onAppear { lastUpdate = Date() }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            updateBands()
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 36, weight: .black)).foregroundColor(.white)
            Text("Score: \(score)").font(.title.bold()).foregroundColor(.yellow)
            Button(action: startGame) {
                Text("PLAY AGAIN").font(.title2.bold())
                    .foregroundColor(.black).padding(.horizontal, 48).padding(.vertical, 14)
                    .background(Color.white).cornerRadius(30)
            }
            Button(action: { phase = .start }) {
                Text("Menu").foregroundColor(.gray)
            }
        }
    }

    // MARK: - Logic

    func startGame() {
        score = 0; lives = 5; speed = 60.0
        bands = (0..<10).map { i in
            ClWvBand(hue: Double(i) / 10.0, yOffset: CGFloat(i) * bandHeight)
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
        if hueDiff < tolerance {
            score += 2
            speed = min(speed + 5, 200)
            targetHue = Double.random(in: 0...1)
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

#Preview { ColorWaveView() }

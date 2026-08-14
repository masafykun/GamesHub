import SwiftUI

enum RhythmTapPhase { case start, playing, gameOver }

struct RhythmTapNote: Identifiable {
    let id = UUID()
    let lane: Int
    var position: Double
    var hit: Bool = false
    var missed: Bool = false
}

struct RhythmTapStats {
    var perfect: Int = 0
    var good: Int = 0
    var miss: Int = 0
    var score: Int = 0
}

struct RhythmTapView: View {
    @State private var phase: RhythmTapPhase = .start
    @AppStorage("rhythmTapBestScore") private var bestScore: Int = 0
    @State private var stats = RhythmTapStats()
    @State private var notes: [RhythmTapNote] = []
    @State private var flashLane: [Bool] = [false, false, false, false]
    @State private var timeLeft: Double = 30
    @State private var bpm: Double = 80
    @State private var speedMultiplier: Double = 1.0
    @State private var gameTimer: Timer? = nil
    @State private var noteTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var lastRating: String = ""
    @State private var lastRatingOpacity: Double = 0

    let laneColors: [Color] = [.pink, .cyan, .mint, .orange]
    let targetY: Double = 0.85
    let tickInterval: Double = 0.016

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var glassPanel: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("RHYTHM TAP").font(.system(size: 42, weight: .black)).foregroundStyle(LinearGradient(colors: [.cyan, .pink], startPoint: .leading, endPoint: .trailing))
                Text(" — Adaptive Difficulty").font(.subheadline).foregroundColor(.white.opacity(0.7))
            }
            .padding(24)
            .background(glassPanel)

            Text("Tap each lane as notes hit the target zone.\nDo well and the game gets faster!").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8)).padding(.horizontal, 32)

            Button(action: startGame) {
                Text("START").font(.title2.bold()).foregroundColor(.white).padding(.horizontal, 48).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            }
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text("\(stats.score)").font(.title.bold()).foregroundColor(.white)
                }
                Spacer()
                if speedMultiplier > 1.05 {
                    Text("x\(String(format: "%.1f", speedMultiplier)) SPEED").font(.caption.bold()).foregroundColor(.orange).padding(.horizontal, 10).padding(.vertical, 4).background(.orange.opacity(0.2)).clipShape(Capsule())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME").font(.caption).foregroundColor(.white.opacity(0.6))
                    Text(String(format: "%.1f", timeLeft)).font(.title.bold()).foregroundColor(timeLeft < 5 ? .red : .white)
                }
            }
            .padding()
            .background(glassPanel.padding(.horizontal, 8))

            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { lane in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(laneColors[lane].opacity(flashLane[lane] ? 0.35 : 0.08))
                                .animation(.easeOut(duration: 0.1), value: flashLane[lane])
                        }
                    }.padding(.horizontal, 4)

                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { lane in
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(laneColors[lane].opacity(0.8), lineWidth: 2)
                                    .frame(height: 46)
                                    .position(x: (geo.size.width - 8) / 4 / 2, y: geo.size.height * targetY)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(laneColors[lane].opacity(0.15))
                                    .frame(height: 46)
                                    .position(x: (geo.size.width - 8) / 4 / 2, y: geo.size.height * targetY)
                            }
                        }
                    }.padding(.horizontal, 4)

                    ForEach(notes) { note in
                        if !note.hit && !note.missed {
                            Circle()
                                .fill(RadialGradient(colors: [.white, laneColors[note.lane]], center: .center, startRadius: 2, endRadius: 18))
                                .frame(width: 36, height: 36)
                                .shadow(color: laneColors[note.lane].opacity(0.8), radius: 8)
                                .position(
                                    x: 4 + (CGFloat(note.lane) + 0.5) * ((geo.size.width - 8) / 4),
                                    y: note.position * geo.size.height
                                )
                        }
                    }

                    if lastRatingOpacity > 0 {
                        Text(lastRating)
                            .font(.title.bold())
                            .foregroundColor(lastRating == "PERFECT" ? .cyan : lastRating == "GOOD" ? .yellow : .red)
                            .opacity(lastRatingOpacity)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.5)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { lane in
                    Button(action: { tapLane(lane) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(laneColors[lane].opacity(0.3))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(laneColors[lane].opacity(0.6), lineWidth: 1))
                                .frame(height: 60)
                            Text(["A","B","C","D"][lane]).font(.title2.bold()).foregroundColor(.white)
                        }
                    }
                }
            }.padding(.horizontal, 8).padding(.vertical, 10)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("GAME OVER").font(.system(size: 36, weight: .black)).foregroundStyle(LinearGradient(colors: [.cyan, .pink], startPoint: .leading, endPoint: .trailing))

            VStack(spacing: 12) {
                Text("\(stats.score)").font(.system(size: 60, weight: .black)).foregroundColor(.white)
                Text("POINTS").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
            }

            VStack(spacing: 10) {
                HStack {
                    Text("Perfect").foregroundColor(.cyan)
                    Spacer()
                    Text("\(stats.perfect)").bold().foregroundColor(.white)
                }
                HStack {
                    Text("Good").foregroundColor(.yellow)
                    Spacer()
                    Text("\(stats.good)").bold().foregroundColor(.white)
                }
                HStack {
                    Text("Miss").foregroundColor(.red)
                    Spacer()
                    Text("\(stats.miss)").bold().foregroundColor(.white)
                }
                if speedMultiplier > 1.05 {
                    Divider().background(.white.opacity(0.3))
                    HStack {
                        Text("Max Speed").foregroundColor(.orange)
                        Spacer()
                        Text("x\(String(format: "%.1f", speedMultiplier))").bold().foregroundColor(.white)
                    }
                }
            }
            .padding(20)
            .background(glassPanel)
            .padding(.horizontal, 32)

            Button(action: startGame) {
                Text("PLAY AGAIN").font(.title2.bold()).foregroundColor(.white).padding(.horizontal, 44).padding(.vertical, 14)
                    .background(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    func startGame() {
        stats = RhythmTapStats()
        notes = []
        flashLane = [false, false, false, false]
        timeLeft = 30
        bpm = 80
        speedMultiplier = 1.0
        recentResults = []
        phase = .playing
        startTimers()
    }

    func startTimers() {
        gameTimer?.invalidate()
        noteTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in updateGame() }
        scheduleNextNote()
    }

    func scheduleNextNote() {
        let interval = (60.0 / bpm) / speedMultiplier
        noteTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 0.2), repeats: false) { _ in
            guard phase == .playing else { return }
            let lane = Int.random(in: 0..<4)
            notes.append(RhythmTapNote(lane: lane, position: 0.0))
            scheduleNextNote()
        }
    }

    func updateGame() {
        guard phase == .playing else { return }
        timeLeft -= tickInterval
        if timeLeft <= 0 { endGame(); return }
        bpm = 80 + (1.0 - timeLeft / 30.0) * 60
        let speed = (bpm / 60.0) * tickInterval * 0.5 * speedMultiplier
        for i in notes.indices {
            notes[i].position += speed
            if notes[i].position > 1.1 && !notes[i].hit && !notes[i].missed {
                notes[i].missed = true
                stats.miss += 1
                addResult(false)
            }
        }
        notes.removeAll { $0.position > 1.2 }
    }

    func tapLane(_ lane: Int) {
        flashLane[lane] = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { flashLane[lane] = false }

        var best: (idx: Int, dist: Double)? = nil
        for (i, note) in notes.enumerated() {
            guard note.lane == lane && !note.hit && !note.missed else { continue }
            let dist = abs(note.position - targetY)
            if best == nil || dist < best!.dist { best = (i, dist) }
        }
        guard let b = best else { return }
        if b.dist <= 0.07 {
            notes[b.idx].hit = true
            stats.score += 100; stats.perfect += 1
            showRating("PERFECT"); addResult(true)
        } else if b.dist <= 0.14 {
            notes[b.idx].hit = true
            stats.score += 50; stats.good += 1
            showRating("GOOD"); addResult(true)
        } else {
            showRating("MISS"); addResult(false)
        }
    }

    func addResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count >= 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
            recentResults = []
        }
    }

    func showRating(_ text: String) {
        lastRating = text
        lastRatingOpacity = 1.0
        withAnimation(.easeOut(duration: 0.8)) { lastRatingOpacity = 0 }
    }

    func endGame() {
        gameTimer?.invalidate()
        noteTimer?.invalidate()
        bestScore = max(bestScore, stats.score)
        phase = .gameOver
    }
}

#Preview { RhythmTapView() }

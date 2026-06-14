import SwiftUI

struct RTpLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum RTpV3Phase { case start, playing, gameOver }

struct RTpV3Note: Identifiable {
    let id = UUID()
    let lane: Int
    var position: Double
    var hit: Bool = false
    var missed: Bool = false
}

struct RTpV3Stats {
    var perfect: Int = 0
    var good: Int = 0
    var miss: Int = 0
    var score: Int = 0
}

struct RhythmTapViewV3: View {
    @State private var phase: RTpV3Phase = .start
    @State private var stats = RTpV3Stats()
    @State private var notes: [RTpV3Note] = []
    @State private var flashLane: [Bool] = [false, false, false, false]
    @State private var timeLeft: Double = 30
    @State private var bpm: Double = 80
    @State private var gameTimer: Timer? = nil
    @State private var noteTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var rng: RTpLCG = RTpLCG(seed: 1)
    @State private var lastRating: String = ""
    @State private var lastRatingOpacity: Double = 0
    @State private var noteSequence: [Int] = []
    @State private var noteSeqIndex: Int = 0

    let laneColors: [Color] = [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.3, green: 0.8, blue: 0.5), Color(red: 0.95, green: 0.7, blue: 0.2)]
    let targetY: Double = 0.85
    let tickInterval: Double = 0.016

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

    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("RHYTHM TAP").font(.system(size: 40, weight: .black)).foregroundColor(Color(.label))
                Text("V3 — Seeded Generation").font(.subheadline).foregroundColor(Color(.secondaryLabel))
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            VStack(spacing: 6) {
                Text("Notes are generated from a seed.").foregroundColor(Color(.secondaryLabel))
                Text("Every run with the same seed is identical!").foregroundColor(Color(.secondaryLabel))
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)

            VStack(spacing: 16) {
                HStack {
                    Text("Next Seed:").foregroundColor(Color(.secondaryLabel))
                    Spacer()
                    Text("#\(seedInt)").font(.system(.body, design: .monospaced)).foregroundColor(Color(.label))
                }
                .padding(.horizontal, 24)

                Button(action: startGame) {
                    Text("START GAME").font(.headline).foregroundColor(Color(.systemBackground)).padding(.horizontal, 48).padding(.vertical, 14)
                        .background(Color(.label)).clipShape(Capsule())
                }
            }
        }
        .padding()
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE").font(.caption.bold()).foregroundColor(Color(.secondaryLabel))
                    Text("\(stats.score)").font(.title.bold()).foregroundColor(Color(.label))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text("SEED: #\(seedInt)").font(.system(.caption2, design: .monospaced)).foregroundColor(Color(.secondaryLabel))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME").font(.caption.bold()).foregroundColor(Color(.secondaryLabel))
                    Text(String(format: "%.1f", timeLeft)).font(.title.bold()).foregroundColor(timeLeft < 5 ? .red : Color(.label))
                }
            }
            .padding()
            .neumorphicCard(radius: 14)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            GeometryReader { geo in
                ZStack {
                    // Lane backgrounds
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { lane in
                            RoundedRectangle(cornerRadius: 6)
                                .fill(flashLane[lane] ? laneColors[lane].opacity(0.2) : Color(.systemGray5))
                                .animation(.easeOut(duration: 0.1), value: flashLane[lane])
                        }
                    }.padding(.horizontal, 12)

                    // Target zones
                    HStack(spacing: 6) {
                        ForEach(0..<4, id: \.self) { lane in
                            GeometryReader { _ in
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8).fill(laneColors[lane].opacity(0.15)).frame(height: 44)
                                    RoundedRectangle(cornerRadius: 8).stroke(laneColors[lane], lineWidth: 2.5).frame(height: 44)
                                }
                                .position(x: (geo.size.width - 24) / 4 / 2, y: geo.size.height * targetY)
                            }
                        }
                    }.padding(.horizontal, 12)

                    // Notes
                    ForEach(notes) { note in
                        if !note.hit && !note.missed {
                            ZStack {
                                Circle().fill(Color(.systemGray6)).frame(width: 38, height: 38)
                                    .shadow(color: .black.opacity(0.25), radius: 5, x: 3, y: 3)
                                    .shadow(color: .white.opacity(0.9), radius: 5, x: -3, y: -3)
                                Circle().fill(laneColors[note.lane]).frame(width: 26, height: 26)
                                    .shadow(color: laneColors[note.lane].opacity(0.5), radius: 4)
                            }
                            .position(
                                x: 12 + (CGFloat(note.lane) + 0.5) * ((geo.size.width - 24) / 4),
                                y: note.position * geo.size.height
                            )
                        }
                    }

                    if lastRatingOpacity > 0 {
                        Text(lastRating)
                            .font(.title.bold())
                            .foregroundColor(lastRating == "PERFECT" ? .green : lastRating == "GOOD" ? .orange : .red)
                            .opacity(lastRatingOpacity)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.45)
                    }
                }
            }

            // Lane buttons
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { lane in
                    Button(action: { tapLane(lane) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                                .shadow(color: .black.opacity(0.22), radius: 6, x: 4, y: 4)
                                .shadow(color: .white.opacity(0.85), radius: 6, x: -4, y: -4)
                                .frame(height: 58)
                            RoundedRectangle(cornerRadius: 12)
                                .fill(laneColors[lane].opacity(flashLane[lane] ? 0.4 : 0.18))
                                .frame(height: 58)
                            Text(["A","B","C","D"][lane]).font(.title2.bold()).foregroundColor(laneColors[lane])
                        }
                    }
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("GAME OVER").font(.system(size: 34, weight: .black)).foregroundColor(Color(.label))
                Text("Seed #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(Color(.secondaryLabel))
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            VStack(spacing: 4) {
                Text("\(stats.score)").font(.system(size: 64, weight: .black)).foregroundColor(Color(.label))
                Text("POINTS").font(.caption.bold()).foregroundColor(Color(.secondaryLabel))
            }

            VStack(spacing: 12) {
                resultRow(label: "Perfect", value: stats.perfect, color: .green)
                resultRow(label: "Good", value: stats.good, color: .orange)
                resultRow(label: "Miss", value: stats.miss, color: .red)
            }
            .padding(20)
            .neumorphicCard(radius: 14)
            .padding(.horizontal, 32)

            Button(action: startGame) {
                Text("PLAY AGAIN").font(.headline).foregroundColor(Color(.systemBackground))
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .background(Color(.label)).clipShape(Capsule())
            }
        }
        .padding()
    }

    func resultRow(label: String, value: Int, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(label).foregroundColor(Color(.secondaryLabel))
            Spacer()
            Text("\(value)").font(.body.bold()).foregroundColor(Color(.label))
        }
    }

    func buildNoteSequence(count: Int) {
        var localRng = RTpLCG(seed: seedInt)
        noteSequence = (0..<count).map { _ in localRng.nextInt(4) }
        noteSeqIndex = 0
    }

    func startGame() {
        stats = RTpV3Stats()
        notes = []
        flashLane = [false, false, false, false]
        timeLeft = 30
        bpm = 80
        rng = RTpLCG(seed: seedInt)
        buildNoteSequence(count: 200)
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
        // Use LCG for slight timing variation
        let baseInterval = 60.0 / bpm
        let variation = rng.nextDouble() * 0.1
        let interval = baseInterval + variation
        noteTimer = Timer.scheduledTimer(withTimeInterval: max(interval, 0.25), repeats: false) { _ in
            guard phase == .playing else { return }
            let lane: Int
            if noteSeqIndex < noteSequence.count {
                lane = noteSequence[noteSeqIndex]
                noteSeqIndex += 1
            } else {
                lane = Int.random(in: 0..<4)
            }
            notes.append(RTpV3Note(lane: lane, position: 0.0))
            scheduleNextNote()
        }
    }

    func updateGame() {
        guard phase == .playing else { return }
        timeLeft -= tickInterval
        if timeLeft <= 0 { endGame(); return }
        bpm = 80 + (1.0 - timeLeft / 30.0) * 60
        let speed = (bpm / 60.0) * tickInterval * 0.5
        for i in notes.indices {
            notes[i].position += speed
            if notes[i].position > 1.1 && !notes[i].hit && !notes[i].missed {
                notes[i].missed = true
                stats.miss += 1
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
            showRating("PERFECT")
        } else if b.dist <= 0.14 {
            notes[b.idx].hit = true
            stats.score += 50; stats.good += 1
            showRating("GOOD")
        } else {
            showRating("MISS")
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
        seedInt += 1
        phase = .gameOver
    }
}

#Preview { RhythmTapViewV3() }

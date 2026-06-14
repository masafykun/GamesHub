import SwiftUI

enum RTpPhase { case start, playing, gameOver }
enum RTpHitRating { case perfect, good, miss }

struct RTpNote: Identifiable {
    let id = UUID()
    let lane: Int
    var position: Double // 0.0 (top) to 1.0 (bottom)
    var hit: Bool = false
    var missed: Bool = false
}

struct RTpLaneResult {
    var perfect: Int = 0
    var good: Int = 0
    var miss: Int = 0
}

struct RhythmTapView: View {
    @State private var phase: RTpPhase = .start
    @State private var score: Int = 0
    @State private var notes: [RTpNote] = []
    @State private var laneResults: [RTpLaneResult] = Array(repeating: RTpLaneResult(), count: 4)
    @State private var flashLane: [Bool] = [false, false, false, false]
    @State private var timeLeft: Double = 30
    @State private var bpm: Double = 80
    @State private var gameTimer: Timer? = nil
    @State private var noteTimer: Timer? = nil
    @State private var lastRatingText: String = ""

    let laneColors: [Color] = [.red, .blue, .green, .yellow]
    let targetY: Double = 0.85
    let tickInterval: Double = 0.016

    var totalNotes: Int { laneResults.reduce(0) { $0 + $1.perfect + $1.good + $1.miss } }
    var totalPerfect: Int { laneResults.reduce(0) { $0 + $1.perfect } }
    var totalGood: Int { laneResults.reduce(0) { $0 + $1.good } }
    var totalMiss: Int { laneResults.reduce(0) { $0 + $1.miss } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("RHYTHM TAP").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            Text("Tap the lane when the note reaches the target!").multilineTextAlignment(.center).foregroundColor(.gray).padding(.horizontal)
            Button(action: startGame) {
                Text("TAP TO START").font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14).background(Color.white).clipShape(Capsule())
            }
        }
    }

    var gameScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCORE: \(score)").font(.title2.bold()).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1fs", timeLeft)).font(.title2.bold()).foregroundColor(timeLeft < 5 ? .red : .white)
            }.padding()

            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { lane in
                            Rectangle().fill(laneColors[lane].opacity(0.08)).overlay(
                                Rectangle().fill(laneColors[lane].opacity(flashLane[lane] ? 0.5 : 0)).animation(.easeOut(duration: 0.1), value: flashLane[lane])
                            )
                        }
                    }
                    // Target zones
                    HStack(spacing: 4) {
                        ForEach(0..<4, id: \.self) { lane in
                            GeometryReader { _ in
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(laneColors[lane], lineWidth: 2)
                                    .frame(height: 44)
                                    .position(x: geo.size.width / 4 / 2, y: geo.size.height * targetY)
                            }
                        }
                    }
                    // Notes
                    ForEach(notes) { note in
                        if !note.hit && !note.missed {
                            Circle()
                                .fill(laneColors[note.lane])
                                .frame(width: 36, height: 36)
                                .position(
                                    x: (CGFloat(note.lane) + 0.5) * (geo.size.width / 4),
                                    y: note.position * geo.size.height
                                )
                        }
                    }
                }
                .contentShape(Rectangle())
            }

            // Lane buttons
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { lane in
                    Button(action: { tapLane(lane) }) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(laneColors[lane].opacity(0.7))
                            .frame(height: 60)
                            .overlay(Text(["A","B","C","D"][lane]).font(.title2.bold()).foregroundColor(.white))
                    }
                }
            }.padding(.horizontal, 4).padding(.vertical, 8)
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.system(size: 34, weight: .black)).foregroundColor(.white)
            Text("SCORE: \(score)").font(.title.bold()).foregroundColor(.yellow)
            VStack(spacing: 8) {
                Text("Perfect: \(totalPerfect)").foregroundColor(.green)
                Text("Good: \(totalGood)").foregroundColor(.yellow)
                Text("Miss: \(totalMiss)").foregroundColor(.red)
            }.font(.title3).padding().background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            Button(action: startGame) {
                Text("PLAY AGAIN").font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14).background(Color.white).clipShape(Capsule())
            }
        }
    }

    func startGame() {
        score = 0
        notes = []
        laneResults = Array(repeating: RTpLaneResult(), count: 4)
        timeLeft = 30
        bpm = 80
        phase = .playing
        startTimers()
    }

    func startTimers() {
        gameTimer?.invalidate()
        noteTimer?.invalidate()

        gameTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            updateGame()
        }
        scheduleNextNote()
    }

    func scheduleNextNote() {
        let interval = 60.0 / bpm
        noteTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            if phase == .playing {
                let lane = Int.random(in: 0..<4)
                notes.append(RTpNote(lane: lane, position: 0.0))
                scheduleNextNote()
            }
        }
    }

    func updateGame() {
        guard phase == .playing else { return }
        timeLeft -= tickInterval
        if timeLeft <= 0 {
            endGame(); return
        }
        // Increase BPM over time
        bpm = 80 + (1.0 - timeLeft / 30.0) * 60
        let speed = (bpm / 60.0) * tickInterval * 0.5
        for i in notes.indices {
            notes[i].position += speed
            if notes[i].position > 1.1 && !notes[i].hit {
                if !notes[i].missed {
                    notes[i].missed = true
                    laneResults[notes[i].lane].miss += 1
                }
            }
        }
        notes.removeAll { $0.position > 1.2 }
    }

    func tapLane(_ lane: Int) {
        flashLane[lane] = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { flashLane[lane] = false }

        let tgt = targetY
        var best: (idx: Int, dist: Double)? = nil
        for (i, note) in notes.enumerated() {
            guard note.lane == lane && !note.hit && !note.missed else { continue }
            let dist = abs(note.position - tgt)
            if best == nil || dist < best!.dist { best = (i, dist) }
        }
        guard let b = best else { return }
        if b.dist <= 0.07 {
            notes[b.idx].hit = true
            score += 100
            laneResults[lane].perfect += 1
        } else if b.dist <= 0.14 {
            notes[b.idx].hit = true
            score += 50
            laneResults[lane].good += 1
        }
    }

    func endGame() {
        gameTimer?.invalidate()
        noteTimer?.invalidate()
        phase = .gameOver
    }
}

#Preview { RhythmTapView() }

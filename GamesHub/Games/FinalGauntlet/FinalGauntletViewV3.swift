import SwiftUI

// MARK: - LCG Seeded Random

struct FnGtLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models V3

enum FnGtV3Phase { case start, stage1, stage2, stage3, stage4, stage5, results }

struct FnGtV3Target: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var tapped: Bool = false
}

// MARK: - Main View V3 (Neumorphism + Seeded Procedural Generation)

struct FinalGauntletViewV3: View {
    @State private var seedInt: Int = 1
    @State private var phase: FnGtV3Phase = .start
    @State private var totalScore: Int = 0
    @State private var rng: FnGtLCG = FnGtLCG(seed: 1)

    // Stage 1
    @State private var v3Targets: [FnGtV3Target] = []
    @State private var v3Stage1Score: Int = 0

    // Stage 2
    @State private var v3MathQ: String = ""
    @State private var v3MathAnswer: Int = 0
    @State private var v3MathChoices: [Int] = []
    @State private var v3TimeLeft: Double = 10
    @State private var v3MathTimer: Timer?
    @State private var v3MathResult: String = ""

    // Stage 3
    @State private var v3Simon: [Int] = []
    @State private var v3Flashing: Int? = nil
    @State private var v3SimonInput: [Int] = []
    @State private var v3Lives: Int = 2
    @State private var v3SimonMode: String = "watch"
    @State private var v3SimonScore: Int = 0

    // Stage 4
    @State private var v3SwipeDir: String = ""
    @State private var v3SwipeRound: Int = 0
    @State private var v3SwipeScore: Int = 0
    @State private var v3SwipeFeedback: String = ""
    let v3Dirs = ["up", "down", "left", "right"]
    let v3Arrows = ["up": "↑", "down": "↓", "left": "←", "right": "→"]

    // Stage 5
    @State private var v3ReactVisible: Bool = false
    @State private var v3ReactStart: Date = Date()
    @State private var v3ReactMS: Int = 0
    @State private var v3ReactDone: Bool = false
    @State private var v3ReactReady: Bool = false

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            VStack {
                // Seed display
                HStack {
                    Spacer()
                    Text("SEED: #\(seedInt)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.trailing, 16).padding(.top, 8)
                }
                Spacer()
            }
            switch phase {
            case .start: v3StartView
            case .stage1: v3Stage1View
            case .stage2: v3Stage2View
            case .stage3: v3Stage3View
            case .stage4: v3Stage4View
            case .stage5: v3Stage5View
            case .results: v3ResultsView
            }
        }
    }

    // MARK: Start
    var v3StartView: some View {
        VStack(spacing: 28) {
            Text("FINAL GAUNTLET")
                .font(.largeTitle.bold())
                .foregroundColor(Color(.label))
            VStack(spacing: 6) {
                Text("5 Challenges").font(.headline).foregroundColor(Color(.label))
                Text("Procedurally generated").font(.caption).foregroundColor(.gray)
            }
            .padding(20)
            .neumorphicCard(radius: 16)
            Button(action: { v3StartStage1() }) {
                Text("BEGIN")
                    .font(.headline.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }
        }
        .padding()
    }

    // MARK: Stage 1
    var v3Stage1View: some View {
        VStack(spacing: 12) {
            HStack {
                Text("STAGE 1: TARGETS").font(.headline).foregroundColor(Color(.label))
                Spacer()
                Text("\(v3Stage1Score)/5").font(.title3.bold()).foregroundColor(.orange)
            }
            .padding(16)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)
            GeometryReader { _ in
                ZStack {
                    ForEach(v3Targets) { t in
                        Circle()
                            .fill(Color.orange.opacity(0.85))
                            .frame(width: 54, height: 54)
                            .shadow(color: .orange.opacity(0.3), radius: 6, x: 3, y: 3)
                            .opacity(t.opacity)
                            .position(t.position)
                            .onTapGesture { v3TapTarget(t.id) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Stage 2
    var v3Stage2View: some View {
        VStack(spacing: 20) {
            HStack {
                Text("STAGE 2: MATH").font(.headline).foregroundColor(Color(.label))
                Spacer()
                Text("\(Int(v3TimeLeft))s").font(.title3.bold())
                    .foregroundColor(v3TimeLeft < 4 ? .red : .secondary)
            }
            .padding(16)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            Text(v3MathQ).font(.system(size: 44, weight: .bold)).foregroundColor(Color(.label))
                .padding(24)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)

            if v3MathResult.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(v3MathChoices, id: \.self) { c in
                        Button(action: { v3AnswerMath(c) }) {
                            Text("\(c)").font(.title3.bold()).foregroundColor(Color(.label))
                                .frame(maxWidth: .infinity).padding(.vertical, 18)
                                .neumorphicCard(radius: 12)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                Text(v3MathResult).font(.title2.bold())
                    .foregroundColor(v3MathResult.contains("Correct") ? .green : .red)
                    .padding(20)
                    .neumorphicCard(radius: 16)
                    .padding(.horizontal)
            }
        }
        .padding(.top)
    }

    // MARK: Stage 3
    var v3Stage3View: some View {
        VStack(spacing: 16) {
            HStack {
                Text("STAGE 3: SIMON").font(.headline).foregroundColor(Color(.label))
                Spacer()
                Text(String(repeating: "♥", count: v3Lives)).foregroundColor(.red).font(.title3)
            }
            .padding(16)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            Text(v3SimonMode == "watch" ? "Watch carefully..." : "Your turn!")
                .font(.subheadline).foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    let cols: [Color] = [.red, .green, .blue, .yellow]
                    RoundedRectangle(cornerRadius: 14)
                        .fill(v3Flashing == i ? cols[i] : cols[i].opacity(v3SimonMode == "input" ? 0.5 : 0.25))
                        .frame(height: 110)
                        .shadow(color: v3Flashing == i ? cols[i].opacity(0.5) : .black.opacity(0.12),
                                radius: v3Flashing == i ? 12 : 4, x: 3, y: 3)
                        .onTapGesture { if v3SimonMode == "input" { v3SimonTap(i) } }
                }
            }
            .padding(.horizontal)
            Text("Step \(v3SimonInput.count)/\(v3Simon.count)").font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: Stage 4
    var v3Stage4View: some View {
        VStack(spacing: 24) {
            HStack {
                Text("STAGE 4: SWIPE").font(.headline).foregroundColor(Color(.label))
                Spacer()
                Text("Round \(v3SwipeRound)/5  ✓\(v3SwipeScore)").font(.subheadline).foregroundColor(.secondary)
            }
            .padding(16)
            .neumorphicCard(radius: 14)
            .padding(.horizontal)

            Text(v3Arrows[v3SwipeDir] ?? "").font(.system(size: 90))
                .foregroundColor(Color(.label))
                .padding(40)
                .neumorphicCard(radius: 20)
                .gesture(DragGesture(minimumDistance: 30).onEnded { val in
                    let h = val.translation.width, v = val.translation.height
                    var dir = "up"
                    if abs(h) > abs(v) { dir = h > 0 ? "right" : "left" }
                    else { dir = v > 0 ? "down" : "up" }
                    v3CheckSwipe(dir)
                })

            if !v3SwipeFeedback.isEmpty {
                Text(v3SwipeFeedback).font(.title2.bold())
                    .foregroundColor(v3SwipeFeedback == "Correct!" ? .green : .red)
            }
        }
        .padding()
    }

    // MARK: Stage 5
    var v3Stage5View: some View {
        VStack(spacing: 28) {
            Text("STAGE 5: REACT!").font(.headline).foregroundColor(Color(.label))
                .padding(16)
                .neumorphicCard(radius: 14)
                .padding(.horizontal)

            Text("Tap green ASAP").font(.subheadline).foregroundColor(.secondary)

            if v3ReactDone {
                VStack(spacing: 8) {
                    Text("\(v3ReactMS)ms").font(.system(size: 52, weight: .bold)).foregroundColor(.green)
                    Text("Reaction Time").font(.caption).foregroundColor(.secondary)
                }
                .padding(28)
                .neumorphicCard(radius: 16)

                Button(action: { v3Finish() }) {
                    Text("See Results").font(.headline).foregroundColor(Color(.label))
                        .padding(.horizontal, 36).padding(.vertical, 14)
                        .neumorphicCard(radius: 30)
                }
            } else if v3ReactVisible {
                Circle().fill(Color.green)
                    .frame(width: 130, height: 130)
                    .shadow(color: .green.opacity(0.4), radius: 16)
                    .onTapGesture { v3FinishReact() }
            } else {
                Circle().fill(Color(.systemGray5))
                    .frame(width: 130, height: 130)
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.8), radius: 8, x: -4, y: -4)
                Text(v3ReactReady ? "Waiting..." : "Get ready...").foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: Results
    var v3ResultsView: some View {
        VStack(spacing: 20) {
            Text("GAUNTLET COMPLETE").font(.largeTitle.bold()).foregroundColor(Color(.label))
            VStack(alignment: .leading, spacing: 10) {
                Text("Stage 1 (Targets): \(v3Stage1Score * 20) pts").foregroundColor(Color(.label))
                Text("Stage 2 (Math): \(v3MathResult.contains("Correct") ? 50 : 0) pts").foregroundColor(Color(.label))
                Text("Stage 3 (Simon): \(v3SimonScore * 80) pts").foregroundColor(Color(.label))
                Text("Stage 4 (Swipe): \(v3SwipeScore * 20) pts").foregroundColor(Color(.label))
                Text("Stage 5 (React): \(v3ReactMS > 0 ? max(0, 1000 - v3ReactMS) : 0) pts").foregroundColor(Color(.label))
                Divider()
                Text("TOTAL: \(totalScore)").font(.headline).foregroundColor(.orange)
            }
            .font(.subheadline).padding(20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)

            Button(action: { v3Reset() }) {
                Text("Play Again").font(.headline).foregroundColor(Color(.label))
                    .padding(.horizontal, 44).padding(.vertical, 14)
                    .neumorphicCard(radius: 30)
            }
        }
        .padding()
    }

    // MARK: - Stage 1 Logic
    func v3StartStage1() {
        phase = .stage1
        v3Stage1Score = 0
        v3Targets = []
        rng = FnGtLCG(seed: seedInt)
        for _ in 0..<5 {
            let x = 40 + rng.nextDouble() * 280
            let y = 80 + rng.nextDouble() * 420
            v3Targets.append(FnGtV3Target(position: CGPoint(x: x, y: y)))
        }
        for i in v3Targets.indices {
            let delay = Double(i) * 0.35
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 2.0)) { v3Targets[i].opacity = 0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            phase = .stage2; v3StartStage2()
        }
    }

    func v3TapTarget(_ id: UUID) {
        guard let idx = v3Targets.firstIndex(where: { $0.id == id }), !v3Targets[idx].tapped, v3Targets[idx].opacity > 0 else { return }
        v3Targets[idx].tapped = true; v3Targets[idx].opacity = 0; v3Stage1Score += 1
    }

    // MARK: - Stage 2 Logic
    func v3StartStage2() {
        let a = 2 + rng.nextInt(11), b = 2 + rng.nextInt(11)
        let ans = a * b
        var choices = [ans]
        var attempts = 0
        while choices.count < 4 && attempts < 40 {
            attempts += 1
            let offset = rng.nextInt(21) - 10
            let c = ans + offset
            if c != ans && !choices.contains(c) && c > 0 { choices.append(c) }
        }
        while choices.count < 4 { choices.append(ans + choices.count * 7) }
        v3MathQ = "\(a) × \(b) = ?"; v3MathAnswer = ans
        v3MathChoices = v3Shuffle(choices)
        v3MathResult = ""; v3TimeLeft = 10
        v3MathTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            v3TimeLeft -= 0.5
            if v3TimeLeft <= 0 {
                v3MathTimer?.invalidate()
                v3MathResult = "Time's up!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; v3StartStage3() }
            }
        }
    }

    func v3Shuffle(_ arr: [Int]) -> [Int] {
        var a = arr
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            a.swapAt(i, j)
        }
        return a
    }

    func v3AnswerMath(_ c: Int) {
        v3MathTimer?.invalidate()
        v3MathResult = c == v3MathAnswer ? "Correct! +50" : "Wrong!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; v3StartStage3() }
    }

    // MARK: - Stage 3 Logic
    func v3StartStage3() {
        v3Simon = (0..<4).map { _ in rng.nextInt(4) }
        v3SimonInput = []; v3Lives = 2; v3SimonMode = "watch"; v3SimonScore = 0
        v3PlaySimon()
    }

    func v3PlaySimon() {
        for (i, val) in v3Simon.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7 + 0.3) {
                v3Flashing = val
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { v3Flashing = nil }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(v3Simon.count) * 0.7 + 0.6) {
            v3SimonMode = "input"
        }
    }

    func v3SimonTap(_ idx: Int) {
        v3SimonInput.append(idx)
        let pos = v3SimonInput.count - 1
        if v3SimonInput[pos] != v3Simon[pos] {
            v3Lives -= 1; v3SimonInput = []
            if v3Lives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; v3StartStage4() }
            } else {
                v3SimonMode = "watch"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { v3PlaySimon() }
            }
        } else if v3SimonInput.count == v3Simon.count {
            v3SimonScore = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; v3StartStage4() }
        }
    }

    // MARK: - Stage 4 Logic
    func v3StartStage4() { v3SwipeRound = 0; v3SwipeScore = 0; v3NextSwipe() }

    func v3NextSwipe() {
        v3SwipeFeedback = ""
        v3SwipeDir = v3Dirs[rng.nextInt(4)]
        v3SwipeRound += 1
    }

    func v3CheckSwipe(_ dir: String) {
        let correct = dir == v3SwipeDir
        v3SwipeFeedback = correct ? "Correct!" : "Wrong!"
        if correct { v3SwipeScore += 1 }
        if v3SwipeRound >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = .stage5; v3StartStage5() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { v3NextSwipe() }
        }
    }

    // MARK: - Stage 5 Logic
    func v3StartStage5() {
        v3ReactVisible = false; v3ReactReady = false; v3ReactDone = false; v3ReactMS = 0
        let delay = 1.5 + rng.nextDouble() * 2.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { v3ReactReady = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            v3ReactVisible = true; v3ReactStart = Date()
        }
    }

    func v3FinishReact() {
        guard v3ReactVisible, !v3ReactDone else { return }
        v3ReactMS = Int(Date().timeIntervalSince(v3ReactStart) * 1000)
        v3ReactVisible = false; v3ReactDone = true
    }

    func v3Finish() {
        let mathPts = v3MathResult.contains("Correct") ? 50 : 0
        let reactPts = v3ReactMS > 0 ? max(0, 1000 - v3ReactMS) : 0
        totalScore = v3Stage1Score * 20 + mathPts + v3SimonScore * 80 + v3SwipeScore * 20 + reactPts
        phase = .results
    }

    func v3Reset() {
        seedInt += 1
        v3Stage1Score = 0; v3MathResult = ""; v3SimonScore = 0; v3SwipeScore = 0; v3ReactMS = 0; totalScore = 0
        phase = .start
    }
}

#Preview { FinalGauntletViewV3() }

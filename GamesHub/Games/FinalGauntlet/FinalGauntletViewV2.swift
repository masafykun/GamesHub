import SwiftUI

// MARK: - Models V2

enum FnGtV2Phase { case start, stage1, stage2, stage3, stage4, stage5, results }

struct FnGtV2Target: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var tapped: Bool = false
}

// MARK: - Main View V2 (Glassmorphism + Adaptive Difficulty)

struct FinalGauntletViewV2: View {
    @State private var phase: FnGtV2Phase = .start
    @State private var totalScore: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    // Stage 1
    @State private var v2Targets: [FnGtV2Target] = []
    @State private var v2Stage1Score: Int = 0

    // Stage 2
    @State private var v2MathQ: String = ""
    @State private var v2MathAnswer: Int = 0
    @State private var v2MathChoices: [Int] = []
    @State private var v2TimeLeft: Double = 10
    @State private var v2MathTimer: Timer?
    @State private var v2MathResult: String = ""

    // Stage 3
    @State private var v2Simon: [Int] = []
    @State private var v2Flashing: Int? = nil
    @State private var v2SimonInput: [Int] = []
    @State private var v2Lives: Int = 2
    @State private var v2SimonMode: String = "watch"
    @State private var v2SimonScore: Int = 0

    // Stage 4
    @State private var v2SwipeDir: String = ""
    @State private var v2SwipeRound: Int = 0
    @State private var v2SwipeScore: Int = 0
    @State private var v2SwipeFeedback: String = ""
    let v2Dirs = ["up", "down", "left", "right"]
    let v2Arrows = ["up": "↑", "down": "↓", "left": "←", "right": "→"]

    // Stage 5
    @State private var v2ReactVisible: Bool = false
    @State private var v2ReactStart: Date = Date()
    @State private var v2ReactMS: Int = 0
    @State private var v2ReactDone: Bool = false
    @State private var v2ReactReady: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: v2StartView
            case .stage1: v2Stage1View
            case .stage2: v2Stage2View
            case .stage3: v2Stage3View
            case .stage4: v2Stage4View
            case .stage5: v2Stage5View
            case .results: v2ResultsView
            }
        }
        .foregroundColor(.white)
    }

    func glassCard<V: View>(@ViewBuilder content: () -> V) -> some View {
        content()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    func recordResult(_ success: Bool) {
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5, recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.5)
        }
    }

    // MARK: Start
    var v2StartView: some View {
        VStack(spacing: 28) {
            Text("FINAL GAUNTLET").font(.largeTitle.bold())
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
            glassCard {
                VStack(spacing: 8) {
                    Text("5 Challenges").font(.headline)
                    Text("Adaptive difficulty scales to your skill").font(.caption).foregroundColor(.white.opacity(0.7))
                }.padding(20)
            }
            Button("BEGIN") { v2StartStage1() }
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(Capsule().stroke(.cyan.opacity(0.6), lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: Stage 1
    var v2Stage1View: some View {
        VStack(spacing: 12) {
            glassCard {
                HStack {
                    Text("STAGE 1: TAP TARGETS").font(.headline)
                    Spacer()
                    Text("\(v2Stage1Score)/5").font(.title3.bold()).foregroundColor(.cyan)
                }.padding(16)
            }
            .padding(.horizontal)
            GeometryReader { geo in
                ZStack {
                    ForEach(v2Targets) { t in
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 56)
                            .opacity(t.opacity)
                            .position(t.position)
                            .onTapGesture { v2TapTarget(t.id) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Stage 2
    var v2Stage2View: some View {
        VStack(spacing: 20) {
            glassCard {
                VStack(spacing: 6) {
                    Text("STAGE 2: MATH").font(.headline)
                    Text("Time: \(Int(v2TimeLeft))s").font(.subheadline)
                        .foregroundColor(v2TimeLeft < 4 ? .red : .white.opacity(0.8))
                }.padding(16)
            }
            glassCard {
                Text(v2MathQ).font(.system(size: 44, weight: .bold)).padding(20)
            }
            if v2MathResult.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(v2MathChoices, id: \.self) { c in
                        Button("\(c)") { v2AnswerMath(c) }
                            .frame(maxWidth: .infinity).padding(.vertical, 16)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                            .font(.title3.bold())
                    }
                }
                .padding(.horizontal)
            } else {
                glassCard {
                    Text(v2MathResult).font(.title2.bold())
                        .foregroundColor(v2MathResult.contains("Correct") ? .green : .red)
                        .padding(20)
                }
            }
        }
        .padding()
    }

    // MARK: Stage 3
    var v2Stage3View: some View {
        VStack(spacing: 16) {
            glassCard {
                HStack {
                    Text("STAGE 3: SIMON").font(.headline)
                    Spacer()
                    Text(String(repeating: "♥", count: v2Lives)).foregroundColor(.red)
                }.padding(16)
            }
            .padding(.horizontal)
            Text(v2SimonMode == "watch" ? "Watch carefully..." : "Your turn!").font(.subheadline).foregroundColor(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    let cols: [Color] = [.red, .green, .blue, .yellow]
                    RoundedRectangle(cornerRadius: 14)
                        .fill(v2Flashing == i ? cols[i] : cols[i].opacity(0.25))
                        .frame(height: 110)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1))
                        .onTapGesture { if v2SimonMode == "input" { v2SimonTap(i) } }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Stage 4
    var v2Stage4View: some View {
        VStack(spacing: 24) {
            glassCard {
                HStack {
                    Text("STAGE 4: SWIPE").font(.headline)
                    Spacer()
                    Text("\(v2SwipeRound)/5  ✓\(v2SwipeScore)").font(.subheadline)
                }.padding(16)
            }
            .padding(.horizontal)
            glassCard {
                Text(v2Arrows[v2SwipeDir] ?? "").font(.system(size: 90))
                    .padding(36)
            }
            .gesture(DragGesture(minimumDistance: 30).onEnded { val in
                let h = val.translation.width, v = val.translation.height
                var dir = "up"
                if abs(h) > abs(v) { dir = h > 0 ? "right" : "left" }
                else { dir = v > 0 ? "down" : "up" }
                v2CheckSwipe(dir)
            })
            if !v2SwipeFeedback.isEmpty {
                Text(v2SwipeFeedback).font(.title2.bold())
                    .foregroundColor(v2SwipeFeedback == "Correct!" ? .green : .red)
            }
        }
        .padding()
    }

    // MARK: Stage 5
    var v2Stage5View: some View {
        VStack(spacing: 28) {
            glassCard {
                Text("STAGE 5: REACT!").font(.headline).padding(16)
            }
            .padding(.horizontal)
            Text("Tap the circle instantly").font(.subheadline).foregroundColor(.white.opacity(0.7))
            if v2ReactDone {
                glassCard {
                    VStack(spacing: 8) {
                        Text("\(v2ReactMS)ms").font(.system(size: 52, weight: .bold)).foregroundColor(.green)
                        Text("Reaction Time").font(.caption).foregroundColor(.white.opacity(0.6))
                    }.padding(24)
                }
                Button("See Results") { v2Finish() }
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .overlay(Capsule().stroke(.cyan.opacity(0.6), lineWidth: 1.5))
                    .clipShape(Capsule())
            } else if v2ReactVisible {
                Circle().fill(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                    .frame(width: 130, height: 130).shadow(color: .green.opacity(0.5), radius: 20)
                    .onTapGesture { v2FinishReact() }
            } else {
                Circle().fill(.white.opacity(0.08)).frame(width: 130, height: 130)
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                Text(v2ReactReady ? "Waiting..." : "Get ready...").foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
    }

    // MARK: Results
    var v2ResultsView: some View {
        VStack(spacing: 20) {
            Text("GAUNTLET COMPLETE").font(.largeTitle.bold())
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
            glassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stage 1: \(v2Stage1Score) × 20 = \(v2Stage1Score * 20) pts")
                    Text("Stage 2: \(v2MathResult.contains("Correct") ? "50" : "0") pts")
                    Text("Stage 3: \(v2SimonScore == 1 ? "80" : "0") pts")
                    Text("Stage 4: \(v2SwipeScore) × 20 = \(v2SwipeScore * 20) pts")
                    Text("Stage 5: \(v2ReactMS > 0 ? max(0, 1000 - v2ReactMS) : 0) pts")
                    Divider().background(.white.opacity(0.3))
                    Text("TOTAL: \(totalScore)").font(.headline).foregroundColor(.yellow)
                }
                .font(.subheadline).padding(20)
            }
            .padding(.horizontal)
            if difficultyMultiplier > 1.01 {
                Text("Difficulty: \(String(format: "%.1f", difficultyMultiplier))x").font(.caption).foregroundColor(.cyan)
            }
            Button("Play Again") { v2Reset() }
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(Capsule().stroke(.orange.opacity(0.6), lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Stage 1 Logic
    func v2StartStage1() {
        phase = .stage1; v2Stage1Score = 0; v2Targets = []
        for _ in 0..<5 {
            let x = CGFloat.random(in: 40...320), y = CGFloat.random(in: 80...500)
            v2Targets.append(FnGtV2Target(position: CGPoint(x: x, y: y)))
        }
        for i in v2Targets.indices {
            let fadeIn = Double(i) * 0.3
            let dur = 2.0 / difficultyMultiplier
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeIn) {
                withAnimation(.linear(duration: dur)) { v2Targets[i].opacity = 0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 / difficultyMultiplier) {
            recordResult(v2Stage1Score >= 3)
            phase = .stage2; v2StartStage2()
        }
    }

    func v2TapTarget(_ id: UUID) {
        guard let idx = v2Targets.firstIndex(where: { $0.id == id }), !v2Targets[idx].tapped, v2Targets[idx].opacity > 0 else { return }
        v2Targets[idx].tapped = true; v2Targets[idx].opacity = 0; v2Stage1Score += 1
    }

    // MARK: - Stage 2 Logic
    func v2StartStage2() {
        let range = Int(12 * difficultyMultiplier)
        let a = Int.random(in: 2...max(12, range)), b = Int.random(in: 2...max(12, range))
        let ans = a * b
        var choices = [ans]
        while choices.count < 4 {
            let c = ans + Int.random(in: -15...15)
            if c != ans && !choices.contains(c) && c > 0 { choices.append(c) }
        }
        v2MathQ = "\(a) × \(b) = ?"
        v2MathAnswer = ans
        v2MathChoices = choices.shuffled()
        v2MathResult = ""
        v2TimeLeft = 10.0 / difficultyMultiplier
        v2MathTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            v2TimeLeft -= 0.5
            if v2TimeLeft <= 0 {
                v2MathTimer?.invalidate()
                v2MathResult = "Time's up!"
                recordResult(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; v2StartStage3() }
            }
        }
    }

    func v2AnswerMath(_ c: Int) {
        v2MathTimer?.invalidate()
        let correct = c == v2MathAnswer
        v2MathResult = correct ? "Correct! +50" : "Wrong!"
        recordResult(correct)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; v2StartStage3() }
    }

    // MARK: - Stage 3 Logic
    func v2StartStage3() {
        v2Simon = (0..<4).map { _ in Int.random(in: 0..<4) }
        v2SimonInput = []; v2Lives = 2; v2SimonMode = "watch"; v2SimonScore = 0
        v2PlaySimon()
    }

    func v2PlaySimon() {
        let speed = 0.7 / difficultyMultiplier
        for (i, val) in v2Simon.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * speed + 0.3) {
                v2Flashing = val
                DispatchQueue.main.asyncAfter(deadline: .now() + speed * 0.6) { v2Flashing = nil }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(v2Simon.count) * speed + 0.6) {
            v2SimonMode = "input"
        }
    }

    func v2SimonTap(_ idx: Int) {
        v2SimonInput.append(idx)
        let pos = v2SimonInput.count - 1
        if v2SimonInput[pos] != v2Simon[pos] {
            v2Lives -= 1; v2SimonInput = []
            if v2Lives <= 0 {
                recordResult(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; v2StartStage4() }
            } else {
                v2SimonMode = "watch"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { v2PlaySimon() }
            }
        } else if v2SimonInput.count == v2Simon.count {
            v2SimonScore = 1; recordResult(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; v2StartStage4() }
        }
    }

    // MARK: - Stage 4 Logic
    func v2StartStage4() { v2SwipeRound = 0; v2SwipeScore = 0; v2NextSwipe() }

    func v2NextSwipe() { v2SwipeFeedback = ""; v2SwipeDir = v2Dirs.randomElement()!; v2SwipeRound += 1 }

    func v2CheckSwipe(_ dir: String) {
        let correct = dir == v2SwipeDir
        v2SwipeFeedback = correct ? "Correct!" : "Wrong!"
        if correct { v2SwipeScore += 1 }
        recordResult(correct)
        if v2SwipeRound >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = .stage5; v2StartStage5() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 / difficultyMultiplier) { v2NextSwipe() }
        }
    }

    // MARK: - Stage 5 Logic
    func v2StartStage5() {
        v2ReactVisible = false; v2ReactReady = false; v2ReactDone = false; v2ReactMS = 0
        let delay = max(1.0, 3.0 / difficultyMultiplier)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { v2ReactReady = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            v2ReactVisible = true; v2ReactStart = Date()
        }
    }

    func v2FinishReact() {
        guard v2ReactVisible, !v2ReactDone else { return }
        v2ReactMS = Int(Date().timeIntervalSince(v2ReactStart) * 1000)
        v2ReactVisible = false; v2ReactDone = true
        recordResult(v2ReactMS < 400)
    }

    func v2Finish() {
        let mathPts = v2MathResult.contains("Correct") ? 50 : 0
        let reactPts = v2ReactMS > 0 ? max(0, 1000 - v2ReactMS) : 0
        totalScore = v2Stage1Score * 20 + mathPts + v2SimonScore * 80 + v2SwipeScore * 20 + reactPts
        phase = .results
    }

    func v2Reset() {
        v2Stage1Score = 0; v2MathResult = ""; v2SimonScore = 0; v2SwipeScore = 0; v2ReactMS = 0; totalScore = 0
        recentResults = []; difficultyMultiplier = 1.0; phase = .start
    }
}

#Preview { FinalGauntletViewV2() }

import SwiftUI

// MARK: - Models 

enum FinalGauntletPhase { case start, stage1, stage2, stage3, stage4, stage5, results }

struct FinalGauntletTarget: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var tapped: Bool = false
}

// MARK: - Main View  (Glassmorphism + Adaptive Difficulty)

struct FinalGauntletView: View {
    @State private var phase: FinalGauntletPhase = .start
    @State private var totalScore: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    // Stage 1
    @State private var targets: [FinalGauntletTarget] = []
    @State private var stage1Score: Int = 0

    // Stage 2
    @State private var mathQ: String = ""
    @State private var mathAnswer: Int = 0
    @State private var mathChoices: [Int] = []
    @State private var timeLeftGauntletLeft: Double = 10
    @State private var mathTimer: Timer?
    @State private var mathResult: String = ""

    // Stage 3
    @State private var simon: [Int] = []
    @State private var flashing: Int? = nil
    @State private var simonInput: [Int] = []
    @State private var livesGauntlet: Int = 2
    @State private var simonMode: String = "watch"
    @State private var simonScore: Int = 0

    // Stage 4
    @State private var swipeDir: String = ""
    @State private var swipeRound: Int = 0
    @State private var swipeScore: Int = 0
    @State private var swipeFeedback: String = ""
    let dirs = ["up", "down", "left", "right"]
    let arrows = ["up": "↑", "down": "↓", "left": "←", "right": "→"]

    // Stage 5
    @State private var reactVisible: Bool = false
    @State private var reactStart: Date = Date()
    @State private var reactMS: Int = 0
    @State private var reactDone: Bool = false
    @State private var reactReady: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25), Color(red: 0.15, green: 0.05, blue: 0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startView
            case .stage1: stage1View
            case .stage2: stage2View
            case .stage3: stage3View
            case .stage4: stage4View
            case .stage5: stage5View
            case .results: resultsView
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
    var startView: some View {
        VStack(spacing: 28) {
            Text("FINAL GAUNTLET").font(.largeTitle.bold())
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
            glassCard {
                VStack(spacing: 8) {
                    Text("5 Challenges").font(.headline)
                    Text("Adaptive difficulty scales to your skill").font(.caption).foregroundColor(.white.opacity(0.7))
                }.padding(20)
            }
            Button("BEGIN") { startStage1() }
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(Capsule().stroke(.cyan.opacity(0.6), lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: Stage 1
    var stage1View: some View {
        VStack(spacing: 12) {
            glassCard {
                HStack {
                    Text("STAGE 1: TAP TARGETS").font(.headline)
                    Spacer()
                    Text("\(stage1Score)/5").font(.title3.bold()).foregroundColor(.cyan)
                }.padding(16)
            }
            .padding(.horizontal)
            GeometryReader { geo in
                ZStack {
                    ForEach(targets) { t in
                        Circle()
                            .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 56, height: 56)
                            .opacity(t.opacity)
                            .position(t.position)
                            .onTapGesture { tapGauntletTarget(t.id) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Stage 2
    var stage2View: some View {
        VStack(spacing: 20) {
            glassCard {
                VStack(spacing: 6) {
                    Text("STAGE 2: MATH").font(.headline)
                    Text("Time: \(Int(timeLeftGauntletLeft))s").font(.subheadline)
                        .foregroundColor(timeLeftGauntletLeft < 4 ? .red : .white.opacity(0.8))
                }.padding(16)
            }
            glassCard {
                Text(mathQ).font(.system(size: 44, weight: .bold)).padding(20)
            }
            if mathResult.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(mathChoices, id: \.self) { c in
                        Button("\(c)") { answerMath(c) }
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
                    Text(mathResult).font(.title2.bold())
                        .foregroundColor(mathResult.contains("Correct") ? .green : .red)
                        .padding(20)
                }
            }
        }
        .padding()
    }

    // MARK: Stage 3
    var stage3View: some View {
        VStack(spacing: 16) {
            glassCard {
                HStack {
                    Text("STAGE 3: SIMON").font(.headline)
                    Spacer()
                    Text(String(repeating: "♥", count: livesGauntlet)).foregroundColor(.red)
                }.padding(16)
            }
            .padding(.horizontal)
            Text(simonMode == "watch" ? "Watch carefully..." : "Your turn!").font(.subheadline).foregroundColor(.white.opacity(0.7))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    let cols: [Color] = [.red, .green, .blue, .yellow]
                    RoundedRectangle(cornerRadius: 14)
                        .fill(flashing == i ? cols[i] : cols[i].opacity(0.25))
                        .frame(height: 110)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1))
                        .onTapGesture { if simonMode == "input" { simonTap(i) } }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: Stage 4
    var stage4View: some View {
        VStack(spacing: 24) {
            glassCard {
                HStack {
                    Text("STAGE 4: SWIPE").font(.headline)
                    Spacer()
                    Text("\(swipeRound)/5  ✓\(swipeScore)").font(.subheadline)
                }.padding(16)
            }
            .padding(.horizontal)
            glassCard {
                Text(arrows[swipeDir] ?? "").font(.system(size: 90))
                    .padding(36)
            }
            .gesture(DragGesture(minimumDistance: 30).onEnded { val in
                let h = val.translation.width, v = val.translation.height
                var dir = "up"
                if abs(h) > abs(v) { dir = h > 0 ? "right" : "left" }
                else { dir = v > 0 ? "down" : "up" }
                checkSwipe(dir)
            })
            if !swipeFeedback.isEmpty {
                Text(swipeFeedback).font(.title2.bold())
                    .foregroundColor(swipeFeedback == "Correct!" ? .green : .red)
            }
        }
        .padding()
    }

    // MARK: Stage 5
    var stage5View: some View {
        VStack(spacing: 28) {
            glassCard {
                Text("STAGE 5: REACT!").font(.headline).padding(16)
            }
            .padding(.horizontal)
            Text("Tap the circle instantly").font(.subheadline).foregroundColor(.white.opacity(0.7))
            if reactDone {
                glassCard {
                    VStack(spacing: 8) {
                        Text("\(reactMS)ms").font(.system(size: 52, weight: .bold)).foregroundColor(.green)
                        Text("Reaction Time").font(.caption).foregroundColor(.white.opacity(0.6))
                    }.padding(24)
                }
                Button("See Results") { finish() }
                    .padding(.horizontal, 36).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .overlay(Capsule().stroke(.cyan.opacity(0.6), lineWidth: 1.5))
                    .clipShape(Capsule())
            } else if reactVisible {
                Circle().fill(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom))
                    .frame(width: 130, height: 130).shadow(color: .green.opacity(0.5), radius: 20)
                    .onTapGesture { finishReact() }
            } else {
                Circle().fill(.white.opacity(0.08)).frame(width: 130, height: 130)
                    .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                Text(reactReady ? "Waiting..." : "Get ready...").foregroundColor(.white.opacity(0.5))
            }
        }
        .padding()
    }

    // MARK: Results
    var resultsView: some View {
        VStack(spacing: 20) {
            Text("GAUNTLET COMPLETE").font(.largeTitle.bold())
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
            glassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Stage 1: \(stage1Score) × 20 = \(stage1Score * 20) pts")
                    Text("Stage 2: \(mathResult.contains("Correct") ? "50" : "0") pts")
                    Text("Stage 3: \(simonScore == 1 ? "80" : "0") pts")
                    Text("Stage 4: \(swipeScore) × 20 = \(swipeScore * 20) pts")
                    Text("Stage 5: \(reactMS > 0 ? max(0, 1000 - reactMS) : 0) pts")
                    Divider().background(.white.opacity(0.3))
                    Text("TOTAL: \(totalScore)").font(.headline).foregroundColor(.yellow)
                }
                .font(.subheadline).padding(20)
            }
            .padding(.horizontal)
            if difficultyMultiplier > 1.01 {
                Text("Difficulty: \(String(format: "%.1f", difficultyMultiplier))x").font(.caption).foregroundColor(.cyan)
            }
            Button("Play Again") { reset() }
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .overlay(Capsule().stroke(.orange.opacity(0.6), lineWidth: 1.5))
                .clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Stage 1 Logic
    func startStage1() {
        phase = .stage1; stage1Score = 0; targets = []
        for _ in 0..<5 {
            let x = CGFloat.random(in: 40...320), y = CGFloat.random(in: 80...500)
            targets.append(FinalGauntletTarget(position: CGPoint(x: x, y: y)))
        }
        for i in targets.indices {
            let fadeIn = Double(i) * 0.3
            let dur = 2.0 / difficultyMultiplier
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeIn) {
                withAnimation(.linear(duration: dur)) { targets[i].opacity = 0 }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5 / difficultyMultiplier) {
            recordResult(stage1Score >= 3)
            phase = .stage2; startStage2()
        }
    }

    func tapGauntletTarget(_ id: UUID) {
        guard let idx = targets.firstIndex(where: { $0.id == id }), !targets[idx].tapped, targets[idx].opacity > 0 else { return }
        targets[idx].tapped = true; targets[idx].opacity = 0; stage1Score += 1
    }

    // MARK: - Stage 2 Logic
    func startStage2() {
        let range = Int(12 * difficultyMultiplier)
        let a = Int.random(in: 2...max(12, range)), b = Int.random(in: 2...max(12, range))
        let ans = a * b
        var choices = [ans]
        while choices.count < 4 {
            let c = ans + Int.random(in: -15...15)
            if c != ans && !choices.contains(c) && c > 0 { choices.append(c) }
        }
        mathQ = "\(a) × \(b) = ?"
        mathAnswer = ans
        mathChoices = choices.shuffled()
        mathResult = ""
        timeLeftGauntletLeft = 10.0 / difficultyMultiplier
        mathTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            timeLeftGauntletLeft -= 0.5
            if timeLeftGauntletLeft <= 0 {
                mathTimer?.invalidate()
                mathResult = "Time's up!"
                recordResult(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; startStage3() }
            }
        }
    }

    func answerMath(_ c: Int) {
        mathTimer?.invalidate()
        let correct = c == mathAnswer
        mathResult = correct ? "Correct! +50" : "Wrong!"
        recordResult(correct)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; startStage3() }
    }

    // MARK: - Stage 3 Logic
    func startStage3() {
        simon = (0..<4).map { _ in Int.random(in: 0..<4) }
        simonInput = []; livesGauntlet = 2; simonMode = "watch"; simonScore = 0
        playSimon()
    }

    func playSimon() {
        let speed = 0.7 / difficultyMultiplier
        for (i, val) in simon.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * speed + 0.3) {
                flashing = val
                DispatchQueue.main.asyncAfter(deadline: .now() + speed * 0.6) { flashing = nil }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(simon.count) * speed + 0.6) {
            simonMode = "input"
        }
    }

    func simonTap(_ idx: Int) {
        simonInput.append(idx)
        let pos = simonInput.count - 1
        if simonInput[pos] != simon[pos] {
            livesGauntlet -= 1; simonInput = []
            if livesGauntlet <= 0 {
                recordResult(false)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; startStage4() }
            } else {
                simonMode = "watch"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playSimon() }
            }
        } else if simonInput.count == simon.count {
            simonScore = 1; recordResult(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; startStage4() }
        }
    }

    // MARK: - Stage 4 Logic
    func startStage4() { swipeRound = 0; swipeScore = 0; nextSwipe() }

    func nextSwipe() { swipeFeedback = ""; swipeDir = dirs.randomElement()!; swipeRound += 1 }

    func checkSwipe(_ dir: String) {
        let correct = dir == swipeDir
        swipeFeedback = correct ? "Correct!" : "Wrong!"
        if correct { swipeScore += 1 }
        recordResult(correct)
        if swipeRound >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = .stage5; startStage5() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 / difficultyMultiplier) { nextSwipe() }
        }
    }

    // MARK: - Stage 5 Logic
    func startStage5() {
        reactVisible = false; reactReady = false; reactDone = false; reactMS = 0
        let delay = max(1.0, 3.0 / difficultyMultiplier)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { reactReady = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            reactVisible = true; reactStart = Date()
        }
    }

    func finishReact() {
        guard reactVisible, !reactDone else { return }
        reactMS = Int(Date().timeIntervalSince(reactStart) * 1000)
        reactVisible = false; reactDone = true
        recordResult(reactMS < 400)
    }

    func finish() {
        let mathPts = mathResult.contains("Correct") ? 50 : 0
        let reactPts = reactMS > 0 ? max(0, 1000 - reactMS) : 0
        totalScore = stage1Score * 20 + mathPts + simonScore * 80 + swipeScore * 20 + reactPts
        phase = .results
    }

    func reset() {
        stage1Score = 0; mathResult = ""; simonScore = 0; swipeScore = 0; reactMS = 0; totalScore = 0
        recentResults = []; difficultyMultiplier = 1.0; phase = .start
    }
}

#Preview { FinalGauntletView() }

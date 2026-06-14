import SwiftUI

// MARK: - Models

enum FnGtPhase { case start, stage1, stage2, stage3, stage4, stage5, results }

struct FnGtTarget: Identifiable {
    let id = UUID()
    var position: CGPoint
    var opacity: Double = 1.0
    var tapped: Bool = false
}

struct FnGtMathQuestion {
    let question: String
    let choices: [Int]
    let answer: Int
}

// MARK: - Main View

struct FinalGauntletView: View {
    @State private var phase: FnGtPhase = .start
    @State private var totalScore: Int = 0

    // Stage 1
    @State private var targets: [FnGtTarget] = []
    @State private var stage1Score: Int = 0
    @State private var stage1Timer: Timer?

    // Stage 2
    @State private var mathQuestion: FnGtMathQuestion = FnGtMathQuestion(question: "", choices: [], answer: 0)
    @State private var stage2TimeLeft: Double = 10
    @State private var stage2Timer: Timer?
    @State private var stage2Result: String = ""

    // Stage 3
    @State private var simonSequence: [Int] = []
    @State private var simonFlashing: Int? = nil
    @State private var simonPlayerInput: [Int] = []
    @State private var simonLives: Int = 2
    @State private var simonPhase: String = "watch"
    @State private var simonScore: Int = 0

    // Stage 4
    @State private var swipeArrow: String = ""
    @State private var swipeRound: Int = 0
    @State private var swipeScore: Int = 0
    @State private var swipeResult: String = ""

    // Stage 5
    @State private var reactVisible: Bool = false
    @State private var reactStartTime: Date = Date()
    @State private var reactMS: Int = 0
    @State private var reactReady: Bool = false
    @State private var reactDone: Bool = false

    let directions = ["up", "down", "left", "right"]
    let dirArrows = ["up": "↑", "down": "↓", "left": "←", "right": "→"]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
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

    // MARK: Start
    var startView: some View {
        VStack(spacing: 24) {
            Text("FINAL GAUNTLET").font(.largeTitle.bold()).foregroundColor(.orange)
            Text("5 challenges. One shot.").font(.headline).foregroundColor(.gray)
            Button("BEGIN") { startStage1() }
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.orange).foregroundColor(.black)
                .clipShape(Capsule())
        }
    }

    // MARK: Stage 1
    var stage1View: some View {
        VStack {
            Text("STAGE 1: TAP THE TARGETS").font(.headline).padding()
            Text("Score: \(stage1Score)").font(.title3)
            GeometryReader { geo in
                ZStack {
                    ForEach(targets) { t in
                        Circle().fill(Color.orange).frame(width: 52, height: 52)
                            .opacity(t.opacity)
                            .position(t.position)
                            .onTapGesture { tapTarget(t.id) }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: Stage 2
    var stage2View: some View {
        VStack(spacing: 20) {
            Text("STAGE 2: MATH").font(.headline)
            Text("Time: \(Int(stage2TimeLeft))s").foregroundColor(stage2TimeLeft < 4 ? .red : .white)
            Text(mathQuestion.question).font(.largeTitle.bold()).padding()
            if stage2Result.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(mathQuestion.choices, id: \.self) { c in
                        Button("\(c)") { answerMath(c) }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue.opacity(0.7)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            } else {
                Text(stage2Result).font(.title2.bold()).foregroundColor(stage2Result.contains("Correct") ? .green : .red)
            }
        }
    }

    // MARK: Stage 3
    var stage3View: some View {
        VStack(spacing: 16) {
            Text("STAGE 3: SIMON").font(.headline)
            Text(simonPhase == "watch" ? "Watch the sequence" : "Repeat it!").font(.subheadline).foregroundColor(.gray)
            Text("Lives: \(String(repeating: "♥", count: simonLives))").foregroundColor(.red)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    let colors: [Color] = [.red, .green, .blue, .yellow]
                    RoundedRectangle(cornerRadius: 12)
                        .fill(simonFlashing == i ? colors[i] : colors[i].opacity(0.3))
                        .frame(height: 100)
                        .onTapGesture { if simonPhase == "input" { simonTap(i) } }
                }
            }
            .padding(.horizontal)
            Text("Input: \(simonPlayerInput.count)/\(simonSequence.count)").font(.caption).foregroundColor(.gray)
        }
    }

    // MARK: Stage 4
    var stage4View: some View {
        VStack(spacing: 24) {
            Text("STAGE 4: SWIPE").font(.headline)
            Text("Round \(swipeRound)/5  Score: \(swipeScore)").font(.subheadline)
            Text(dirArrows[swipeArrow] ?? "").font(.system(size: 100))
                .padding(40)
                .background(Color.purple.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .gesture(DragGesture(minimumDistance: 30).onEnded { val in
                    let h = val.translation.width
                    let v = val.translation.height
                    var dir = "up"
                    if abs(h) > abs(v) { dir = h > 0 ? "right" : "left" }
                    else { dir = v > 0 ? "down" : "up" }
                    checkSwipe(dir)
                })
            if !swipeResult.isEmpty {
                Text(swipeResult).font(.title2.bold()).foregroundColor(swipeResult == "Correct!" ? .green : .red)
            }
        }
    }

    // MARK: Stage 5
    var stage5View: some View {
        VStack(spacing: 24) {
            Text("STAGE 5: REACT!").font(.headline)
            Text("Tap the green circle as fast as you can").font(.subheadline).foregroundColor(.gray)
            if reactDone {
                Text("Reaction: \(reactMS)ms").font(.title.bold()).foregroundColor(.green)
            } else if reactVisible {
                Circle().fill(Color.green).frame(width: 120, height: 120)
                    .onTapGesture { finishReact() }
            } else {
                Circle().fill(Color.gray.opacity(0.3)).frame(width: 120, height: 120)
                Text(reactReady ? "Waiting..." : "Get ready...").foregroundColor(.gray)
            }
            if reactDone {
                Button("See Results") { finishGame() }
                    .padding(.horizontal, 30).padding(.vertical, 12)
                    .background(Color.orange).foregroundColor(.black).clipShape(Capsule())
            }
        }
    }

    // MARK: Results
    var resultsView: some View {
        VStack(spacing: 20) {
            Text("GAUNTLET COMPLETE").font(.largeTitle.bold()).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text("Stage 1 (Targets): \(stage1Score)/5").font(.headline)
                Text("Stage 2 (Math): \(stage2Result.contains("Correct") ? 1 : 0)/1").font(.headline)
                Text("Stage 3 (Simon): \(simonScore)/1").font(.headline)
                Text("Stage 4 (Swipe): \(swipeScore)/5").font(.headline)
                Text("Stage 5 (React): \(reactMS > 0 ? max(0, 1000 - reactMS) : 0) pts").font(.headline)
            }
            .padding().background(Color.white.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 12))
            Text("TOTAL: \(totalScore)").font(.largeTitle.bold()).foregroundColor(.yellow)
            Button("Play Again") { resetGame() }
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.orange).foregroundColor(.black).clipShape(Capsule())
        }
        .padding()
    }

    // MARK: - Stage 1 Logic
    func startStage1() {
        phase = .stage1
        stage1Score = 0
        targets = []
        spawnTargets()
    }

    func spawnTargets() {
        for _ in 0..<5 {
            let x = CGFloat.random(in: 40...320)
            let y = CGFloat.random(in: 80...500)
            targets.append(FnGtTarget(position: CGPoint(x: x, y: y)))
        }
        startFadeTimers()
    }

    func startFadeTimers() {
        for i in targets.indices {
            let delay = Double(i) * 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                fadeTarget(targets[i].id)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            phase = .stage2
            startStage2()
        }
    }

    func fadeTarget(_ id: UUID) {
        guard let idx = targets.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.linear(duration: 2)) {
            targets[idx].opacity = 0
        }
    }

    func tapTarget(_ id: UUID) {
        guard let idx = targets.firstIndex(where: { $0.id == id }), !targets[idx].tapped, targets[idx].opacity > 0 else { return }
        targets[idx].tapped = true
        targets[idx].opacity = 0
        stage1Score += 1
    }

    // MARK: - Stage 2 Logic
    func startStage2() {
        let a = Int.random(in: 2...12)
        let b = Int.random(in: 2...12)
        let ans = a * b
        var choices = [ans]
        while choices.count < 4 {
            let c = ans + Int.random(in: -10...10)
            if c != ans && !choices.contains(c) && c > 0 { choices.append(c) }
        }
        mathQuestion = FnGtMathQuestion(question: "\(a) × \(b) = ?", choices: choices.shuffled(), answer: ans)
        stage2Result = ""
        stage2TimeLeft = 10
        stage2Timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            stage2TimeLeft -= 1
            if stage2TimeLeft <= 0 {
                stage2Timer?.invalidate()
                stage2Result = "Time's up!"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; startStage3() }
            }
        }
    }

    func answerMath(_ choice: Int) {
        stage2Timer?.invalidate()
        stage2Result = choice == mathQuestion.answer ? "Correct! +1" : "Wrong!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { phase = .stage3; startStage3() }
    }

    // MARK: - Stage 3 Logic
    func startStage3() {
        simonSequence = (0..<4).map { _ in Int.random(in: 0..<4) }
        simonPlayerInput = []
        simonLives = 2
        simonPhase = "watch"
        simonScore = 0
        playSimonSequence()
    }

    func playSimonSequence() {
        for (i, val) in simonSequence.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.7 + 0.3) {
                simonFlashing = val
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { simonFlashing = nil }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(simonSequence.count) * 0.7 + 0.6) {
            simonPhase = "input"
        }
    }

    func simonTap(_ idx: Int) {
        simonPlayerInput.append(idx)
        let pos = simonPlayerInput.count - 1
        if simonPlayerInput[pos] != simonSequence[pos] {
            simonLives -= 1
            simonPlayerInput = []
            if simonLives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; startStage4() }
            } else {
                simonPhase = "watch"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playSimonSequence() }
            }
        } else if simonPlayerInput.count == simonSequence.count {
            simonScore = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { phase = .stage4; startStage4() }
        }
    }

    // MARK: - Stage 4 Logic
    func startStage4() {
        swipeRound = 0
        swipeScore = 0
        nextSwipeRound()
    }

    func nextSwipeRound() {
        swipeResult = ""
        swipeArrow = directions.randomElement()!
        swipeRound += 1
    }

    func checkSwipe(_ dir: String) {
        swipeResult = dir == swipeArrow ? "Correct!" : "Wrong!"
        if dir == swipeArrow { swipeScore += 1 }
        if swipeRound >= 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { phase = .stage5; startStage5() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { nextSwipeRound() }
        }
    }

    // MARK: - Stage 5 Logic
    func startStage5() {
        reactVisible = false
        reactReady = false
        reactDone = false
        reactMS = 0
        let delay = Double.random(in: 1.5...4.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { reactReady = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            reactVisible = true
            reactStartTime = Date()
        }
    }

    func finishReact() {
        guard reactVisible, !reactDone else { return }
        reactMS = Int(Date().timeIntervalSince(reactStartTime) * 1000)
        reactVisible = false
        reactDone = true
    }

    func finishGame() {
        let mathPts = stage2Result.contains("Correct") ? 1 : 0
        let reactPts = reactMS > 0 ? max(0, 1000 - reactMS) : 0
        totalScore = stage1Score * 20 + mathPts * 50 + simonScore * 80 + swipeScore * 20 + reactPts
        phase = .results
    }

    func resetGame() {
        stage1Score = 0; stage2Result = ""; simonScore = 0; swipeScore = 0; reactMS = 0; totalScore = 0
        phase = .start
    }
}

#Preview { FinalGauntletView() }

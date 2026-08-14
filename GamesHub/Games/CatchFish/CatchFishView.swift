import SwiftUI

enum CatchFishFishType: CaseIterable {
    case small, medium, large, shark, octopus

    var emoji: String {
        switch self {
        case .small: return "🐟"
        case .medium: return "🐠"
        case .large: return "🐡"
        case .shark: return "🦈"
        case .octopus: return "🐙"
        }
    }

    var points: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .large: return 3
        case .shark: return -5
        case .octopus: return 2
        }
    }

    var baseSize: CGFloat {
        switch self {
        case .small: return 34
        case .medium: return 46
        case .large: return 54
        case .shark: return 58
        case .octopus: return 42
        }
    }

    var baseSpeed: CGFloat {
        switch self {
        case .small: return 105
        case .medium: return 78
        case .large: return 58
        case .shark: return 128
        case .octopus: return 68
        }
    }
}

struct CatchFishFish: Identifiable {
    let id = UUID()
    var type: CatchFishFishType
    var x: CGFloat
    var y: CGFloat
    var goingRight: Bool
}

enum CatchFishPhase {
    case start, playing, gameOver
}

struct CatchFishView: View {
    @State private var phase: CatchFishPhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Int = 30
    @State private var fish: [CatchFishFish] = []
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var catchLabel: String = ""
    @State private var showLabel: Bool = false
    @State private var moveTimer: Timer? = nil
    @State private var canvasSize: CGSize = UIScreen.main.bounds.size
    @AppStorage("catchFishBestScore") private var bestScore: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.18, blue: 0.55), Color(red: 0.0, green: 0.55, blue: 0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

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

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("🎣 Catch Fish").font(.largeTitle).bold().foregroundColor(.white)
            Text("Tap fish to score!\nBeware of 🦈 (−5 pts)\nDifficulty adapts to your skill!")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .font(.callout)
            glassButton("Start Game") { startGame() }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over!").font(.largeTitle).bold().foregroundColor(.white)
            Text("Score: \(score)").font(.title).foregroundColor(.cyan)
            Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))")
                .font(.caption).foregroundColor(.white.opacity(0.7))
            glassButton("Play Again") { startGame() }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                Color.clear
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in canvasSize = newSize }

                ForEach(fish) { f in
                    Text(f.type.emoji)
                        .font(.system(size: f.type.baseSize))
                        .scaleEffect(x: f.goingRight ? 1 : -1, y: 1)
                        .position(x: f.x, y: f.y)
                        .onTapGesture {
                            catchFish(f)
                        }
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Score: \(score)").font(.title2).bold().foregroundColor(.white)
                            Text("Difficulty: \(String(format: "%.1fx", difficultyMultiplier))")
                                .font(.caption2).foregroundColor(.white.opacity(0.7))
                        }
                        Spacer()
                        Text("⏱ \(timeLeft)s")
                            .font(.title2).bold()
                            .foregroundColor(timeLeft <= 5 ? .red : .white)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                    .padding()
                    Spacer()
                }

                if showLabel {
                    Text(catchLabel)
                        .font(.title).bold()
                        .foregroundColor(.yellow)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    func glassButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title2).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    func startGame() {
        score = 0
        timeLeft = 30
        fish = []
        difficultyMultiplier = 1.0
        recentResults = []
        phase = .playing
        gameTimer?.invalidate()
        spawnTimer?.invalidate()

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeLeft > 0 {
                timeLeft -= 1
            } else {
                endGame()
            }
        }

        // Fish used to jump a full second's worth of distance at a time.
        moveTimer?.invalidate()
        moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            moveFish()
        }

        let interval = max(0.6, 1.5 / difficultyMultiplier)
        spawnTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            spawnFish()
        }
        spawnFish()
    }

    func endGame() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        moveTimer?.invalidate()
        bestScore = max(bestScore, score)
        phase = .gameOver
    }

    func spawnFish() {
        let screenH = canvasSize.height
        let screenW = canvasSize.width
        let type = CatchFishFishType.allCases.randomElement()!
        let goingRight = Bool.random()
        let startX: CGFloat = goingRight ? -40 : screenW + 40
        let y = CGFloat.random(in: 120...max(200, screenH - 80))
        fish.append(CatchFishFish(type: type, x: startX, y: y, goingRight: goingRight))
        if fish.count > 14 { fish.removeFirst() }
    }

    func moveFish() {
        let screenW = canvasSize.width
        fish = fish.compactMap { f in
            var mf = f
            // baseSpeed was tuned for one step per second; spread it over 30 frames.
            let speed = f.type.baseSpeed * CGFloat(difficultyMultiplier) / 30.0
            let dx = speed * (f.goingRight ? 1 : -1)
            mf.x += dx
            if mf.x < -80 || mf.x > screenW + 80 { return nil }
            return mf
        }
    }

    func catchFish(_ f: CatchFishFish) {
        fish.removeAll { $0.id == f.id }
        let pts = f.type.points
        score += pts
        catchLabel = pts >= 0 ? "+\(pts)" : "\(pts)"
        showLabel = true

        let caught = pts > 0
        recentResults.append(caught)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(3.0, difficultyMultiplier * 1.2)
            recentResults = []
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation { showLabel = false }
        }
    }
}

#Preview { CatchFishView() }

import SwiftUI

enum CtFshFishType: CaseIterable {
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

    var size: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 48
        case .large: return 56
        case .shark: return 60
        case .octopus: return 44
        }
    }

    var speed: CGFloat {
        switch self {
        case .small: return 110
        case .medium: return 80
        case .large: return 60
        case .shark: return 130
        case .octopus: return 70
        }
    }
}

struct CtFshFish: Identifiable {
    let id = UUID()
    var type: CtFshFishType
    var x: CGFloat
    var y: CGFloat
    var goingRight: Bool
}

enum CtFshPhase {
    case start, playing, gameOver
}

struct CatchFishView: View {
    @State private var phase: CtFshPhase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Int = 30
    @State private var fish: [CtFshFish] = []
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var lastCatch: String = ""
    @State private var showCatch: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.25, blue: 0.45).ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("🎣 Catch Fish").font(.largeTitle).bold().foregroundColor(.white)
            Text("Tap fish to catch them!\nAvoid 🦈 (−5 pts)").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.85))
            Button("Start Game") {
                startGame()
            }
            .font(.title2).bold()
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.cyan).foregroundColor(.white)
            .clipShape(Capsule())
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over!").font(.largeTitle).bold().foregroundColor(.white)
            Text("Score: \(score)").font(.title).foregroundColor(.cyan)
            Button("Play Again") {
                startGame()
            }
            .font(.title2).bold()
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.cyan).foregroundColor(.white)
            .clipShape(Capsule())
        }
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(fish) { f in
                    Text(f.type.emoji)
                        .font(.system(size: f.type.size))
                        .scaleEffect(x: f.goingRight ? 1 : -1, y: 1)
                        .position(x: f.x, y: f.y)
                        .onTapGesture {
                            catchFish(f)
                        }
                }

                VStack {
                    HStack {
                        Text("Score: \(score)").font(.title2).bold().foregroundColor(.white)
                        Spacer()
                        Text("⏱ \(timeLeft)s").font(.title2).bold().foregroundColor(timeLeft <= 5 ? .red : .white)
                    }
                    .padding()
                    Spacer()
                }

                if showCatch {
                    Text(lastCatch).font(.title).bold().foregroundColor(.yellow)
                        .transition(.opacity)
                }
            }
        }
    }

    func startGame() {
        score = 0
        timeLeft = 30
        fish = []
        phase = .playing
        gameTimer?.invalidate()
        spawnTimer?.invalidate()

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeLeft > 0 {
                timeLeft -= 1
                moveFish()
            } else {
                endGame()
            }
        }

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            spawnFish()
        }
        spawnFish()
    }

    func endGame() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        phase = .gameOver
    }

    func spawnFish() {
        let screenH = UIScreen.main.bounds.height
        let type = CtFshFishType.allCases.randomElement()!
        let goingRight = Bool.random()
        let startX: CGFloat = goingRight ? -40 : UIScreen.main.bounds.width + 40
        let y = CGFloat.random(in: 120...(screenH - 120))
        fish.append(CtFshFish(type: type, x: startX, y: y, goingRight: goingRight))
        if fish.count > 12 { fish.removeFirst() }
    }

    func moveFish() {
        let screenW = UIScreen.main.bounds.width
        fish = fish.compactMap { f in
            var mf = f
            let dx = f.type.speed * (f.goingRight ? 1 : -1)
            mf.x += dx
            if mf.x < -80 || mf.x > screenW + 80 { return nil }
            return mf
        }
    }

    func catchFish(_ f: CtFshFish) {
        fish.removeAll { $0.id == f.id }
        score += f.type.points
        lastCatch = f.type.points >= 0 ? "+\(f.type.points)" : "\(f.type.points)"
        showCatch = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { showCatch = false }
    }
}

#Preview { CatchFishView() }

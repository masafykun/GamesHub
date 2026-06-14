import SwiftUI

struct CtFshLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum CtFshV3FishType: CaseIterable {
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
        case .small: return 34
        case .medium: return 46
        case .large: return 54
        case .shark: return 58
        case .octopus: return 42
        }
    }

    var speed: CGFloat {
        switch self {
        case .small: return 108
        case .medium: return 80
        case .large: return 60
        case .shark: return 132
        case .octopus: return 70
        }
    }
}

struct CtFshV3Fish: Identifiable {
    let id = UUID()
    var type: CtFshV3FishType
    var x: CGFloat
    var y: CGFloat
    var goingRight: Bool
}

enum CtFshV3Phase {
    case start, playing, gameOver
}

struct CatchFishViewV3: View {
    @State private var phase: CtFshV3Phase = .start
    @State private var score: Int = 0
    @State private var timeLeft: Int = 30
    @State private var fish: [CtFshV3Fish] = []
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var lcg: CtFshLCG = CtFshLCG(seed: 1)
    @State private var catchLabel: String = ""
    @State private var showLabel: Bool = false
    @State private var spawnCounter: Int = 0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

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
            Text("🎣 Catch Fish").font(.largeTitle).bold().foregroundColor(.primary)
            Text("Tap fish to score!\nAvoid 🦈 (−5 pts)")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: { startGame() }) {
                Text("Start Game")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40).padding(.vertical, 14)
            }
            .neumorphicCard(radius: 24)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over!").font(.largeTitle).bold().foregroundColor(.primary)
            Text("Score: \(score)").font(.title).foregroundColor(.accentColor)
            Text("SEED: #\(seedInt - 1)").font(.caption).monospaced().foregroundColor(.gray)
            Button(action: { startGame() }) {
                Text("Play Again")
                    .font(.title2).bold()
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40).padding(.vertical, 14)
            }
            .neumorphicCard(radius: 24)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
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
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Score: \(score)").font(.title2).bold().foregroundColor(.primary)
                            Text("SEED: #\(seedInt)").font(.caption2).monospaced().foregroundColor(.gray)
                        }
                        Spacer()
                        Text("⏱ \(timeLeft)s")
                            .font(.title2).bold()
                            .foregroundColor(timeLeft <= 5 ? .red : .primary)
                    }
                    .padding(12)
                    .neumorphicCard(radius: 14)
                    .padding()
                    Spacer()
                }

                if showLabel {
                    Text(catchLabel)
                        .font(.title).bold()
                        .foregroundColor(catchLabel.hasPrefix("+") ? .green : .red)
                        .shadow(color: .black.opacity(0.15), radius: 3)
                }
            }
        }
    }

    func startGame() {
        score = 0
        timeLeft = 30
        fish = []
        spawnCounter = 0
        lcg = CtFshLCG(seed: seedInt)
        seedInt += 1
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

        spawnTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { _ in
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
        let screenW = UIScreen.main.bounds.width
        let allTypes = CtFshV3FishType.allCases
        let typeIndex = lcg.nextInt(allTypes.count)
        let type = allTypes[typeIndex]
        let goingRight = lcg.nextInt(2) == 0
        let startX: CGFloat = goingRight ? -40 : screenW + 40
        let yRange = screenH - 260.0
        let y = 140.0 + CGFloat(lcg.nextDouble()) * yRange
        fish.append(CtFshV3Fish(type: type, x: startX, y: y, goingRight: goingRight))
        if fish.count > 14 { fish.removeFirst() }
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

    func catchFish(_ f: CtFshV3Fish) {
        fish.removeAll { $0.id == f.id }
        let pts = f.type.points
        score += pts
        catchLabel = pts >= 0 ? "+\(pts)" : "\(pts)"
        showLabel = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation { showLabel = false }
        }
    }
}

#Preview { CatchFishViewV3() }

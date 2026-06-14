import SwiftUI

// MARK: - Models
struct TWClPlatform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 14
}

enum TWClGamePhase {
    case start, playing, gameOver
}

// MARK: - Main View
struct TowerClimbView: View {
    @State private var phase: TWClGamePhase = .start
    @State private var playerX: CGFloat = 0
    @State private var playerY: CGFloat = 0
    @State private var playerVX: CGFloat = 0
    @State private var playerVY: CGFloat = 0
    @State private var platforms: [TWClPlatform] = []
    @State private var score: Int = 0
    @State private var highScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var isOnGround: Bool = false
    @State private var screenSize: CGSize = .zero

    let playerSize: CGFloat = 26
    let gravity: CGFloat = 0.45
    let scrollSpeed: CGFloat = 1.5
    let jumpPower: CGFloat = -11.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()
                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .gameOver:
                    gameOverScreen
                }
            }
            .onAppear {
                screenSize = geo.size
            }
        }
    }

    // MARK: - Screens
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("TOWER\nCLIMB").font(.system(size: 52, weight: .black)).foregroundColor(.white).multilineTextAlignment(.center)
            Text("Tap left or right to jump\nonto platforms!").font(.system(size: 16, weight: .medium)).foregroundColor(.gray).multilineTextAlignment(.center)
            Button(action: startGame) {
                Text("START").font(.system(size: 22, weight: .bold)).foregroundColor(.black).padding(.horizontal, 48).padding(.vertical, 14).background(Color.white).cornerRadius(30)
            }
            if highScore > 0 {
                Text("Best: \(highScore)").font(.system(size: 14)).foregroundColor(.gray)
            }
        }
    }

    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Platforms
            ForEach(platforms) { p in
                RoundedRectangle(cornerRadius: 5)
                    .fill(platformColor(score: score))
                    .frame(width: p.width, height: p.height)
                    .position(x: p.x, y: p.y)
            }
            // Player
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white)
                .frame(width: playerSize, height: playerSize)
                .position(x: playerX, y: playerY)
            // Score
            VStack {
                Text("\(score)").font(.system(size: 36, weight: .black)).foregroundColor(.white).padding(.top, 50)
                Spacer()
            }
            // Tap zones
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: true) }
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: false) }
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("GAME OVER").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            Text("Score: \(score)").font(.system(size: 28, weight: .bold)).foregroundColor(.yellow)
            if score >= highScore && score > 0 {
                Text("New Best!").font(.system(size: 18, weight: .semibold)).foregroundColor(.green)
            } else if highScore > 0 {
                Text("Best: \(highScore)").font(.system(size: 16)).foregroundColor(.gray)
            }
            Button(action: startGame) {
                Text("PLAY AGAIN").font(.system(size: 20, weight: .bold)).foregroundColor(.black).padding(.horizontal, 44).padding(.vertical, 13).background(Color.white).cornerRadius(28)
            }
        }
    }

    // MARK: - Game Logic
    func platformColor(score: Int) -> Color {
        let colors: [Color] = [.cyan, .mint, .teal, .green, .yellow, .orange]
        return colors[min(score / 5, colors.count - 1)]
    }

    func startGame() {
        score = 0
        playerX = screenSize.width / 2
        playerY = screenSize.height * 0.6
        playerVX = 0
        playerVY = 0
        isOnGround = false
        platforms = spawnInitialPlatforms()
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            gameLoop()
        }
    }

    func spawnInitialPlatforms() -> [TWClPlatform] {
        var ps: [TWClPlatform] = []
        let w = screenSize.width
        let h = screenSize.height
        // Starting platform under player
        ps.append(TWClPlatform(x: w / 2, y: h * 0.65, width: 120))
        var y = h * 0.65 - 110
        while y > -100 {
            let px = CGFloat.random(in: 60...(w - 60))
            ps.append(TWClPlatform(x: px, y: y, width: platformWidth()))
            y -= 110
        }
        return ps
    }

    func platformWidth() -> CGFloat {
        max(40, 120 - CGFloat(score) * 1.5)
    }

    func doJump(left: Bool) {
        guard phase == .playing else { return }
        playerVX = left ? -7.0 : 7.0
        playerVY = jumpPower
    }

    func gameLoop() {
        guard phase == .playing else { return }
        let w = screenSize.width
        let h = screenSize.height

        // Physics
        playerVY += gravity
        playerX += playerVX
        playerY += playerVY
        playerVX *= 0.92

        // Clamp horizontal
        playerX = max(playerSize / 2, min(w - playerSize / 2, playerX))

        // Scroll platforms down
        for i in platforms.indices {
            platforms[i].y += scrollSpeed
        }

        // Platform collision (landing on top)
        if playerVY > 0 {
            for p in platforms {
                let halfW = p.width / 2 + playerSize / 2
                if abs(playerX - p.x) < halfW - 4 &&
                    playerY + playerSize / 2 >= p.y - p.height / 2 &&
                    playerY + playerSize / 2 <= p.y + p.height / 2 + playerVY + 2 {
                    playerY = p.y - p.height / 2 - playerSize / 2
                    playerVY = 0
                    isOnGround = true
                }
            }
        }

        // Remove platforms that scrolled off and spawn new ones
        let topY = platforms.map(\.y).min() ?? 0
        if topY > 80 {
            let newY = topY - 110
            let px = CGFloat.random(in: 60...(w - 60))
            platforms.append(TWClPlatform(x: px, y: newY, width: platformWidth()))
        }
        let scoredPlatforms = platforms.filter { $0.y > h + 20 }
        score += scoredPlatforms.count
        platforms.removeAll { $0.y > h + 20 }

        // Game over: player falls off bottom
        if playerY > h + 40 {
            endGame()
        }
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        if score > highScore { highScore = score }
        phase = .gameOver
    }
}

#Preview { TowerClimbView() }

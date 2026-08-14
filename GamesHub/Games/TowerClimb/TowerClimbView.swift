import SwiftUI

// MARK: - Models 
struct TowerClimbPlatform: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    let height: CGFloat = 14
}

enum TowerClimbPhase {
    case start, playing, gameOver
}

// MARK: - TowerClimbView
struct TowerClimbView: View {
    @State private var phase: TowerClimbPhase = .start
    @State private var playerX: CGFloat = 0
    @State private var playerY: CGFloat = 0
    @State private var playerVX: CGFloat = 0
    @State private var playerVY: CGFloat = 0
    @State private var platforms: [TowerClimbPlatform] = []
    @State private var score: Int = 0
    @AppStorage("towerClimbHighScore") private var highScore: Int = 0
    @State private var timer: Timer? = nil
    @State private var screenSize: CGSize = .zero

    // Adaptive difficulty
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: CGFloat = 1.0

    let playerSize: CGFloat = 26
    let gravity: CGFloat = 0.45
    let baseScrollSpeed: CGFloat = 1.5
    let jumpPower: CGFloat = -11.0

    var scrollSpeed: CGFloat { baseScrollSpeed * speedMultiplier }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.25),
                                        Color(red: 0.15, green: 0.05, blue: 0.35)],
                               startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                switch phase {
                case .start:
                    startScreen
                case .playing:
                    gameScreen(geo: geo)
                case .gameOver:
                    gameOverScreen
                }
            }
            .onAppear { screenSize = geo.size }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            Text("TOWER\nCLIMB").font(.system(size: 52, weight: .black)).foregroundColor(.white).multilineTextAlignment(.center)
            Text("Tap left or right to jump\nonto platforms!").font(.system(size: 16)).foregroundColor(.white.opacity(0.7)).multilineTextAlignment(.center)
            if speedMultiplier > 1.0 {
                Text("Difficulty: \(String(format: "%.0fx", speedMultiplier))").font(.system(size: 13, weight: .semibold)).foregroundColor(.yellow.opacity(0.8))
            }
            Button(action: startGame) {
                Text("START").font(.system(size: 22, weight: .bold)).foregroundColor(.white).padding(.horizontal, 48).padding(.vertical, 14)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
            if highScore > 0 {
                Text("Best: \(highScore)").font(.system(size: 14)).foregroundColor(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Game Screen
    func gameScreen(geo: GeometryProxy) -> some View {
        ZStack {
            // Platforms with glassmorphism
            ForEach(platforms) { p in
                RoundedRectangle(cornerRadius: 6)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.4), lineWidth: 1))
                    .frame(width: p.width, height: p.height)
                    .position(x: p.x, y: p.y)
            }
            // Player
            Circle()
                .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom))
                .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 1))
                .frame(width: playerSize, height: playerSize)
                .position(x: playerX, y: playerY)
            // Score panel
            VStack {
                HStack {
                    Spacer()
                    Text("\(score)").font(.system(size: 34, weight: .black)).foregroundColor(.white).padding(12)
                        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
                        .padding(.top, 50).padding(.trailing, 20)
                }
                Spacer()
            }
            // Speed indicator
            if speedMultiplier > 1.0 {
                VStack {
                    HStack {
                        Text("x\(String(format: "%.1f", speedMultiplier))").font(.system(size: 12, weight: .bold)).foregroundColor(.yellow.opacity(0.8)).padding(8)
                            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.yellow.opacity(0.3), lineWidth: 1))
                            .padding(.top, 50).padding(.leading, 20)
                        Spacer()
                    }
                    Spacer()
                }
            }
            // Tap zones
            HStack(spacing: 0) {
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: true) }
                Color.clear.contentShape(Rectangle()).onTapGesture { doJump(left: false) }
            }
        }
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("GAME OVER").font(.system(size: 40, weight: .black)).foregroundColor(.white)
            VStack(spacing: 8) {
                Text("Score: \(score)").font(.system(size: 28, weight: .bold)).foregroundColor(.cyan)
                if score >= highScore && score > 0 {
                    Text("New Best!").font(.system(size: 18, weight: .semibold)).foregroundColor(.yellow)
                } else if highScore > 0 {
                    Text("Best: \(highScore)").font(.system(size: 15)).foregroundColor(.white.opacity(0.6))
                }
            }.padding(20)
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            Button(action: startGame) {
                Text("PLAY AGAIN").font(.system(size: 20, weight: .bold)).foregroundColor(.white).padding(.horizontal, 44).padding(.vertical, 13)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
    }

    // MARK: - Game Logic
    func startGame() {
        score = 0
        playerX = screenSize.width / 2
        playerY = screenSize.height * 0.6
        playerVX = 0; playerVY = 0
        platforms = spawnInitialPlatforms()
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in gameLoop() }
    }

    func spawnInitialPlatforms() -> [TowerClimbPlatform] {
        var ps: [TowerClimbPlatform] = []
        let w = screenSize.width
        let h = screenSize.height
        ps.append(TowerClimbPlatform(x: w / 2, y: h * 0.65, width: 120))
        var y = h * 0.65 - 110
        while y > -100 {
            ps.append(TowerClimbPlatform(x: CGFloat.random(in: 60...(w - 60)), y: y, width: platformWidth()))
            y -= 110
        }
        return ps
    }

    func platformWidth() -> CGFloat { max(38, 120 - CGFloat(score) * 1.5) }

    func doJump(left: Bool) {
        guard phase == .playing else { return }
        playerVX = left ? -7.0 : 7.0
        playerVY = jumpPower
    }

    func gameLoop() {
        guard phase == .playing else { return }
        let w = screenSize.width; let h = screenSize.height
        playerVY += gravity
        playerX += playerVX; playerY += playerVY
        playerVX *= 0.92
        playerX = max(playerSize / 2, min(w - playerSize / 2, playerX))
        for i in platforms.indices { platforms[i].y += scrollSpeed }
        if playerVY > 0 {
            for p in platforms {
                let halfW = p.width / 2 + playerSize / 2
                if abs(playerX - p.x) < halfW - 4 &&
                    playerY + playerSize / 2 >= p.y - p.height / 2 &&
                    playerY + playerSize / 2 <= p.y + p.height / 2 + playerVY + 2 {
                    playerY = p.y - p.height / 2 - playerSize / 2
                    playerVY = 0
                }
            }
        }
        let topY = platforms.map(\.y).min() ?? 0
        if topY > 80 {
            platforms.append(TowerClimbPlatform(x: CGFloat.random(in: 60...(w - 60)), y: topY - 110, width: platformWidth()))
        }
        let offScreen = platforms.filter { $0.y > h + 20 }
        score += offScreen.count
        platforms.removeAll { $0.y > h + 20 }
        if playerY > h + 40 { endGame() }
    }

    func endGame() {
        timer?.invalidate(); timer = nil
        if score > highScore { highScore = score }
        // Adaptive difficulty
        let success = score >= 10
        recentResults.append(success)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            speedMultiplier = min(speedMultiplier * 1.2, 3.0)
        }
        phase = .gameOver
    }
}

#Preview { TowerClimbView() }

import SwiftUI

// MARK: - Models

enum GemCatcherItemType {
    case gem(GemCatcherGemColor)
    case bomb
}

enum GemCatcherGemColor: CaseIterable {
    case red, green, blue

    var color: Color {
        switch self {
        case .red:   return .red
        case .green: return .green
        case .blue:  return .blue
        }
    }
}

struct GemCatcherFallingItem: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var type: GemCatcherItemType
    var speed: CGFloat
    var radius: CGFloat = 18

    var color: Color {
        switch type {
        case .gem(let gemColor): return gemColor.color
        case .bomb:              return Color(red: 0.8, green: 0.1, blue: 0.1)
        }
    }
}


// MARK: - Models

enum GemCatcherDifficulty: String {
    case easy   = "Easy"
    case medium = "Medium"
    case hard   = "Hard"

    var badgeColor: Color {
        switch self {
        case .easy:   return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .medium: return Color(red: 1.0, green: 0.7, blue: 0.1)
        case .hard:   return Color(red: 0.9, green: 0.2, blue: 0.2)
        }
    }

    var baseSpeed: CGFloat {
        switch self {
        case .easy:   return 2.5
        case .medium: return 4.0
        case .hard:   return 6.0
        }
    }

    var spawnInterval: Double {
        switch self {
        case .easy:   return 1.4
        case .medium: return 1.0
        case .hard:   return 0.65
        }
    }

    var bombProbability: Double {
        switch self {
        case .easy:   return 0.10
        case .medium: return 0.18
        case .hard:   return 0.28
        }
    }
}

// MARK: - Main View

struct GemCatcherView: View {

    // MARK: Persistent state
    @State var roundScores: [Int] = []
    @AppStorage("gemCatcherBestScore") private var bestScore: Int = 0

    // MARK: Game state
    @State private var score: Int = 0
    @State private var timeRemaining: Int = 60
    @State private var isPlaying: Bool = false
    @State private var showGameOver: Bool = false
    @State private var difficulty: GemCatcherDifficulty = .medium

    // MARK: Basket
    @State private var basketX: CGFloat = 0
    @State private var dragOffsetX: CGFloat = 0

    // MARK: Falling items
    @State private var fallingItems: [GemCatcherFallingItem] = []
    @State private var spawnAccumulator: Double = 0

    // MARK: Timers
    @State private var gameTimer: Timer? = nil
    @State private var countdownTimer: Timer? = nil

    // MARK: Geometry cache
    @State private var screenWidth: CGFloat = 390
    @State private var screenHeight: CGFloat = 844

    // MARK: Score flash
    @State private var scoreFlash: String = ""
    @State private var flashOpacity: Double = 0

    // MARK: Constants
    private let basketWidth: CGFloat  = 90
    private let basketHeight: CGFloat = 22
    private let itemRadius: CGFloat   = 18
    private let gameTickRate: Double  = 1.0 / 60.0

    // MARK: Computed basket position
    private var clampedBasketX: CGFloat {
        let half = basketWidth / 2
        let raw  = basketX + dragOffsetX
        return max(half, min(screenWidth - half, raw))
    }

    private var starPositions: [(CGFloat, CGFloat, Double, CGFloat)] {
        (0..<20).map { i in
            let x = CGFloat((i * 37 + 13) % max(1, Int(screenWidth)))
            let y = CGFloat((i * 53 + 7) % max(1, Int(screenHeight * 0.8)))
            let opacity = Double((i * 17 + 11) % 30) / 100.0 + 0.1
            let sz = CGFloat((i * 7 + 3) % 3) + 1
            return (x, y, opacity, sz)
        }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                backgroundGradient

                if isPlaying || showGameOver {
                    gameLayer
                }

                if !isPlaying && !showGameOver {
                    startOverlay
                }

                if showGameOver {
                    gameOverOverlay
                }
            }
            .onAppear {
                screenWidth  = geo.size.width
                screenHeight = geo.size.height
                basketX      = geo.size.width / 2
            }
            .onChange(of: geo.size) { newSize in
                screenWidth  = newSize.width
                screenHeight = newSize.height
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Layers

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.05, green: 0.05, blue: 0.15),
                Color(red: 0.08, green: 0.03, blue: 0.20),
                Color(red: 0.03, green: 0.08, blue: 0.18)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var gameLayer: some View {
        ZStack {
            // Stars decoration
            ForEach(starPositions, id: \.0) { star in
                Circle()
                    .fill(Color.white.opacity(star.2))
                    .frame(width: star.3, height: star.3)
                    .position(x: star.0, y: star.1)
            }

            // Falling items
            ForEach(fallingItems) { item in
                GemCatcherItemView(item: item)
                    .position(x: item.x, y: item.y)
            }

            // Basket
            basketView
                .position(x: clampedBasketX, y: screenHeight - 80)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            dragOffsetX = value.translation.width
                        }
                        .onEnded { value in
                            basketX     = clampedBasketX
                            dragOffsetX = 0
                        }
                )

            // HUD
            hudView

            // Score flash
            if flashOpacity > 0 {
                Text(scoreFlash)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(scoreFlash.hasPrefix("+") ? Color(red: 0.3, green: 1.0, blue: 0.5) : Color(red: 1.0, green: 0.35, blue: 0.35))
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                    .opacity(flashOpacity)
                    .position(x: screenWidth / 2, y: screenHeight / 2 - 60)
                    .allowsHitTesting(false)
            }
        }
    }

    private var basketView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.8),
                                    Color.white.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color.white.opacity(0.25), radius: 8, x: 0, y: -2)
        }
        .frame(width: basketWidth, height: basketHeight)
    }

    private var hudView: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                // Score
                VStack(alignment: .leading, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    Text("\(score)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )

                Spacer()

                // Difficulty badge
                Text(difficulty.rawValue)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(difficulty.badgeColor.opacity(0.35), in: Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(difficulty.badgeColor.opacity(0.7), lineWidth: 1.5)
                    )

                Spacer()

                // Timer
                VStack(alignment: .trailing, spacing: 2) {
                    Text("TIME")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    Text("\(timeRemaining)")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(timeRemaining <= 10 ? Color(red: 1.0, green: 0.35, blue: 0.35) : .white)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)

            Spacer()
        }
    }

    // MARK: - Overlays

    private var startOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Gem Catcher")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.8, green: 0.5, blue: 1.0), Color(red: 0.4, green: 0.7, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0.6, green: 0.3, blue: 1.0).opacity(0.6), radius: 12)

                Text(" — Adaptive Difficulty")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                VStack(spacing: 8) {
                    gemLegendRow(color: Color(red: 0.9, green: 0.2, blue: 0.2), label: "Ruby  +10")
                    gemLegendRow(color: Color(red: 0.1, green: 0.8, blue: 0.3), label: "Emerald  +10")
                    gemLegendRow(color: Color(red: 0.2, green: 0.4, blue: 1.0), label: "Sapphire  +10")
                    bombLegendRow(label: "Bomb  -30")
                    Text("Miss  -5")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

                if !roundScores.isEmpty {
                    VStack(spacing: 6) {
                        Text("Last Rounds: \(roundScores.map { "\($0)" }.joined(separator: ", "))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Difficulty: \(difficulty.rawValue)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(difficulty.badgeColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }

                Button(action: startGame) {
                    Text("Play")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 180, height: 54)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.5, green: 0.2, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 1.0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.5), radius: 12, x: 0, y: 4)
                }
            }
            .padding(32)
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Time's Up!")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.3, blue: 0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                VStack(spacing: 6) {
                    Text("Final Score")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(2)
                    Text("\(score)")
                        .font(.system(size: 56, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                if roundScores.count >= 2 {
                    VStack(spacing: 6) {
                        Text("Recent Scores")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .tracking(1.5)
                        HStack(spacing: 10) {
                            ForEach(roundScores.indices, id: \.self) { i in
                                Text("\(roundScores[i])")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        Text("Next difficulty: \(difficulty.rawValue)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(difficulty.badgeColor)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }

                HStack(spacing: 16) {
                    Button(action: startGame) {
                        Text("Play Again")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 150, height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.5, green: 0.2, blue: 1.0), Color(red: 0.2, green: 0.5, blue: 1.0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: Color(red: 0.4, green: 0.3, blue: 1.0).opacity(0.5), radius: 10, x: 0, y: 4)
                    }

                    Button(action: returnToMenu) {
                        Text("Menu")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 110, height: 50)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(32)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Legend Helpers

    private func gemLegendRow(color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 16, height: 16)
                .shadow(color: color.opacity(0.8), radius: 4)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }

    private func bombLegendRow(label: String) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                .overlay(Circle().strokeBorder(Color.red.opacity(0.8), lineWidth: 2))
                .frame(width: 16, height: 16)
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Spacer()
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        score          = 0
        timeRemaining  = 60
        fallingItems   = []
        spawnAccumulator = 0
        showGameOver   = false
        isPlaying      = true
        basketX        = screenWidth / 2
        dragOffsetX    = 0

        startGameLoop()
        startCountdown()
    }

    private func returnToMenu() {
        showGameOver = false
        isPlaying    = false
        stopTimers()
        fallingItems = []
    }

    private func startGameLoop() {
        gameTimer?.invalidate()
        let timer = Timer(timeInterval: gameTickRate, repeats: true) { _ in
            gameTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        gameTimer = timer
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                endGame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func stopTimers() {
        gameTimer?.invalidate()
        countdownTimer?.invalidate()
        gameTimer     = nil
        countdownTimer = nil
    }

    private func endGame() {
        stopTimers()
        isPlaying = false

        bestScore = max(bestScore, score)

        // Update round scores (keep last 5)
        roundScores.append(score)
        if roundScores.count > 5 {
            roundScores = Array(roundScores.suffix(5))
        }

        // Compute moving average and adjust difficulty
        let avg = Double(roundScores.reduce(0, +)) / Double(roundScores.count)
        if avg >= 200 {
            difficulty = .hard
        } else if avg >= 80 {
            difficulty = .medium
        } else {
            difficulty = .easy
        }

        showGameOver = true
    }

    private func gameTick() {
        guard isPlaying else { return }

        spawnAccumulator += gameTickRate
        let interval = difficulty.spawnInterval

        if spawnAccumulator >= interval {
            spawnAccumulator = 0
            spawnItem()
        }

        // Move items
        var toRemove: [UUID] = []
        for i in fallingItems.indices {
            fallingItems[i].y += fallingItems[i].speed
            if fallingItems[i].y > screenHeight + itemRadius {
                // Missed (only penalize gems, not bombs)
                if case .gem = fallingItems[i].type {
                    score = max(score - 5, -999)
                    showFlash("-5")
                }
                toRemove.append(fallingItems[i].id)
            }
        }
        fallingItems.removeAll { toRemove.contains($0.id) }

        // Collision detection
        let basketY  = screenHeight - 80
        let halfBasket = basketWidth / 2
        var caught: [UUID] = []

        for item in fallingItems {
            let dx = abs(item.x - clampedBasketX)
            let dy = abs(item.y - basketY)
            if dx < halfBasket + itemRadius * 0.5 && dy < basketHeight / 2 + itemRadius * 0.7 {
                caught.append(item.id)
                switch item.type {
                case .gem:
                    score += 10
                    showFlash("+10")
                case .bomb:
                    score = max(score - 30, -999)
                    showFlash("-30")
                }
            }
        }
        fallingItems.removeAll { caught.contains($0.id) }
    }

    private func spawnItem() {
        let margin: CGFloat = itemRadius + 8
        let x = CGFloat.random(in: margin...(screenWidth - margin))

        // Adaptive speed: scale within difficulty band based on remaining time
        let timeProgress = 1.0 - (Double(timeRemaining) / 60.0)
        let baseSpeed    = difficulty.baseSpeed
        let speedBonus   = baseSpeed * timeProgress * 0.4
        let speed        = CGFloat(baseSpeed + speedBonus)

        let isBomb = Double.random(in: 0...1) < difficulty.bombProbability
        let type: GemCatcherItemType = isBomb
            ? .bomb
            : .gem(GemCatcherGemColor.allCases.randomElement() ?? .red)

        let item = GemCatcherFallingItem(x: x, y: -itemRadius, type: type, speed: speed)
        fallingItems.append(item)
    }

    private func showFlash(_ text: String) {
        scoreFlash  = text
        flashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.8)) {
            flashOpacity = 0
        }
    }
}

// MARK: - Item View

// MARK: - Preview

#Preview {
    GemCatcherView()
}
struct GemCatcherItemView: View {
    let item: GemCatcherFallingItem

    var body: some View {
        Group {
            switch item.type {
            case .gem(let gemColor):
                GemCatcherGemShape(color: gemColor.color, radius: item.radius)
            case .bomb:
                GemCatcherBombShape(radius: item.radius)
            }
        }
    }
}
struct GemCatcherGemShape: View {
    let color: Color
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: radius * 2.6, height: radius * 2.6)
            // Gem diamond shape
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.8), color, color.opacity(0.5)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 1.6, height: radius * 1.6)
                .rotationEffect(.degrees(45))
            // Shine
            Circle()
                .fill(Color.white.opacity(0.5))
                .frame(width: radius * 0.5, height: radius * 0.5)
                .offset(x: -radius * 0.3, y: -radius * 0.3)
        }
        .frame(width: radius * 2, height: radius * 2)
    }
}
struct GemCatcherBombShape: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(Color.red.opacity(0.25))
                .frame(width: radius * 2.6, height: radius * 2.6)
            // Body
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.9, green: 0.2, blue: 0.2),
                            Color(red: 0.5, green: 0.0, blue: 0.0)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
            // Skull-like cross
            Text("💣")
                .font(.system(size: radius * 1.1))
        }
    }
}

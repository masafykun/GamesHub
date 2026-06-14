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

// MARK: - ViewModel

class GemCatcherViewModel: ObservableObject {
    // Layout constants — set when view appears
    var screenWidth: CGFloat = 390
    var screenHeight: CGFloat = 844

    // Game state
    @Published var score: Int = 0
    @Published var timeRemaining: Int = 60
    @Published var items: [GemCatcherFallingItem] = []
    @Published var basketX: CGFloat = 195
    @Published var isGameOver: Bool = false
    @Published var isRunning: Bool = false

    // Flash feedback
    @Published var feedbackText: String = ""
    @Published var feedbackOpacity: Double = 0

    let basketWidth: CGFloat = 90
    let basketHeight: CGFloat = 22

    private var gameTimer: Timer?
    private var countdownTimer: Timer?
    private var spawnAccumulator: Double = 0
    private var frameAccumulator: Double = 0
    private var difficultyMultiplier: Double = 1.0

    var basketY: CGFloat {
        screenHeight - 80
    }

    // MARK: - Lifecycle

    func startGame() {
        score = 0
        timeRemaining = 60
        items = []
        basketX = screenWidth / 2
        isGameOver = false
        isRunning = true
        spawnAccumulator = 0
        difficultyMultiplier = 1.0
        feedbackOpacity = 0

        startGameLoop()
        startCountdown()
    }

    func stopGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        countdownTimer?.invalidate()
        countdownTimer = nil
        isRunning = false
    }

    private func startGameLoop() {
        gameTimer?.invalidate()
        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(gameTimer!, forMode: .common)
    }

    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.timeRemaining > 0 {
                    self.timeRemaining -= 1
                    // Increase difficulty over time
                    self.difficultyMultiplier = 1.0 + Double(60 - self.timeRemaining) / 60.0
                } else {
                    self.endGame()
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }

    private func endGame() {
        stopGame()
        isGameOver = true
    }

    // MARK: - Update

    private func update() {
        let dt: Double = 1.0 / 60.0
        spawnAccumulator += dt

        // Spawn interval decreases as difficulty increases
        let spawnInterval = max(0.6, 1.4 / difficultyMultiplier)

        if spawnAccumulator >= spawnInterval {
            spawnAccumulator = 0
            spawnItem()
        }

        // Move items downward
        var toRemove: [UUID] = []
        var caught: [(UUID, GemCatcherItemType)] = []

        for i in items.indices {
            items[i].y += items[i].speed * CGFloat(difficultyMultiplier)

            let item = items[i]

            // Check catch
            if item.y + item.radius >= basketY - basketHeight / 2 &&
               item.y - item.radius <= basketY + basketHeight / 2 &&
               item.x >= basketX - basketWidth / 2 - item.radius &&
               item.x <= basketX + basketWidth / 2 + item.radius {
                caught.append((item.id, item.type))
                toRemove.append(item.id)
                continue
            }

            // Off screen
            if item.y - item.radius > screenHeight {
                if case .gem = item.type {
                    DispatchQueue.main.async { [weak self] in
                        self?.applyMiss()
                    }
                }
                toRemove.append(item.id)
            }
        }

        items.removeAll { toRemove.contains($0.id) }

        for (_, type) in caught {
            switch type {
            case .gem:
                DispatchQueue.main.async { [weak self] in self?.applyCatch() }
            case .bomb:
                DispatchQueue.main.async { [weak self] in self?.applyBomb() }
            }
        }
    }

    private func spawnItem() {
        let margin: CGFloat = 30
        let x = CGFloat.random(in: margin...(screenWidth - margin))

        // 20% chance of bomb
        let isBomb = Double.random(in: 0...1) < 0.20
        let type: GemCatcherItemType
        if isBomb {
            type = .bomb
        } else {
            let gemColor = GemCatcherGemColor.allCases.randomElement()!
            type = .gem(gemColor)
        }

        let baseSpeed = CGFloat.random(in: 2.8...4.5)

        let item = GemCatcherFallingItem(x: x, y: -20, type: type, speed: baseSpeed)
        items.append(item)
    }

    // MARK: - Scoring

    private func applyCatch() {
        score += 10
        showFeedback("+10", color: .green)
    }

    private func applyMiss() {
        score = max(score - 5, -999)
        showFeedback("-5", color: .orange)
    }

    private func applyBomb() {
        score = max(score - 30, -999)
        showFeedback("-30", color: .red)
    }

    private func showFeedback(_ text: String, color: Color) {
        feedbackText = text
        withAnimation(.easeIn(duration: 0.1)) {
            feedbackOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            withAnimation(.easeOut(duration: 0.3)) {
                self?.feedbackOpacity = 0
            }
        }
    }

    // MARK: - Basket Control

    func movBasket(to x: CGFloat) {
        let half = basketWidth / 2
        basketX = min(max(x, half), screenWidth - half)
    }
}

// MARK: - Main View

struct GemCatcherView: View {
    @StateObject private var vm = GemCatcherViewModel()
    @GestureState private var dragOffset: CGFloat = 0
    @State private var dragStartBasketX: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.18),
                        Color(red: 0.10, green: 0.05, blue: 0.25)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Stars background
                GemCatcherStarsView()

                if vm.isRunning || vm.isGameOver {
                    // Game field
                    gameField(geo: geo)
                }

                if !vm.isRunning && !vm.isGameOver {
                    GemCatcherStartView {
                        vm.screenWidth = geo.size.width
                        vm.screenHeight = geo.size.height
                        vm.startGame()
                    }
                }

                if vm.isGameOver {
                    GemCatcherGameOverView(score: vm.score) {
                        vm.screenWidth = geo.size.width
                        vm.screenHeight = geo.size.height
                        vm.startGame()
                    }
                }
            }
            .onAppear {
                vm.screenWidth = geo.size.width
                vm.screenHeight = geo.size.height
            }
        }
    }

    @ViewBuilder
    private func gameField(geo: GeometryProxy) -> some View {
        ZStack {
            // HUD
            VStack {
                GemCatcherHUDView(score: vm.score, timeRemaining: vm.timeRemaining)
                Spacer()
            }

            // Falling items
            ForEach(vm.items) { item in
                GemCatcherItemView(item: item)
                    .position(x: item.x, y: item.y)
            }

            // Basket
            GemCatcherBasketView(width: vm.basketWidth, height: vm.basketHeight)
                .position(x: vm.basketX, y: vm.basketY)

            // Feedback label
            Text(vm.feedbackText)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 4)
                .opacity(vm.feedbackOpacity)
                .position(x: geo.size.width / 2, y: geo.size.height / 2 - 40)
                .allowsHitTesting(false)

            // Drag capture overlay
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            vm.movBasket(to: value.location.x)
                        }
                )
        }
    }
}

// MARK: - Sub-views

struct GemCatcherStarsView: View {
    // Fixed star positions to avoid recompute
    private let stars: [(CGFloat, CGFloat, Double)] = (0..<80).map { _ in
        (CGFloat.random(in: 0...400), CGFloat.random(in: 0...900), Double.random(in: 0.3...1.0))
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<stars.count, id: \.self) { i in
                Circle()
                    .fill(Color.white.opacity(stars[i].2 * 0.6))
                    .frame(width: 2, height: 2)
                    .position(
                        x: stars[i].0 / 400 * geo.size.width,
                        y: stars[i].1 / 900 * geo.size.height
                    )
            }
        }
        .allowsHitTesting(false)
    }
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

struct GemCatcherBasketView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            // Shadow
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .frame(width: width + 6, height: height + 6)
                .offset(y: 3)

            // Main basket
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.9, green: 0.85, blue: 0.3),
                            Color(red: 0.7, green: 0.55, blue: 0.1)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.5), lineWidth: 2)
                )

            // Shine
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.3))
                .frame(width: width * 0.6, height: height * 0.35)
                .offset(y: -height * 0.15)
        }
    }
}

struct GemCatcherHUDView: View {
    let score: Int
    let timeRemaining: Int

    var timerColor: Color {
        timeRemaining > 20 ? .white : (timeRemaining > 10 ? .yellow : .red)
    }

    var body: some View {
        HStack {
            // Score
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("\(score)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.12))
            )

            Spacer()

            // Timer
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .foregroundColor(timerColor)
                Text("\(timeRemaining)s")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(timerColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.12))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

struct GemCatcherStartView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Text("💎")
                .font(.system(size: 72))

            Text("Gem Catcher")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                GemCatcherRuleRow(icon: "💎", text: "Catch gems: +10")
                GemCatcherRuleRow(icon: "❌", text: "Miss gem: -5")
                GemCatcherRuleRow(icon: "💣", text: "Catch bomb: -30")
                GemCatcherRuleRow(icon: "👆", text: "Drag to move basket")
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))
            )

            Button(action: onStart) {
                Text("Start Game")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.yellow, .orange]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .orange.opacity(0.5), radius: 12, x: 0, y: 6)
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.1, green: 0.08, blue: 0.22).opacity(0.95))
                .shadow(color: .black.opacity(0.5), radius: 24)
        )
        .padding(24)
    }
}

struct GemCatcherRuleRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(icon)
                .font(.system(size: 20))
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct GemCatcherGameOverView: View {
    let score: Int
    let onRestart: () -> Void

    var medal: String {
        if score >= 300 { return "🥇" }
        if score >= 150 { return "🥈" }
        if score >= 50  { return "🥉" }
        return "😢"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Game Over")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text(medal)
                    .font(.system(size: 60))

                VStack(spacing: 6) {
                    Text("Final Score")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                    Text("\(score)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundColor(.yellow)
                }

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.yellow, .orange]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: .orange.opacity(0.5), radius: 12, x: 0, y: 6)
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(red: 0.08, green: 0.06, blue: 0.20))
                    .shadow(color: .black.opacity(0.6), radius: 30)
            )
            .padding(28)
        }
    }
}

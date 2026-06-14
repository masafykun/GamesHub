import SwiftUI

// MARK: - Models

struct WhackHole: Identifiable {
    let id: Int
    var isMoleUp: Bool = false
    var moleTimer: Double = 0
}

enum WhackGameState {
    case idle
    case playing
    case gameOver
}

// MARK: - ViewModel

class WhackGameViewModel: ObservableObject {
    @Published var holes: [WhackHole] = (0..<9).map { WhackHole(id: $0) }
    @Published var score: Int = 0
    @Published var timeRemaining: Int = 30
    @Published var gameState: WhackGameState = .idle

    private var gameTimer: Timer?
    private var moleInterval: Double = 0
    private var elapsed: Double = 0
    private let moleDuration: Double = 1.2
    private let moleSpawnInterval: Double = 0.8

    func startGame() {
        resetGame()
        gameState = .playing
        elapsed = 0
        moleInterval = 0

        gameTimer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        if let t = gameTimer {
            RunLoop.main.add(t, forMode: .common)
        }
    }

    private func resetGame() {
        score = 0
        timeRemaining = 30
        holes = (0..<9).map { WhackHole(id: $0) }
        gameTimer?.invalidate()
        gameTimer = nil
    }

    private func tick() {
        let dt = 1.0 / 60.0
        elapsed += dt

        // Update countdown
        let newTime = max(0, 30 - Int(elapsed))
        if newTime != timeRemaining {
            timeRemaining = newTime
        }

        // End game
        if elapsed >= 30 {
            endGame()
            return
        }

        // Spawn moles
        moleInterval += dt
        if moleInterval >= moleSpawnInterval {
            moleInterval = 0
            spawnMoles()
        }

        // Age active moles
        for i in 0..<holes.count {
            if holes[i].isMoleUp {
                holes[i].moleTimer += dt
                if holes[i].moleTimer >= moleDuration {
                    holes[i].isMoleUp = false
                    holes[i].moleTimer = 0
                }
            }
        }
    }

    private func spawnMoles() {
        let count = Int.random(in: 1...2)
        let downIndices = holes.indices.filter { !holes[$0].isMoleUp }
        let shuffled = downIndices.shuffled().prefix(count)
        for i in shuffled {
            holes[i].isMoleUp = true
            holes[i].moleTimer = 0
        }
    }

    private func endGame() {
        gameTimer?.invalidate()
        gameTimer = nil
        for i in 0..<holes.count {
            holes[i].isMoleUp = false
        }
        gameState = .gameOver
    }

    func tapHole(_ id: Int) {
        guard gameState == .playing else { return }
        guard let idx = holes.firstIndex(where: { $0.id == id }) else { return }
        if holes[idx].isMoleUp {
            holes[idx].isMoleUp = false
            holes[idx].moleTimer = 0
            score += 10
        } else {
            score -= 5
        }
    }
}

// MARK: - Main View

struct WhackView: View {
    @StateObject private var vm = WhackGameViewModel()

    let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        ZStack {
            Color(red: 0.53, green: 0.81, blue: 0.53)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                HStack {
                    WhackStatBadge(label: "SCORE", value: "\(vm.score)")
                    Spacer()
                    WhackStatBadge(label: "TIME", value: "\(vm.timeRemaining)s")
                }
                .padding(.horizontal, 24)

                // Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(vm.holes) { hole in
                        WhackHoleView(hole: hole) {
                            vm.tapHole(hole.id)
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Start button (idle state)
                if vm.gameState == .idle {
                    Button(action: { vm.startGame() }) {
                        Text("Start Game")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.2, green: 0.6, blue: 0.2))
                            .clipShape(Capsule())
                            .shadow(radius: 4)
                    }
                }
            }
            .padding(.vertical, 40)

            // Game Over overlay
            if vm.gameState == .gameOver {
                WhackGameOverOverlay(score: vm.score) {
                    vm.startGame()
                }
            }
        }
    }
}

// MARK: - Hole View

struct WhackHoleView: View {
    let hole: WhackHole
    let onTap: () -> Void

    @State private var pressed: Bool = false

    var body: some View {
        ZStack {
            // Hole background
            Ellipse()
                .fill(Color(red: 0.3, green: 0.18, blue: 0.07))
                .frame(height: 60)
                .padding(.top, 30)

            // Mole
            if hole.isMoleUp {
                WhackMoleSprite(pressed: pressed)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 90, height: 90)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if hole.isMoleUp {
                withAnimation(.easeIn(duration: 0.1)) {
                    pressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    pressed = false
                }
            }
            onTap()
        }
        .animation(.easeOut(duration: 0.2), value: hole.isMoleUp)
        .onChange(of: hole.isMoleUp) { up in
            if !up { pressed = false }
        }
    }
}

// MARK: - Mole Sprite

struct WhackMoleSprite: View {
    let pressed: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Body
                Ellipse()
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.18))
                    .frame(width: 54, height: 58)

                // Face
                VStack(spacing: 4) {
                    HStack(spacing: 12) {
                        WhackEye()
                        WhackEye()
                    }
                    // Nose
                    Ellipse()
                        .fill(Color(red: 0.9, green: 0.5, blue: 0.5))
                        .frame(width: 14, height: 10)
                }
                .offset(y: pressed ? 3 : 0)
            }
            .scaleEffect(pressed ? 0.88 : 1.0)
        }
        .offset(y: pressed ? 6 : 0)
    }
}

struct WhackEye: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 14, height: 14)
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
        }
    }
}

// MARK: - Stat Badge

struct WhackStatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Game Over Overlay

struct WhackGameOverOverlay: View {
    let score: Int
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Game Over!")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)

                Text("Final Score")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.75))

                Text("\(score)")
                    .font(.system(size: 60, weight: .black))
                    .foregroundColor(.yellow)

                Button(action: onRestart) {
                    Text("Play Again")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 44)
                        .padding(.vertical, 14)
                        .background(Color(red: 0.2, green: 0.6, blue: 0.2))
                        .clipShape(Capsule())
                        .shadow(radius: 6)
                }
            }
            .padding(40)
            .background(Color(red: 0.15, green: 0.12, blue: 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(radius: 20)
            .padding(.horizontal, 32)
        }
    }
}

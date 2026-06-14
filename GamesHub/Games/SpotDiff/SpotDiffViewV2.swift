import SwiftUI

// MARK: - Data Types

struct SpDfV2Cell: Identifiable {
    let id: Int
    var color: Color
}

struct SpDfV2Level {
    let leftColors: [Color]
    let diffIndices: Set<Int>
    let rightColors: [Color]
}

enum SpDfV2Phase {
    case start, playing, complete
}

// MARK: - Levels

private let spDfV2Levels: [SpDfV2Level] = {
    let p1: [Color] = [.red, .blue, .green, .yellow, .orange,
                       .purple, .pink, .cyan, .mint, .indigo,
                       .teal, .red, .blue, .green, .yellow,
                       .orange, .purple, .pink, .cyan, .mint,
                       .indigo, .teal, .red, .blue, .green]
    var r1 = p1; r1[2] = .brown; r1[11] = .gray; r1[18] = .white

    let p2: [Color] = [.cyan, .mint, .indigo, .teal, .pink,
                       .red, .blue, .green, .yellow, .orange,
                       .purple, .pink, .cyan, .mint, .indigo,
                       .teal, .red, .blue, .green, .yellow,
                       .orange, .purple, .pink, .cyan, .mint]
    var r2 = p2; r2[0] = .orange; r2[14] = .red; r2[22] = .teal

    let p3: [Color] = [.purple, .orange, .teal, .cyan, .red,
                       .blue, .green, .yellow, .indigo, .mint,
                       .pink, .red, .blue, .green, .yellow,
                       .orange, .purple, .cyan, .teal, .indigo,
                       .mint, .pink, .red, .blue, .green]
    var r3 = p3; r3[4] = .purple; r3[9] = .pink; r3[20] = .orange

    return [
        SpDfV2Level(leftColors: p1, diffIndices: [2, 11, 18], rightColors: r1),
        SpDfV2Level(leftColors: p2, diffIndices: [0, 14, 22], rightColors: r2),
        SpDfV2Level(leftColors: p3, diffIndices: [4, 9, 20], rightColors: r3),
    ]
}()

// MARK: - Main View

struct SpotDiffViewV2: View {
    @State private var phase: SpDfV2Phase = .start
    @State private var levelIndex: Int = 0
    @State private var foundIndices: Set<Int> = []
    @State private var wrongFlash: Set<Int> = []
    @State private var elapsed: Double = 0
    @State private var gameTimer: Timer? = nil
    @State private var recentResults: [Bool] = []
    @State private var speedMultiplier: Double = 1.0

    private var level: SpDfV2Level { spDfV2Levels[levelIndex % spDfV2Levels.count] }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.indigo.opacity(0.8), Color.purple.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    // MARK: Start Screen
    private var startScreen: some View {
        VStack(spacing: 28) {
            Text("Spot the Difference")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Find 3 differences\nbetween LEFT and RIGHT grids")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.8))
            Button(action: beginGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding()
    }

    // MARK: Game Screen
    private var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(levelIndex + 1)")
                    .font(.headline).foregroundColor(.white)
                Spacer()
                Text(String(format: "%.1fs", elapsed))
                    .font(.headline.monospacedDigit()).foregroundColor(.white)
                Spacer()
                Text("\(foundIndices.count)/3")
                    .font(.headline).foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            if speedMultiplier > 1.0 {
                Text("Speed Boost Active!")
                    .font(.caption.bold())
                    .foregroundColor(.yellow)
            }

            HStack(spacing: 16) {
                gridPanel(isRight: false)
                gridPanel(isRight: true)
            }
            .padding(.horizontal)
        }
    }

    private func gridPanel(isRight: Bool) -> some View {
        VStack(spacing: 6) {
            Text(isRight ? "RIGHT" : "LEFT")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 3), count: 5), spacing: 3) {
                ForEach(0..<25, id: \.self) { idx in
                    let colors = isRight ? level.rightColors : level.leftColors
                    let isFound = isRight && foundIndices.contains(idx)
                    let isWrong = isRight && wrongFlash.contains(idx)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFound ? Color.red.opacity(0.85) : (isWrong ? Color.red.opacity(0.5) : colors[idx]))
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isFound ? Color.white : Color.white.opacity(0.2), lineWidth: isFound ? 2 : 1)
                        )
                        .onTapGesture {
                            if isRight { handleTap(idx) }
                        }
                }
            }
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    // MARK: Complete Screen
    private var completeScreen: some View {
        VStack(spacing: 24) {
            Text("Level Complete!")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text(String(format: "Time: %.1f seconds", elapsed))
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            if speedMultiplier > 1.0 {
                Text(String(format: "Speed: %.0fx", speedMultiplier))
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
            HStack(spacing: 16) {
                if levelIndex + 1 < spDfV2Levels.count {
                    Button("Next Level") {
                        levelIndex += 1
                        beginGame()
                    }
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
                }
                Button("Play Again") {
                    levelIndex = 0
                    speedMultiplier = 1.0
                    recentResults = []
                    beginGame()
                }
                .font(.headline).foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding()
    }

    // MARK: Logic
    private func beginGame() {
        foundIndices = []
        wrongFlash = []
        elapsed = 0
        phase = .playing
        gameTimer?.invalidate()
        let interval = 0.1 / speedMultiplier
        gameTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    private func handleTap(_ idx: Int) {
        guard phase == .playing else { return }
        if level.diffIndices.contains(idx) {
            foundIndices.insert(idx)
            if foundIndices.count == 3 {
                gameTimer?.invalidate()
                // Record result and adapt difficulty
                let success = elapsed < 30.0
                recentResults.append(success)
                if recentResults.count > 5 { recentResults.removeFirst() }
                if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
                    speedMultiplier = min(speedMultiplier * 1.2, 3.0)
                }
                phase = .complete
            }
        } else if !foundIndices.contains(idx) {
            wrongFlash.insert(idx)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                wrongFlash.remove(idx)
            }
        }
    }
}

#Preview { SpotDiffViewV2() }

import SwiftUI

// MARK: - Data Types

struct SpDfCell: Identifiable, Equatable {
    let id: Int
    var color: Color
}

struct SpDfLevel {
    let leftColors: [Color]
    let diffIndices: Set<Int>
    let rightColors: [Color]
}

enum SpDfPhase {
    case start, playing, complete
}

// MARK: - Levels

private let spDfLevels: [SpDfLevel] = {
    let palette1: [Color] = [.red, .blue, .green, .yellow, .orange,
                             .purple, .pink, .cyan, .mint, .indigo,
                             .teal, .red, .blue, .green, .yellow,
                             .orange, .purple, .pink, .cyan, .mint,
                             .indigo, .teal, .red, .blue, .green]
    var right1 = palette1
    right1[2] = .brown
    right1[11] = .gray
    right1[18] = .white

    let palette2: [Color] = [.cyan, .mint, .indigo, .teal, .pink,
                             .red, .blue, .green, .yellow, .orange,
                             .purple, .pink, .cyan, .mint, .indigo,
                             .teal, .red, .blue, .green, .yellow,
                             .orange, .purple, .pink, .cyan, .mint]
    var right2 = palette2
    right2[0] = .orange
    right2[14] = .red
    right2[22] = .teal

    let palette3: [Color] = [.purple, .orange, .teal, .cyan, .red,
                             .blue, .green, .yellow, .indigo, .mint,
                             .pink, .red, .blue, .green, .yellow,
                             .orange, .purple, .cyan, .teal, .indigo,
                             .mint, .pink, .red, .blue, .green]
    var right3 = palette3
    right3[4] = .purple
    right3[9] = .pink
    right3[20] = .orange

    return [
        SpDfLevel(leftColors: palette1, diffIndices: [2, 11, 18], rightColors: right1),
        SpDfLevel(leftColors: palette2, diffIndices: [0, 14, 22], rightColors: right2),
        SpDfLevel(leftColors: palette3, diffIndices: [4, 9, 20], rightColors: right3),
    ]
}()

// MARK: - Main View

struct SpotDiffView: View {
    @State private var phase: SpDfPhase = .start
    @State private var levelIndex: Int = 0
    @State private var foundIndices: Set<Int> = []
    @State private var wrongFlash: Set<Int> = []
    @State private var elapsed: Double = 0
    @State private var timer: Timer? = nil

    private var level: SpDfLevel { spDfLevels[levelIndex % spDfLevels.count] }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    // MARK: Start Screen
    private var startScreen: some View {
        VStack(spacing: 24) {
            Text("Spot the Difference").font(.largeTitle.bold())
            Text("Find 3 differences\nbetween LEFT and RIGHT grids")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: beginGame) {
                Text("Start Game")
                    .font(.headline)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    // MARK: Game Screen
    private var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Level \(levelIndex + 1)").font(.headline)
                Spacer()
                Text(String(format: "Time: %.1fs", elapsed)).font(.headline).monospacedDigit()
                Spacer()
                Text("Found: \(foundIndices.count)/3").font(.headline)
            }
            .padding(.horizontal)

            HStack(spacing: 20) {
                gridView(isRight: false)
                gridView(isRight: true)
            }
            .padding(.horizontal)
        }
    }

    private func gridView(isRight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(isRight ? "RIGHT" : "LEFT")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 4), count: 5), spacing: 4) {
                ForEach(0..<25, id: \.self) { idx in
                    let colors = isRight ? level.rightColors : level.leftColors
                    let isFound = isRight && foundIndices.contains(idx)
                    let isWrong = isRight && wrongFlash.contains(idx)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFound ? Color.red.opacity(0.8) : (isWrong ? Color.red.opacity(0.4) : colors[idx]))
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isFound ? Color.red : Color.clear, lineWidth: 2)
                        )
                        .onTapGesture {
                            if isRight { handleTap(idx) }
                        }
                }
            }
        }
    }

    // MARK: Complete Screen
    private var completeScreen: some View {
        VStack(spacing: 24) {
            Text("Level Complete!").font(.largeTitle.bold())
            Text(String(format: "Time: %.1f seconds", elapsed))
                .font(.title3)
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                if levelIndex + 1 < spDfLevels.count {
                    Button("Next Level") {
                        levelIndex += 1
                        beginGame()
                    }
                    .font(.headline)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button("Play Again") {
                    levelIndex = 0
                    beginGame()
                }
                .font(.headline)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }

    // MARK: Logic
    private func beginGame() {
        foundIndices = []
        wrongFlash = []
        elapsed = 0
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    private func handleTap(_ idx: Int) {
        guard phase == .playing else { return }
        if level.diffIndices.contains(idx) {
            foundIndices.insert(idx)
            if foundIndices.count == 3 {
                timer?.invalidate()
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

#Preview { SpotDiffView() }

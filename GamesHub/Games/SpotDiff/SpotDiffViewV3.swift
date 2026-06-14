import SwiftUI

// MARK: - LCG Random Number Generator

struct SpDfLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Data Types

struct SpDfV3Level {
    let leftColors: [Color]
    let diffIndices: Set<Int>
    let rightColors: [Color]
}

enum SpDfV3Phase {
    case start, playing, complete
}

// MARK: - Color Palette

private let spDfV3Palette: [Color] = [
    .red, .blue, .green, .yellow, .orange,
    .purple, .pink, .cyan, .mint, .indigo,
    .teal, .brown, .gray
]

// MARK: - Level Generation

private func spDfV3GenerateLevel(seed: Int) -> SpDfV3Level {
    var rng = SpDfLCG(seed: seed)

    // Generate 25 left colors using LCG
    var leftColors: [Color] = (0..<25).map { _ in
        spDfV3Palette[rng.nextInt(spDfV3Palette.count)]
    }

    // Pick 3 unique diff indices
    var diffSet: Set<Int> = []
    while diffSet.count < 3 {
        diffSet.insert(rng.nextInt(25))
    }

    // Generate right colors: same as left, but different at diff indices
    var rightColors = leftColors
    for idx in diffSet {
        var newColor: Color
        repeat {
            newColor = spDfV3Palette[rng.nextInt(spDfV3Palette.count)]
        } while newColor == leftColors[idx]
        rightColors[idx] = newColor
    }

    return SpDfV3Level(leftColors: leftColors, diffIndices: diffSet, rightColors: rightColors)
}

// MARK: - Main View

struct SpotDiffViewV3: View {
    @State private var phase: SpDfV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var currentLevel: SpDfV3Level = spDfV3GenerateLevel(seed: 1)
    @State private var foundIndices: Set<Int> = []
    @State private var wrongFlash: Set<Int> = []
    @State private var elapsed: Double = 0
    @State private var gameTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
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
                .foregroundColor(.primary)
            Text("Find 3 differences\nbetween LEFT and RIGHT grids")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button(action: beginGame) {
                Text("Start Game")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 40).padding(.vertical, 14)
                    .neumorphicCard(radius: 12)
            }
        }
        .padding()
    }

    // MARK: Game Screen
    private var gameScreen: some View {
        VStack(spacing: 16) {
            // Stats bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(seedInt)")
                        .font(.headline)
                    Text("SEED: #\(seedInt)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .monospaced()
                }
                Spacer()
                Text(String(format: "%.1fs", elapsed))
                    .font(.headline.monospacedDigit())
                Spacer()
                Text("\(foundIndices.count)/3 found")
                    .font(.headline)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

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
                .foregroundColor(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 4), count: 5), spacing: 4) {
                ForEach(0..<25, id: \.self) { idx in
                    let colors = isRight ? currentLevel.rightColors : currentLevel.leftColors
                    let isFound = isRight && foundIndices.contains(idx)
                    let isWrong = isRight && wrongFlash.contains(idx)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isFound ? Color.red.opacity(0.8) : (isWrong ? Color.red.opacity(0.5) : colors[idx]))
                        .frame(width: 40, height: 40)
                        .shadow(color: isFound ? .red.opacity(0.5) : .clear, radius: 4)
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
        .padding(10)
        .neumorphicCard(radius: 16)
    }

    // MARK: Complete Screen
    private var completeScreen: some View {
        VStack(spacing: 24) {
            Text("Level Complete!")
                .font(.largeTitle.bold())
            Text(String(format: "Time: %.1f seconds", elapsed))
                .font(.title3)
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.caption)
                .foregroundColor(.gray)
                .monospaced()
            HStack(spacing: 16) {
                Button("Next Level") {
                    seedInt += 1
                    beginGame()
                }
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .neumorphicCard(radius: 12)

                Button("Restart") {
                    seedInt = 1
                    beginGame()
                }
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .neumorphicCard(radius: 12)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 24)
        .padding()
    }

    // MARK: Logic
    private func beginGame() {
        currentLevel = spDfV3GenerateLevel(seed: seedInt)
        foundIndices = []
        wrongFlash = []
        elapsed = 0
        phase = .playing
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            elapsed += 0.1
        }
    }

    private func handleTap(_ idx: Int) {
        guard phase == .playing else { return }
        if currentLevel.diffIndices.contains(idx) {
            foundIndices.insert(idx)
            if foundIndices.count == 3 {
                gameTimer?.invalidate()
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

#Preview { SpotDiffViewV3() }

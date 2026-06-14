import SwiftUI

struct MmSqLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum MmSqPhaseV3 {
    case start, showing, input, gameOver
}

struct MemorySeqViewV3: View {
    @State private var phase: MmSqPhaseV3 = .start
    @State private var sequence: [Int] = []
    @State private var playerIndex: Int = 0
    @State private var lives: Int = 3
    @State private var showFlash: Int = -1
    @State private var score: Int = 0
    @State private var seedInt: Int = 1
    @State private var rng: MmSqLCG = MmSqLCG(seed: 1)

    let colors: [Color] = [.red, .blue, .green, .yellow]
    let colorNames: [String] = ["RED", "BLUE", "GREEN", "YLW"]

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            switch phase {
            case .start:
                startScreen
            case .showing, .input:
                gameScreen
            case .gameOver:
                gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("MemorySeq")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            Text("Watch the sequence,\nthen repeat it!")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Start Game") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .foregroundColor(.primary)
            .neumorphicCard(radius: 22)
        }
        .padding(28)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SEQUENCE \(sequence.count)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text("Score: \(score)")
                            .font(.headline.bold())
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < lives ? "heart.fill" : "heart")
                                .foregroundColor(i < lives ? .red : .gray.opacity(0.4))
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(phase == .showing ? "WATCH" : "TAP!")
                            .font(.caption.bold())
                            .foregroundColor(phase == .showing ? .orange : .green)
                        Text("SEED: #\(seedInt)")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .neumorphicCard(radius: 16)
            .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    colorButton(index: i)
                }
            }
            .padding(.horizontal, 16)
            .disabled(phase == .showing)
        }
    }

    func colorButton(index: Int) -> some View {
        let isFlashing = showFlash == index
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(colors[index].opacity(isFlashing ? 0.75 : 0.18))
            Text(colorNames[index])
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(colors[index].opacity(isFlashing ? 1.0 : 0.6))
        }
        .frame(height: 130)
        .neumorphicCard(radius: 16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors[index].opacity(isFlashing ? 0.8 : 0.0), lineWidth: 2.5)
        )
        .scaleEffect(isFlashing ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFlashing)
        .onTapGesture {
            if phase == .input { handleTap(index) }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("Game Over")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.red)
            Text("Score: \(score)")
                .font(.title2.bold())
                .foregroundColor(.primary)
            Text("Sequence length: \(sequence.count)")
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
            Button("Play Again") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .foregroundColor(.primary)
            .neumorphicCard(radius: 22)
        }
        .padding(28)
        .neumorphicCard(radius: 24)
        .padding(32)
    }

    func startGame() {
        seedInt += 1
        rng = MmSqLCG(seed: seedInt)
        sequence = []
        playerIndex = 0
        lives = 3
        score = 0
        showFlash = -1
        addStep()
    }

    func addStep() {
        sequence.append(rng.nextInt(4))
        playerIndex = 0
        phase = .showing
        showSequence()
    }

    func showSequence() {
        var delay = 0.4
        for btn in sequence {
            let capturedBtn = btn
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showFlash = capturedBtn
            }
            delay += 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + delay - 0.14) {
                showFlash = -1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            phase = .input
        }
    }

    func handleTap(_ index: Int) {
        showFlash = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            showFlash = -1
        }
        if index == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex == sequence.count {
                score += sequence.count
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    addStep()
                }
            }
        } else {
            lives -= 1
            if lives <= 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    phase = .gameOver
                }
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    playerIndex = 0
                    phase = .showing
                    showSequence()
                }
            }
        }
    }
}

#Preview { MemorySeqViewV3() }

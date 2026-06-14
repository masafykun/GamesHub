import SwiftUI

enum MmSqPhaseV2 {
    case start, showing, input, gameOver
}

struct MemorySeqViewV2: View {
    @State private var phase: MmSqPhaseV2 = .start
    @State private var sequence: [Int] = []
    @State private var playerIndex: Int = 0
    @State private var lives: Int = 3
    @State private var showFlash: Int = -1
    @State private var score: Int = 0
    @State private var recentResults: [Bool] = []
    @State private var flashDuration: Double = 0.6

    let colors: [Color] = [.red, .blue, .green, .yellow]
    let colorNames: [String] = ["R", "B", "G", "Y"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.35), Color(red: 0.2, green: 0.05, blue: 0.25)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

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
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Watch the sequence,\nthen repeat it!")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            Button("Start Game") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SEQ \(sequence.count)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Text("Score \(score)")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < lives ? "heart.fill" : "heart")
                            .foregroundColor(i < lives ? .pink : .white.opacity(0.3))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(speedLabel)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Text(phase == .showing ? "Watch" : "Tap!")
                        .font(.headline.bold())
                        .foregroundColor(phase == .showing ? .yellow : .green)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 16)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(0..<4, id: \.self) { i in
                    colorButton(index: i)
                }
            }
            .padding(.horizontal, 16)
            .disabled(phase == .showing)
        }
    }

    var speedLabel: String {
        if flashDuration < 0.4 { return "Fast" }
        if flashDuration < 0.55 { return "Medium" }
        return "Normal"
    }

    func colorButton(index: Int) -> some View {
        let isFlashing = showFlash == index
        return ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(colors[index].opacity(isFlashing ? 0.85 : 0.25))
            RoundedRectangle(cornerRadius: 16)
                .stroke(colors[index].opacity(isFlashing ? 1.0 : 0.5), lineWidth: isFlashing ? 3 : 1.5)
        }
        .frame(height: 130)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(isFlashing ? 0.6 : 0.15), lineWidth: 1))
        .scaleEffect(isFlashing ? 1.07 : 1.0)
        .shadow(color: isFlashing ? colors[index].opacity(0.6) : .clear, radius: 12)
        .animation(.easeInOut(duration: 0.15), value: isFlashing)
        .onTapGesture {
            if phase == .input { handleTap(index) }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 22) {
            Text("Game Over")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.pink)
            Text("Score: \(score)")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Length: \(sequence.count)")
                .foregroundColor(.white.opacity(0.6))
            Button("Play Again") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
            .foregroundColor(.white)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    func startGame() {
        sequence = []
        playerIndex = 0
        lives = 3
        score = 0
        showFlash = -1
        recentResults = []
        flashDuration = 0.6
        addStep()
    }

    func addStep() {
        sequence.append(Int.random(in: 0..<4))
        playerIndex = 0
        phase = .showing
        showSequence()
    }

    func adaptDifficulty(passed: Bool) {
        recentResults.append(passed)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 {
            let trueCount = recentResults.filter { $0 }.count
            if trueCount > 4 {
                flashDuration = max(0.3, flashDuration * 0.82)
            }
        }
    }

    func showSequence() {
        let step = flashDuration
        var delay = 0.35
        for btn in sequence {
            let capturedBtn = btn
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showFlash = capturedBtn
            }
            delay += step
            DispatchQueue.main.asyncAfter(deadline: .now() + delay - 0.12) {
                showFlash = -1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            phase = .input
        }
    }

    func handleTap(_ index: Int) {
        showFlash = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showFlash = -1
        }
        if index == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex == sequence.count {
                score += sequence.count
                adaptDifficulty(passed: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    addStep()
                }
            }
        } else {
            adaptDifficulty(passed: false)
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

#Preview { MemorySeqViewV2() }

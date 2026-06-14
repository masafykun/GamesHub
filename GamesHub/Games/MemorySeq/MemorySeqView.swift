import SwiftUI

enum MmSqPhase {
    case start, showing, input, gameOver
}

struct MemorySeqView: View {
    @State private var phase: MmSqPhase = .start
    @State private var sequence: [Int] = []
    @State private var playerIndex: Int = 0
    @State private var lives: Int = 3
    @State private var flashIndex: Int = -1
    @State private var score: Int = 0
    @State private var showFlash: Int = -1

    let colors: [Color] = [.red, .blue, .green, .yellow]
    let labels: [String] = ["", "", "", ""]
    let positions: [(String, String)] = [("Top Left", "Top Right"), ("Bottom Left", "Bottom Right")]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
        VStack(spacing: 30) {
            Text("MemorySeq")
                .font(.largeTitle.bold())
                .foregroundColor(.white)
            Text("Watch the sequence,\nthen repeat it!")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Button("Start Game") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
    }

    var gameScreen: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Seq: \(sequence.count)")
                    .foregroundColor(.white)
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < lives ? "heart.fill" : "heart")
                            .foregroundColor(i < lives ? .red : .gray)
                    }
                }
                Spacer()
                Text("Score: \(score)")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(.horizontal, 24)

            if phase == .showing {
                Text("Watch...")
                    .foregroundColor(.yellow)
                    .font(.subheadline)
            } else {
                Text("Your turn!")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    colorButton(index: i)
                }
            }
            .padding(.horizontal, 32)
            .disabled(phase == .showing)
        }
    }

    func colorButton(index: Int) -> some View {
        let isFlashing = showFlash == index
        return RoundedRectangle(cornerRadius: 16)
            .fill(colors[index].opacity(isFlashing ? 1.0 : 0.4))
            .frame(height: 130)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(colors[index], lineWidth: isFlashing ? 4 : 1)
            )
            .scaleEffect(isFlashing ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFlashing)
            .onTapGesture {
                if phase == .input {
                    handleTap(index)
                }
            }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over")
                .font(.largeTitle.bold())
                .foregroundColor(.red)
            Text("Score: \(score)")
                .font(.title2)
                .foregroundColor(.white)
            Text("Sequence length: \(sequence.count)")
                .foregroundColor(.gray)
            Button("Play Again") {
                startGame()
            }
            .font(.title2.bold())
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.blue)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
    }

    func startGame() {
        sequence = []
        playerIndex = 0
        lives = 3
        score = 0
        showFlash = -1
        addStep()
    }

    func addStep() {
        sequence.append(Int.random(in: 0..<4))
        playerIndex = 0
        phase = .showing
        showSequence()
    }

    func showSequence() {
        var delay = 0.4
        for (i, btn) in sequence.enumerated() {
            let capturedBtn = btn
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                showFlash = capturedBtn
            }
            delay += 0.6
            DispatchQueue.main.asyncAfter(deadline: .now() + delay - 0.15) {
                showFlash = -1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            phase = .input
        }
    }

    func handleTap(_ index: Int) {
        showFlash = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
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

#Preview { MemorySeqView() }

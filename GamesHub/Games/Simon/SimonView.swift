import SwiftUI

enum SimonColor: Int, CaseIterable {
    case red = 0
    case blue = 1
    case green = 2
    case yellow = 3

    var color: Color {
        switch self {
        case .red:    return Color(red: 0.9, green: 0.2, blue: 0.2)
        case .blue:   return Color(red: 0.2, green: 0.4, blue: 0.9)
        case .green:  return Color(red: 0.2, green: 0.75, blue: 0.3)
        case .yellow: return Color(red: 0.95, green: 0.8, blue: 0.1)
        }
    }

    var dimColor: Color {
        switch self {
        case .red:    return Color(red: 0.4, green: 0.1, blue: 0.1)
        case .blue:   return Color(red: 0.1, green: 0.15, blue: 0.4)
        case .green:  return Color(red: 0.1, green: 0.3, blue: 0.12)
        case .yellow: return Color(red: 0.4, green: 0.33, blue: 0.04)
        }
    }

    var label: String {
        switch self {
        case .red:    return "Red"
        case .blue:   return "Blue"
        case .green:  return "Green"
        case .yellow: return "Yellow"
        }
    }

    var brightColor: Color {
        switch self {
        case .red:    return Color(red: 1.0, green: 0.35, blue: 0.35)
        case .blue:   return Color(red: 0.35, green: 0.6, blue: 1.0)
        case .green:  return Color(red: 0.35, green: 1.0, blue: 0.45)
        case .yellow: return Color(red: 1.0, green: 0.95, blue: 0.3)
        }
    }
}

enum SimonGamePhase {
    case idle
    case showingSequence
    case playerInput
    case gameOver
}

struct SimonView: View {
    @State private var sequence: [SimonColor] = []
    @State private var playerIndex: Int = 0
    @State private var phase: SimonGamePhase = .idle
    @State private var activeButton: SimonColor? = nil
    @State private var score: Int = 0
    @State private var highScore: Int = 0
    @State private var flashIndex: Int = 0
    @State private var flashTimer: Timer? = nil

    var body: some View {
        ZStack {
            Color(red: 0.12, green: 0.12, blue: 0.18)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 6) {
                    Text("Simon Says")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    HStack(spacing: 24) {
                        VStack(spacing: 2) {
                            Text("ROUND")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)
                            Text("\(sequence.count)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 1, height: 36)
                        VStack(spacing: 2) {
                            Text("BEST")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                                .tracking(2)
                            Text("\(highScore)")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.1))
                        }
                    }
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.14))
                        .frame(width: 300, height: 300)
                        .shadow(color: .black.opacity(0.5), radius: 16, x: 0, y: 8)

                    LazyVGrid(columns: [GridItem(.fixed(130)), GridItem(.fixed(130))], spacing: 16) {
                        ForEach(SimonColor.allCases, id: \.rawValue) { simonColor in
                            SimonButtonView(
                                simonColor: simonColor,
                                isActive: activeButton == simonColor,
                                isPlayerPhase: phase == .playerInput
                            ) {
                                handlePlayerTap(simonColor)
                            }
                        }
                    }
                    .padding(16)

                    if phase == .showingSequence {
                        RoundedRectangle(cornerRadius: 28)
                            .fill(Color.clear)
                            .frame(width: 300, height: 300)
                            .contentShape(Rectangle())
                    }
                }

                statusView

                actionButton
            }
            .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch phase {
        case .idle:
            Text("Tap Start to play")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        case .showingSequence:
            Text("Watch the sequence...")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        case .playerInput:
            Text("Your turn! \(playerIndex) / \(sequence.count)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.5))
        case .gameOver:
            VStack(spacing: 4) {
                Text("Game Over!")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 0.9, green: 0.3, blue: 0.3))
                Text("You reached round \(sequence.count)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if phase == .idle || phase == .gameOver {
            Button(action: startGame) {
                Text(phase == .idle ? "Start" : "Play Again")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 180, height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.3, green: 0.5, blue: 1.0), Color(red: 0.2, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.2, green: 0.35, blue: 0.85).opacity(0.5), radius: 10, x: 0, y: 5)
            }
        } else {
            Color.clear.frame(height: 52)
        }
    }

    private func startGame() {
        sequence = []
        playerIndex = 0
        score = 0
        phase = .idle
        addToSequence()
    }

    private func addToSequence() {
        let next = SimonColor.allCases.randomElement()!
        sequence.append(next)
        playerIndex = 0
        phase = .showingSequence
        flashIndex = 0
        startFlashSequence()
    }

    private func startFlashSequence() {
        flashTimer?.invalidate()
        flashTimer = nil
        flashIndex = 0
        showNextFlash()
    }

    private func showNextFlash() {
        guard flashIndex < sequence.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                activeButton = nil
                phase = .playerInput
            }
            return
        }

        let color = sequence[flashIndex]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeButton = color
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                activeButton = nil
                flashIndex += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    showNextFlash()
                }
            }
        }
    }

    private func handlePlayerTap(_ color: SimonColor) {
        guard phase == .playerInput else { return }

        activeButton = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeButton = nil
        }

        if color == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex == sequence.count {
                score = sequence.count
                if score > highScore { highScore = score }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    addToSequence()
                }
            }
        } else {
            if sequence.count > highScore { highScore = sequence.count }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                phase = .gameOver
            }
        }
    }
}

struct SimonButtonView: View {
    let simonColor: SimonColor
    let isActive: Bool
    let isPlayerPhase: Bool
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(isActive || isPressed ? simonColor.color : simonColor.dimColor)
            .frame(width: 130, height: 130)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        isActive || isPressed
                            ? simonColor.color.opacity(0.8)
                            : simonColor.color.opacity(0.2),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: isActive || isPressed
                    ? simonColor.color.opacity(0.7)
                    : .clear,
                radius: isActive || isPressed ? 20 : 0,
                x: 0, y: 0
            )
            .scaleEffect(isActive || isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isActive)
            .animation(.easeInOut(duration: 0.08), value: isPressed)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isPlayerPhase else { return }
                        if !isPressed {
                            isPressed = true
                            onTap()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

#Preview {
    SimonView()
}

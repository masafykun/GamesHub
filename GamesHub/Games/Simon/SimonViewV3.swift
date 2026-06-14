import SwiftUI

// MARK: - Color Enum (V3)

enum SimonV3Color: Int, CaseIterable {
    case red = 0
    case blue = 1
    case green = 2
    case yellow = 3

    var brightColor: Color {
        switch self {
        case .red:    return Color(red: 0.92, green: 0.25, blue: 0.25)
        case .blue:   return Color(red: 0.22, green: 0.45, blue: 0.92)
        case .green:  return Color(red: 0.18, green: 0.78, blue: 0.32)
        case .yellow: return Color(red: 0.96, green: 0.82, blue: 0.12)
        }
    }

    var softColor: Color {
        switch self {
        case .red:    return Color(red: 0.88, green: 0.60, blue: 0.60)
        case .blue:   return Color(red: 0.60, green: 0.70, blue: 0.90)
        case .green:  return Color(red: 0.58, green: 0.84, blue: 0.64)
        case .yellow: return Color(red: 0.95, green: 0.92, blue: 0.62)
        }
    }

    var glowColor: Color {
        switch self {
        case .red:    return Color(red: 0.92, green: 0.25, blue: 0.25).opacity(0.6)
        case .blue:   return Color(red: 0.22, green: 0.45, blue: 0.92).opacity(0.6)
        case .green:  return Color(red: 0.18, green: 0.78, blue: 0.32).opacity(0.6)
        case .yellow: return Color(red: 0.96, green: 0.82, blue: 0.12).opacity(0.6)
        }
    }

    var label: String {
        switch self {
        case .red:    return "R"
        case .blue:   return "B"
        case .green:  return "G"
        case .yellow: return "Y"
        }
    }
}

// MARK: - Game Phase (V3)

enum SimonV3Phase {
    case idle
    case showingSequence
    case playerInput
    case gameOver
}

// MARK: - LCG Generator

struct SimonLCG {
    private var state: UInt64

    init(seed: Int) {
        var s = UInt64(seed)
        s = s &* 6364136223846793005 &+ 1442695040888963407
        self.state = s
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextColor() -> SimonV3Color {
        let val = next() % 4
        return SimonV3Color(rawValue: Int(val)) ?? .red
    }
}

// MARK: - Button View (V3)

struct SimonV3ButtonView: View {
    let simonColor: SimonV3Color
    let isActive: Bool
    let isPlayerPhase: Bool
    let onTap: () -> Void

    @State private var isPressed: Bool = false

    private var effectiveActive: Bool { isActive || isPressed }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(.systemGray6))
                .shadow(
                    color: effectiveActive
                        ? simonColor.glowColor
                        : Color(.systemGray4).opacity(0.8),
                    radius: effectiveActive ? 14 : 6,
                    x: effectiveActive ? 0 : 4,
                    y: effectiveActive ? 0 : 4
                )
                .shadow(
                    color: effectiveActive ? .clear : .white.opacity(0.85),
                    radius: 6,
                    x: -4,
                    y: -4
                )

            RoundedRectangle(cornerRadius: 22)
                .fill(
                    effectiveActive
                        ? simonColor.brightColor
                        : simonColor.softColor.opacity(0.35)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(
                            effectiveActive
                                ? simonColor.brightColor.opacity(0.9)
                                : simonColor.softColor.opacity(0.5),
                            lineWidth: effectiveActive ? 2.5 : 1.5
                        )
                )

            Text(simonColor.label)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(
                    effectiveActive
                        ? .white
                        : simonColor.softColor.opacity(0.7)
                )
        }
        .frame(width: 130, height: 130)
        .scaleEffect(effectiveActive ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isActive)
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

// MARK: - Main View

struct SimonViewV3: View {
    @State var seedInt: Int = 1

    @State private var sequence: [SimonV3Color] = []
    @State private var playerIndex: Int = 0
    @State private var phase: SimonV3Phase = .idle
    @State private var activeButton: SimonV3Color? = nil
    @State private var highScore: Int = 0
    @State private var flashIndex: Int = 0
    @State private var lcg: SimonLCG = SimonLCG(seed: 1)

    var currentRound: Int { sequence.count }

    var body: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                headerView

                seedBadge

                gridView

                statusView

                actionButton
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Simon Says")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("V3 · Procedural")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
            }

            Spacer()

            HStack(spacing: 16) {
                scoreChip(label: "ROUND", value: currentRound)
                scoreChip(label: "BEST", value: highScore)
            }
        }
        .padding(.horizontal, 4)
    }

    private func scoreChip(label: String, value: Int) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(1.5)
            Text("\(value)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(minWidth: 52)
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .neumorphicCard(radius: 14)
    }

    // MARK: Seed Badge

    private var seedBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "dice.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            Text("SEED: #\(seedInt)")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 18)
        .neumorphicCard(radius: 20)
    }

    // MARK: Grid

    private var gridView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(Color(.systemGray6))
                .shadow(color: .white.opacity(0.85), radius: 10, x: -6, y: -6)
                .shadow(color: Color(.systemGray4).opacity(0.8), radius: 10, x: 6, y: 6)
                .frame(width: 308, height: 308)

            LazyVGrid(
                columns: [GridItem(.fixed(130)), GridItem(.fixed(130))],
                spacing: 16
            ) {
                ForEach(SimonV3Color.allCases, id: \.rawValue) { color in
                    SimonV3ButtonView(
                        simonColor: color,
                        isActive: activeButton == color,
                        isPlayerPhase: phase == .playerInput
                    ) {
                        handlePlayerTap(color)
                    }
                }
            }
            .padding(16)

            // Block taps during sequence display
            if phase == .showingSequence {
                RoundedRectangle(cornerRadius: 30)
                    .fill(Color.clear)
                    .frame(width: 308, height: 308)
                    .contentShape(Rectangle())
            }
        }
    }

    // MARK: Status

    @ViewBuilder
    private var statusView: some View {
        Group {
            switch phase {
            case .idle:
                Text("Tap Start to begin")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)

            case .showingSequence:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.secondary)
                    Text("Watch the sequence…")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.secondary)
                }

            case .playerInput:
                Text("Your turn!  \(playerIndex) / \(sequence.count)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.72, blue: 0.42))

            case .gameOver:
                VStack(spacing: 4) {
                    Text("Game Over!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(Color(red: 0.85, green: 0.22, blue: 0.22))
                    Text("Reached round \(sequence.count) with seed #\(seedInt)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
    }

    // MARK: Action Button

    @ViewBuilder
    private var actionButton: some View {
        if phase == .idle || phase == .gameOver {
            Button(action: startGame) {
                HStack(spacing: 8) {
                    Image(systemName: phase == .idle ? "play.fill" : "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                    Text(phase == .idle ? "Start" : "Play Again")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                .foregroundColor(.primary)
                .frame(width: 190, height: 52)
                .neumorphicCard(radius: 26)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(height: 52)
        }
    }

    // MARK: - Game Logic

    private func startGame() {
        seedInt += 1
        lcg = SimonLCG(seed: seedInt)
        sequence = []
        playerIndex = 0
        phase = .idle
        addToSequence()
    }

    private func addToSequence() {
        let next = lcg.nextColor()
        sequence.append(next)
        playerIndex = 0
        phase = .showingSequence
        flashIndex = 0
        showNextFlash()
    }

    private func showNextFlash() {
        guard flashIndex < sequence.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
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

    private func handlePlayerTap(_ color: SimonV3Color) {
        guard phase == .playerInput else { return }

        activeButton = color
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            activeButton = nil
        }

        if color == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex == sequence.count {
                if sequence.count > highScore { highScore = sequence.count }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                    addToSequence()
                }
            }
        } else {
            if sequence.count > highScore { highScore = sequence.count }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                phase = .gameOver
            }
        }
    }
}


#Preview {
    SimonViewV3()
}

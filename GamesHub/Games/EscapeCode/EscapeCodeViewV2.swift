import SwiftUI

// MARK: - Models

enum EsCdV2Clue {
    case coloredShapes, emojiIcons, numberPattern
}

struct EsCdV2Room {
    let number: Int
    let clueType: EsCdV2Clue
    let pin: [Int]
    let clues: [String]
    let hint: String
}

enum EsCdV2Phase {
    case start, playing, complete
}

// MARK: - Glassmorphism View

struct EscapeCodeViewV2: View {
    @State private var phase: EsCdV2Phase = .start
    @State private var currentRoom: Int = 0
    @State private var enteredDigits: [Int] = []
    @State private var shakeTrigger: Int = 0
    @State private var doorsOpen: Bool = false
    @State private var recentResults: [Bool] = []
    @State private var difficultyLevel: Double = 1.0

    private let rooms: [EsCdV2Room] = [
        EsCdV2Room(number: 1, clueType: .coloredShapes, pin: [3,1,4,2],
                   clues: ["🔴=3  🔵=1  🟢=4  🟡=2"], hint: "Color order: Red Blue Green Yellow"),
        EsCdV2Room(number: 2, clueType: .emojiIcons, pin: [7,2,5,9],
                   clues: ["🌟=7  🌊=2  🔥=5  🌙=9"], hint: "Stars, waves, flames, crescent"),
        EsCdV2Room(number: 3, clueType: .numberPattern, pin: [1,4,9,6],
                   clues: ["1²  2²  3²  4²  →  last digits"], hint: "Perfect squares, single digit"),
        EsCdV2Room(number: 4, clueType: .coloredShapes, pin: [8,0,3,7],
                   clues: ["🔴=8  ⚫=0  🟢=3  🔵=7"], hint: "Eight zero three seven"),
        EsCdV2Room(number: 5, clueType: .emojiIcons, pin: [2,6,1,5],
                   clues: ["🐉=2  🦊=6  🦋=1  🐬=5"], hint: "Dragon Fox Butterfly Dolphin")
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.25), Color(red: 0.05, green: 0.15, blue: 0.3)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("🔐").font(.system(size: 72))
            Text("ESCAPE CODE").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Decode visual clues.\nCrack the PIN.\nEscape all 5 rooms.").multilineTextAlignment(.center).foregroundColor(.white.opacity(0.7))
            Text("Adaptive difficulty enabled").font(.caption).foregroundColor(.cyan.opacity(0.8))
            Spacer()
            Button("BEGIN") { startGame() }
                .font(.title2.bold()).foregroundColor(.white)
                .padding(.horizontal, 48).padding(.vertical, 16)
                .background(.ultraThinMaterial).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }.padding()
    }

    var gameScreen: some View {
        let room = rooms[currentRoom]
        return VStack(spacing: 14) {
            // Header card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROOM \(room.number) OF 5").font(.caption.bold()).foregroundColor(.white.opacity(0.6))
                    Text("DIFFICULTY: \(String(format: "%.1f", difficultyLevel))x").font(.caption2).foregroundColor(.cyan.opacity(0.8))
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        ZStack {
                            Circle().fill(i < enteredDigits.count ? Color.cyan : Color.white.opacity(0.2)).frame(width: 36, height: 36)
                            if i < enteredDigits.count {
                                Text("\(enteredDigits[i])").font(.headline.bold()).foregroundColor(.black)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            // Door
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.05)).frame(height: 110)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.2), lineWidth: 1))
                if doorsOpen {
                    HStack(spacing: 16) {
                        Text("🚪").font(.system(size: 52)).offset(x: -20)
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 36)).foregroundColor(.green)
                    }
                } else {
                    Text("🚪").font(.system(size: 52))
                }
            }.padding(.horizontal)

            // Clue card
            VStack(alignment: .leading, spacing: 10) {
                Label("CLUES", systemImage: "eye.fill").font(.caption.bold()).foregroundColor(.cyan)
                ForEach(room.clues, id: \.self) { clue in
                    Text(clue).font(.system(.body, design: .monospaced)).foregroundColor(.white)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Text("Hint: \(room.hint)").font(.caption).foregroundColor(.white.opacity(0.5)).italic()
            }
            .padding()
            .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal)

            Spacer()

            // Keypad
            glassKeypad
        }
        .modifier(EsCdV2ShakeModifier(trigger: shakeTrigger))
    }

    var glassKeypad: some View {
        VStack(spacing: 8) {
            let rows = [[1,2,3],[4,5,6],[7,8,9]]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { digit in glassKey(digit) }
                }
            }
            HStack(spacing: 8) {
                Button("CLR") { enteredDigits.removeAll() }
                    .frame(maxWidth: .infinity).frame(height: 52).font(.headline.bold()).foregroundColor(.red.opacity(0.9))
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
                glassKey(0)
                Button("GO") { checkPin() }
                    .frame(maxWidth: .infinity).frame(height: 52).font(.headline.bold()).foregroundColor(.cyan)
                    .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.cyan.opacity(0.4), lineWidth: 1))
            }
        }.padding(.horizontal).padding(.bottom)
    }

    func glassKey(_ digit: Int) -> some View {
        Button("\(digit)") {
            if enteredDigits.count < 4 { enteredDigits.append(digit) }
        }
        .frame(maxWidth: .infinity).frame(height: 52).font(.title2.bold()).foregroundColor(.white)
        .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.2), lineWidth: 1))
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🎊").font(.system(size: 80))
            Text("FREEDOM!").font(.largeTitle.bold()).foregroundColor(.white)
            Text("All 5 rooms escaped!").foregroundColor(.white.opacity(0.7))
            Text("Final difficulty: \(String(format: "%.1f", difficultyLevel))x").font(.subheadline).foregroundColor(.cyan)
            Spacer()
            Button("ESCAPE AGAIN") { startGame() }
                .font(.title2.bold()).foregroundColor(.white)
                .padding(.horizontal, 40).padding(.vertical, 16)
                .background(.ultraThinMaterial).clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
        }.padding()
    }

    // MARK: - Logic

    func startGame() {
        currentRoom = 0; enteredDigits = []; doorsOpen = false
        recentResults = []; difficultyLevel = 1.0; phase = .playing
    }

    func checkPin() {
        let room = rooms[currentRoom]
        let correct = enteredDigits == room.pin
        recentResults.append(correct)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            difficultyLevel = min(difficultyLevel * 1.2, 3.0)
        }
        if correct {
            doorsOpen = true
            let delay = max(0.3, 1.0 / difficultyLevel)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if currentRoom < rooms.count - 1 {
                    currentRoom += 1; enteredDigits = []; doorsOpen = false
                } else { phase = .complete }
            }
        } else {
            shakeTrigger += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { enteredDigits.removeAll() }
        }
    }
}

// MARK: - Shake

struct EsCdV2ShakeModifier: ViewModifier {
    let trigger: Int
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content.offset(x: offset)
            .onChange(of: trigger) { _ in
                withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) { offset = 10 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { offset = 0 }
            }
    }
}

#Preview { EscapeCodeViewV2() }

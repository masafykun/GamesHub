import SwiftUI

// MARK: - LCG Random Number Generator

struct EsCdLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Models

struct EsCdV3Room {
    let number: Int
    let pin: [Int]
    let clueLines: [String]
    let colorNames: [String]
    let colorValues: [Color]
}

enum EsCdV3Phase {
    case start, playing, complete
}

// MARK: - Neumorphism View

struct EscapeCodeViewV3: View {
    @State private var phase: EsCdV3Phase = .start
    @State private var seedInt: Int = 1
    @State private var currentRoom: Int = 0
    @State private var enteredDigits: [Int] = []
    @State private var shakeTrigger: Int = 0
    @State private var doorsOpen: Bool = false
    @State private var rooms: [EsCdV3Room] = []

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing:
                if rooms.isEmpty {
                    ProgressView()
                } else {
                    gameScreen
                }
            case .complete: completeScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("🔓").font(.system(size: 72))
            Text("ESCAPE CODE").font(.largeTitle.bold()).foregroundColor(.primary)
            Text("Decode seeded clues.\nCrack the PIN. Escape 5 rooms.").multilineTextAlignment(.center).foregroundColor(.secondary)
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Spacer()
            Button("START") { beginGame() }
                .font(.title2.bold()).foregroundColor(.primary)
                .padding(.horizontal, 48).padding(.vertical, 16)
                .neumorphicCard(radius: 24)
        }.padding()
    }

    var gameScreen: some View {
        let room = rooms[currentRoom]
        return VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROOM \(room.number)/5").font(.headline.bold()).foregroundColor(.primary)
                    Text("SEED: #\(seedInt)").font(.system(.caption2, design: .monospaced)).foregroundColor(.gray)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        ZStack {
                            Circle()
                                .fill(i < enteredDigits.count ? Color.blue.opacity(0.15) : Color(.systemGray5))
                                .frame(width: 38, height: 38)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                            if i < enteredDigits.count {
                                Text("\(enteredDigits[i])").font(.headline.bold()).foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            // Door
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)).frame(height: 110)
                    .shadow(color: .black.opacity(0.15), radius: 6, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.85), radius: 6, x: -4, y: -4)
                if doorsOpen {
                    HStack(spacing: 16) {
                        Text("🚪").font(.system(size: 52)).offset(x: -20)
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundColor(.green)
                    }
                } else {
                    Text("🚪").font(.system(size: 52))
                }
            }.padding(.horizontal)

            // Clue panel
            VStack(alignment: .leading, spacing: 10) {
                Text("CLUES").font(.caption.bold()).foregroundColor(.secondary)

                // Color shape clues
                HStack(spacing: 10) {
                    ForEach(0..<4, id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(room.colorValues[i])
                                .frame(width: 36, height: 36)
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 2, y: 2)
                                .shadow(color: .white.opacity(0.6), radius: 3, x: -2, y: -2)
                            Text(room.colorNames[i]).font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Text("= \(room.pin.map { "\($0)" }.joined())").font(.system(.title3, design: .monospaced)).foregroundColor(.primary).bold()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 3, y: 3)
                .shadow(color: .white.opacity(0.7), radius: 4, x: -3, y: -3)

                ForEach(room.clueLines, id: \.self) { line in
                    Text(line).font(.system(.subheadline, design: .monospaced)).foregroundColor(.primary)
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray5)).clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.08), radius: 3, x: 2, y: 2)
                        .shadow(color: .white.opacity(0.8), radius: 3, x: -2, y: -2)
                }
            }
            .padding()
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            Spacer()
            neuKeypad
        }
        .modifier(EsCdV3ShakeModifier(trigger: shakeTrigger))
    }

    var neuKeypad: some View {
        VStack(spacing: 8) {
            let rows = [[1,2,3],[4,5,6],[7,8,9]]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { digit in neuKey(digit) }
                }
            }
            HStack(spacing: 8) {
                Button("CLR") { enteredDigits.removeAll() }
                    .frame(maxWidth: .infinity).frame(height: 52).font(.headline.bold()).foregroundColor(.red)
                    .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
                neuKey(0)
                Button("ENTER") { checkPin() }
                    .frame(maxWidth: .infinity).frame(height: 52).font(.headline.bold()).foregroundColor(.blue)
                    .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
            }
        }.padding(.horizontal).padding(.bottom)
    }

    func neuKey(_ digit: Int) -> some View {
        Button("\(digit)") {
            if enteredDigits.count < 4 { enteredDigits.append(digit) }
        }
        .frame(maxWidth: .infinity).frame(height: 52).font(.title2.bold()).foregroundColor(.primary)
        .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 4, x: 3, y: 3)
        .shadow(color: .white.opacity(0.9), radius: 4, x: -3, y: -3)
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🏆").font(.system(size: 80))
            Text("ESCAPED!").font(.largeTitle.bold()).foregroundColor(.primary)
            Text("All 5 rooms cleared").foregroundColor(.secondary)
            Text("SEED: #\(seedInt)").font(.system(.subheadline, design: .monospaced)).foregroundColor(.gray)
            Spacer()
            Button("NEW GAME") { seedInt += 1; beginGame() }
                .font(.title2.bold()).foregroundColor(.primary)
                .padding(.horizontal, 48).padding(.vertical, 16)
                .neumorphicCard(radius: 24)
        }.padding()
    }

    // MARK: - Generation

    func beginGame() {
        rooms = generateRooms(seed: seedInt)
        currentRoom = 0; enteredDigits = []; doorsOpen = false; phase = .playing
    }

    func generateRooms(seed: Int) -> [EsCdV3Room] {
        var lcg = EsCdLCG(seed: seed)
        let allColors: [(String, Color)] = [
            ("RED", .red), ("BLU", .blue), ("GRN", .green), ("YLW", .yellow),
            ("PRP", .purple), ("ORG", .orange), ("PNK", .pink), ("TEL", .teal)
        ]
        let symbols = ["★", "♦", "●", "▲", "◆", "♠", "■", "✦"]

        return (0..<5).map { roomIdx in
            var pin: [Int] = []
            for _ in 0..<4 { pin.append(lcg.nextInt(10)) }

            var colorIndices: [Int] = []
            var used: Set<Int> = []
            while colorIndices.count < 4 {
                let idx = lcg.nextInt(allColors.count)
                if !used.contains(idx) { colorIndices.append(idx); used.insert(idx) }
            }

            let colorNames = colorIndices.map { allColors[$0].0 }
            let colorValues = colorIndices.map { allColors[$0].1 }

            let symPairs = (0..<4).map { i in "\(symbols[lcg.nextInt(symbols.count)])=\(pin[i])" }
            let clueLines = [symPairs.joined(separator: "  ")]

            return EsCdV3Room(number: roomIdx + 1, pin: pin, clueLines: clueLines,
                              colorNames: colorNames, colorValues: colorValues)
        }
    }

    // MARK: - Logic

    func checkPin() {
        guard !rooms.isEmpty else { return }
        let room = rooms[currentRoom]
        if enteredDigits == room.pin {
            doorsOpen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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

struct EsCdV3ShakeModifier: ViewModifier {
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

#Preview { EscapeCodeViewV3() }

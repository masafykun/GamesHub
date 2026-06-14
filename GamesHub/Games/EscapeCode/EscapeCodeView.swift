import SwiftUI

// MARK: - Models

enum EsCdClueType {
    case coloredShapes, emojiIcons, numberPattern
}

struct EsCdRoom {
    let number: Int
    let clueType: EsCdClueType
    let pin: [Int]
    let clues: [String]
}

enum EsCdPhase {
    case start, playing, success, failed, complete
}

// MARK: - Main View

struct EscapeCodeView: View {
    @State private var phase: EsCdPhase = .start
    @State private var currentRoom: Int = 0
    @State private var enteredDigits: [Int] = []
    @State private var shakeTrigger: Int = 0
    @State private var doorsOpen: Bool = false

    private let rooms: [EsCdRoom] = [
        EsCdRoom(number: 1, clueType: .coloredShapes, pin: [3,1,4,2],
                 clues: ["Red=1 Blue=2 Green=3 Yellow=4", "🟥🟦🟩🟨", "△=3  ○=1  □=4  ◇=2"]),
        EsCdRoom(number: 2, clueType: .emojiIcons, pin: [7,2,5,9],
                 clues: ["🌟=7  🌊=2  🔥=5  🌙=9", "Star Wave Fire Moon", "Count the points: ★7 ~2 🔥5 ☽9"]),
        EsCdRoom(number: 3, clueType: .numberPattern, pin: [1,4,9,6],
                 clues: ["1² = ?  2² = ?  3² = ?  4² = ?", "Squares: 1, 4, 9, 16→6", "Pattern: 1·1, 2·2, 3·3, 4·4"]),
        EsCdRoom(number: 4, clueType: .coloredShapes, pin: [8,0,3,7],
                 clues: ["🔴8  ⚫0  🟢3  🔵7", "Red=8  Black=0  Green=3  Blue=7", "Circles: R8 K0 G3 B7"]),
        EsCdRoom(number: 5, clueType: .emojiIcons, pin: [2,6,1,5],
                 clues: ["🐉=2  🦊=6  🦋=1  🐬=5", "Dragon Fox Butterfly Dolphin", "D2 F6 B1 D5"])
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            default: gameScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("ESCAPE CODE").font(.largeTitle.bold()).foregroundColor(.green)
            Text("Decode clues to crack the PIN\nand escape 5 rooms!").multilineTextAlignment(.center).foregroundColor(.gray)
            Button("START") {
                currentRoom = 0; enteredDigits = []; phase = .playing
            }
            .font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.green).clipShape(Capsule())
        }.padding()
    }

    var gameScreen: some View {
        let room = rooms[currentRoom]
        return VStack(spacing: 16) {
            // Header
            HStack {
                Text("ROOM \(room.number)/5").font(.headline).foregroundColor(.green)
                Spacer()
                Text(enteredDigits.map { "\($0)" }.joined(separator: " ")).font(.title2.monospaced()).foregroundColor(.white)
            }.padding(.horizontal)

            // Door graphic
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.15)).frame(height: 120)
                if doorsOpen {
                    Text("🚪").font(.system(size: 60)).offset(x: -30)
                    Image(systemName: "arrow.right.circle.fill").font(.system(size: 40)).foregroundColor(.green).offset(x: 30)
                } else {
                    Text("🚪").font(.system(size: 60))
                }
            }.padding(.horizontal)

            // Clue panel
            VStack(alignment: .leading, spacing: 8) {
                Text("CLUES").font(.caption.bold()).foregroundColor(.green.opacity(0.7))
                ForEach(room.clues, id: \.self) { clue in
                    Text(clue).font(.system(.subheadline, design: .monospaced)).foregroundColor(.white).padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.12)).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }.padding(.horizontal)

            Spacer()

            // Keypad
            keypad
        }
        .modifier(EsCdShakeModifier(trigger: shakeTrigger))
        .onAppear { doorsOpen = false }
    }

    var keypad: some View {
        VStack(spacing: 8) {
            let rows = [[1,2,3],[4,5,6],[7,8,9]]
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { digit in
                        keyButton(digit)
                    }
                }
            }
            HStack(spacing: 8) {
                Button("CLR") { enteredDigits.removeAll() }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .font(.headline).foregroundColor(.red)
                    .background(Color(white: 0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
                keyButton(0)
                Button("ENTER") { checkPin() }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .font(.headline).foregroundColor(.green)
                    .background(Color(white: 0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding(.horizontal).padding(.bottom)
    }

    func keyButton(_ digit: Int) -> some View {
        Button("\(digit)") {
            if enteredDigits.count < 4 { enteredDigits.append(digit) }
        }
        .frame(maxWidth: .infinity).frame(height: 52).font(.title2.bold())
        .foregroundColor(.white).background(Color(white: 0.18)).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Text("🎉").font(.system(size: 80))
            Text("ESCAPED!").font(.largeTitle.bold()).foregroundColor(.green)
            Text("You cracked all 5 room codes!").foregroundColor(.gray)
            Button("PLAY AGAIN") { currentRoom = 0; enteredDigits = []; doorsOpen = false; phase = .playing }
                .font(.title2.bold()).foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14)
                .background(Color.green).clipShape(Capsule())
        }
    }

    // MARK: - Logic

    func checkPin() {
        let room = rooms[currentRoom]
        if enteredDigits == room.pin {
            doorsOpen = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if currentRoom < rooms.count - 1 {
                    currentRoom += 1; enteredDigits = []; doorsOpen = false
                } else {
                    phase = .complete
                }
            }
        } else {
            shakeTrigger += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { enteredDigits.removeAll() }
        }
    }
}

// MARK: - Shake Modifier

struct EsCdShakeModifier: ViewModifier {
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

#Preview { EscapeCodeView() }

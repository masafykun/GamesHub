import SwiftUI

// MARK: - LCG

struct CrcLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - V3 Models

enum CrcV3Phase { case start, playing, complete }

struct CrcV3GridPos: Hashable {
    let row: Int, col: Int
}

enum CrcV3ComponentType { case batteryPlus, batteryMinus, led, resistor }

struct CrcV3Component {
    let pos: CrcV3GridPos
    let type: CrcV3ComponentType
}

struct CrcV3WireSegment: Hashable {
    let from: CrcV3GridPos
    let to: CrcV3GridPos
    init(from: CrcV3GridPos, to: CrcV3GridPos) {
        if from.row < to.row || (from.row == to.row && from.col < to.col) {
            self.from = from; self.to = to
        } else {
            self.from = to; self.to = from
        }
    }
}

struct CrcV3Layout {
    let components: [CrcV3Component]
    let requiredPath: [CrcV3GridPos]
}

// MARK: - CircuitViewV3

struct CircuitViewV3: View {
    @State private var phase: CrcV3Phase = .start
    @State private var wires: Set<CrcV3WireSegment> = []
    @State private var layoutIndex: Int = 0
    @State private var isComplete: Bool = false
    @State private var score: Int = 0
    @State private var dragStart: CrcV3GridPos? = nil
    @State private var seedInt: Int = 1
    @State private var currentLayout: CrcV3Layout = CrcV3Layout(components: [], requiredPath: [])
    @State private var ledGlow: Bool = false

    let gridSize = 7
    let cellSize: CGFloat = 42
    let totalLevels = 3

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
        .onAppear { generateLayout() }
    }

    // MARK: - Layout Generation

    func generateLayout() {
        var rng = CrcLCG(seed: seedInt + layoutIndex * 997)

        // Pick corner/edge positions for components
        let corners: [CrcV3GridPos] = [
            CrcV3GridPos(row: 0, col: 0), CrcV3GridPos(row: 0, col: 6),
            CrcV3GridPos(row: 6, col: 0), CrcV3GridPos(row: 6, col: 6),
            CrcV3GridPos(row: 0, col: 3), CrcV3GridPos(row: 6, col: 3),
            CrcV3GridPos(row: 3, col: 0), CrcV3GridPos(row: 3, col: 6)
        ]
        var shuffled = corners
        // Simple shuffle with LCG
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let j = rng.nextInt(i + 1)
            shuffled.swapAt(i, j)
        }

        let battPlusPos = shuffled[0]
        let resistorPos = shuffled[1]
        let ledPos = shuffled[2]
        let battMinusPos = shuffled[3]

        // Generate a path connecting all components: battPlus -> resistor -> led -> battMinus
        // Build path segments between waypoints using simple row-then-col movement
        var path: [CrcV3GridPos] = []
        func walkPath(from: CrcV3GridPos, to: CrcV3GridPos) {
            var cur = from
            // Move row first, then col
            let rowDir = to.row > cur.row ? 1 : (to.row < cur.row ? -1 : 0)
            let colDir = to.col > cur.col ? 1 : (to.col < cur.col ? -1 : 0)
            while cur.row != to.row {
                let next = CrcV3GridPos(row: cur.row + rowDir, col: cur.col)
                path.append(next)
                cur = next
            }
            while cur.col != to.col {
                let next = CrcV3GridPos(row: cur.row, col: cur.col + colDir)
                path.append(next)
                cur = next
            }
        }

        path.append(battPlusPos)
        walkPath(from: battPlusPos, to: resistorPos)
        // Remove duplicate at resistorPos if present
        if path.last != resistorPos { path.append(resistorPos) }
        walkPath(from: resistorPos, to: ledPos)
        if path.last != ledPos { path.append(ledPos) }
        walkPath(from: ledPos, to: battMinusPos)
        if path.last != battMinusPos { path.append(battMinusPos) }

        // Deduplicate consecutive duplicates
        var dedupedPath: [CrcV3GridPos] = []
        for p in path {
            if dedupedPath.last != p { dedupedPath.append(p) }
        }

        let components = [
            CrcV3Component(pos: battPlusPos, type: .batteryPlus),
            CrcV3Component(pos: resistorPos, type: .resistor),
            CrcV3Component(pos: ledPos, type: .led),
            CrcV3Component(pos: battMinusPos, type: .batteryMinus)
        ]

        currentLayout = CrcV3Layout(components: components, requiredPath: dedupedPath)
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("CIRCUIT").font(.system(size: 48, weight: .black, design: .monospaced)).foregroundColor(.primary)
            Text("Draw wires to complete the circuit.\nConnect battery + through components to battery −.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Text("SEED: #\(seedInt)")
                .font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button("START") {
                wires = []; isComplete = false; score = 0; layoutIndex = 0
                generateLayout()
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .neumorphicCard(radius: 14)
        }.padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL \(layoutIndex + 1)/\(totalLevels)")
                        .font(.system(.caption, design: .monospaced)).foregroundColor(.secondary)
                    Text("SCORE: \(score)")
                        .font(.system(.headline, design: .monospaced)).foregroundColor(.primary)
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(.caption2, design: .monospaced)).foregroundColor(.gray)
            }.padding(.horizontal)

            ZStack {
                Color(.systemGray6)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .neumorphicCard(radius: 16)
                gridView.padding(10)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                Button("CLEAR") { wires = []; isComplete = false }
                    .font(.system(.subheadline, design: .monospaced)).foregroundColor(.red)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .neumorphicCard(radius: 8)
            }
        }
    }

    var gridView: some View {
        let total = CGFloat(gridSize) * cellSize
        return ZStack {
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    Circle().fill(Color.gray.opacity(0.3)).frame(width: 5, height: 5)
                        .position(x: CGFloat(col) * cellSize + cellSize / 2,
                                  y: CGFloat(row) * cellSize + cellSize / 2)
                }
            }
            ForEach(Array(wires), id: \.self) { seg in wireView(seg) }
            ForEach(currentLayout.components.indices, id: \.self) { i in
                componentView(currentLayout.components[i])
            }
        }
        .frame(width: total, height: total)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { val in
                let col = Int(val.location.x / cellSize)
                let row = Int(val.location.y / cellSize)
                guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
                let pos = CrcV3GridPos(row: row, col: col)
                if dragStart == nil {
                    dragStart = pos
                } else if let start = dragStart, start != pos {
                    if abs(start.row - pos.row) + abs(start.col - pos.col) == 1 {
                        wires.insert(CrcV3WireSegment(from: start, to: pos))
                        dragStart = pos
                        checkCompletion()
                    }
                }
            }
            .onEnded { _ in dragStart = nil }
        )
    }

    func wireView(_ seg: CrcV3WireSegment) -> some View {
        let x1 = CGFloat(seg.from.col) * cellSize + cellSize / 2
        let y1 = CGFloat(seg.from.row) * cellSize + cellSize / 2
        let x2 = CGFloat(seg.to.col) * cellSize + cellSize / 2
        let y2 = CGFloat(seg.to.row) * cellSize + cellSize / 2
        return Path { p in
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        .stroke(isComplete ? Color.orange : Color(red: 0.2, green: 0.5, blue: 0.9), lineWidth: 3)
    }

    func componentView(_ comp: CrcV3Component) -> some View {
        let x = CGFloat(comp.pos.col) * cellSize + cellSize / 2
        let y = CGFloat(comp.pos.row) * cellSize + cellSize / 2
        return Group {
            switch comp.type {
            case .batteryPlus:
                ZStack {
                    Circle().fill(Color.green.opacity(0.85)).frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                    Text("+").font(.system(size: 15, weight: .black)).foregroundColor(.white)
                }
            case .batteryMinus:
                ZStack {
                    Circle().fill(Color.red.opacity(0.85)).frame(width: 28, height: 28)
                        .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                    Text("−").font(.system(size: 15, weight: .black)).foregroundColor(.white)
                }
            case .led:
                ZStack {
                    Circle()
                        .fill(isComplete ? Color.yellow : Color(.systemGray4))
                        .frame(width: 28, height: 28)
                        .shadow(color: isComplete ? .yellow.opacity(ledGlow ? 0.9 : 0.4) : .black.opacity(0.2),
                                radius: isComplete ? (ledGlow ? 14 : 6) : 2, x: 0, y: 0)
                    Text("L").font(.system(size: 11, weight: .black))
                        .foregroundColor(isComplete ? .black : .secondary)
                }
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: ledGlow)
            case .resistor:
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange.opacity(0.9))
                        .frame(width: 28, height: 18)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
                    Text("R").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                }
            }
        }.position(x: x, y: y)
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Text("COMPLETE!").font(.system(size: 32, weight: .black, design: .monospaced)).foregroundColor(.primary)
            Text("Score: \(score)").font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundColor(.orange)
            Text("SEED: #\(seedInt)").font(.system(.caption, design: .monospaced)).foregroundColor(.gray)
            Button("PLAY AGAIN") {
                seedInt += 1
                wires = []; isComplete = false; score = 0; layoutIndex = 0
                generateLayout()
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.primary)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .neumorphicCard(radius: 14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(24)
    }

    func checkCompletion() {
        let path = currentLayout.requiredPath
        guard path.count > 1 else { return }
        for i in 0..<path.count - 1 {
            if !wires.contains(CrcV3WireSegment(from: path[i], to: path[i + 1])) { return }
        }
        isComplete = true
        ledGlow = true
        score += 100
        if layoutIndex + 1 < totalLevels {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                layoutIndex += 1
                wires = []; isComplete = false; ledGlow = false
                generateLayout()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { phase = .complete }
        }
    }
}

#Preview { CircuitViewV3() }

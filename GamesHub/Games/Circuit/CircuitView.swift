import SwiftUI

// MARK: -  Models

enum CircuitPhase { case start, playing, complete }

struct CircuitGridPos: Hashable {
    let row: Int, col: Int
}

enum CircuitComponentType { case batteryPlus, batteryMinus, led, resistor }

struct CircuitComponent {
    let pos: CircuitGridPos
    let type: CircuitComponentType
}

struct CircuitLayout {
    let components: [CircuitComponent]
    let requiredPath: [CircuitGridPos]
}

struct CircuitWireSegment: Hashable {
    let from: CircuitGridPos
    let to: CircuitGridPos
    init(from: CircuitGridPos, to: CircuitGridPos) {
        if from.row < to.row || (from.row == to.row && from.col < to.col) {
            self.from = from; self.to = to
        } else {
            self.from = to; self.to = from
        }
    }
}

// MARK: - CircuitView

struct CircuitView: View {
    @State private var phase: CircuitPhase = .start
    @State private var wires: Set<CircuitWireSegment> = []
    @State private var layoutIndex: Int = 0
    @State private var isComplete: Bool = false
    @State private var score: Int = 0
    @State private var dragStart: CircuitGridPos? = nil
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0
    @State private var ledPulse: Bool = false

    let gridSize = 7
    var cellSize: CGFloat { CGFloat(42 * difficultyMultiplier < 36 ? 36 : 42) }

    let layouts: [CircuitLayout] = [
        CircuitLayout(
            components: [
                CircuitComponent(pos: CircuitGridPos(row: 1, col: 1), type: .batteryPlus),
                CircuitComponent(pos: CircuitGridPos(row: 1, col: 5), type: .resistor),
                CircuitComponent(pos: CircuitGridPos(row: 5, col: 5), type: .led),
                CircuitComponent(pos: CircuitGridPos(row: 5, col: 1), type: .batteryMinus)
            ],
            requiredPath: [
                CircuitGridPos(row: 1, col: 1), CircuitGridPos(row: 1, col: 2), CircuitGridPos(row: 1, col: 3),
                CircuitGridPos(row: 1, col: 4), CircuitGridPos(row: 1, col: 5), CircuitGridPos(row: 2, col: 5),
                CircuitGridPos(row: 3, col: 5), CircuitGridPos(row: 4, col: 5), CircuitGridPos(row: 5, col: 5),
                CircuitGridPos(row: 5, col: 4), CircuitGridPos(row: 5, col: 3), CircuitGridPos(row: 5, col: 2),
                CircuitGridPos(row: 5, col: 1)
            ]
        ),
        CircuitLayout(
            components: [
                CircuitComponent(pos: CircuitGridPos(row: 0, col: 3), type: .batteryPlus),
                CircuitComponent(pos: CircuitGridPos(row: 3, col: 0), type: .resistor),
                CircuitComponent(pos: CircuitGridPos(row: 6, col: 3), type: .led),
                CircuitComponent(pos: CircuitGridPos(row: 3, col: 6), type: .batteryMinus)
            ],
            requiredPath: [
                CircuitGridPos(row: 0, col: 3), CircuitGridPos(row: 1, col: 3), CircuitGridPos(row: 2, col: 3),
                CircuitGridPos(row: 3, col: 3), CircuitGridPos(row: 3, col: 2), CircuitGridPos(row: 3, col: 1),
                CircuitGridPos(row: 3, col: 0), CircuitGridPos(row: 4, col: 0), CircuitGridPos(row: 5, col: 0),
                CircuitGridPos(row: 6, col: 0), CircuitGridPos(row: 6, col: 1), CircuitGridPos(row: 6, col: 2),
                CircuitGridPos(row: 6, col: 3), CircuitGridPos(row: 6, col: 4), CircuitGridPos(row: 6, col: 5),
                CircuitGridPos(row: 6, col: 6), CircuitGridPos(row: 5, col: 6), CircuitGridPos(row: 4, col: 6),
                CircuitGridPos(row: 3, col: 6)
            ]
        ),
        CircuitLayout(
            components: [
                CircuitComponent(pos: CircuitGridPos(row: 2, col: 0), type: .batteryPlus),
                CircuitComponent(pos: CircuitGridPos(row: 0, col: 4), type: .resistor),
                CircuitComponent(pos: CircuitGridPos(row: 4, col: 6), type: .led),
                CircuitComponent(pos: CircuitGridPos(row: 6, col: 2), type: .batteryMinus)
            ],
            requiredPath: [
                CircuitGridPos(row: 2, col: 0), CircuitGridPos(row: 1, col: 0), CircuitGridPos(row: 0, col: 0),
                CircuitGridPos(row: 0, col: 1), CircuitGridPos(row: 0, col: 2), CircuitGridPos(row: 0, col: 3),
                CircuitGridPos(row: 0, col: 4), CircuitGridPos(row: 0, col: 5), CircuitGridPos(row: 0, col: 6),
                CircuitGridPos(row: 1, col: 6), CircuitGridPos(row: 2, col: 6), CircuitGridPos(row: 3, col: 6),
                CircuitGridPos(row: 4, col: 6), CircuitGridPos(row: 5, col: 6), CircuitGridPos(row: 6, col: 6),
                CircuitGridPos(row: 6, col: 5), CircuitGridPos(row: 6, col: 4), CircuitGridPos(row: 6, col: 3),
                CircuitGridPos(row: 6, col: 2)
            ]
        )
    ]

    var currentLayout: CircuitLayout { layouts[layoutIndex % layouts.count] }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.05, blue: 0.2), Color(red: 0.1, green: 0.02, blue: 0.15)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var glassPanel: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
    }

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("CIRCUIT").font(.system(size: 48, weight: .black, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
            Text("Draw wires to complete the circuit.\nConnect battery + through components to battery −.")
                .font(.subheadline).foregroundColor(.white.opacity(0.8)).multilineTextAlignment(.center)
            if difficultyMultiplier > 1.0 {
                Text("DIFFICULTY: \(String(format: "%.0f%%", difficultyMultiplier * 100))")
                    .font(.system(.caption, design: .monospaced)).foregroundColor(.orange)
            }
            Button("START") {
                wires = []; isComplete = false; score = 0; layoutIndex = 0
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.white)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.cyan.opacity(0.6), lineWidth: 1.5))
        }.padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LEVEL \(layoutIndex + 1)/\(layouts.count)")
                        .font(.system(.caption, design: .monospaced)).foregroundColor(.white.opacity(0.7))
                    Text("SCORE: \(score)")
                        .font(.system(.headline, design: .monospaced)).foregroundColor(.cyan)
                }
                Spacer()
                if difficultyMultiplier > 1.0 {
                    Text("HARD")
                        .font(.system(.caption2, design: .monospaced)).foregroundColor(.orange)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                }
            }.padding(.horizontal)

            ZStack {
                glassPanel
                gridView.padding(8)
            }
            .padding(.horizontal)

            HStack {
                Button("CLEAR") { wires = []; isComplete = false }
                    .font(.system(.subheadline, design: .monospaced)).foregroundColor(.red.opacity(0.9))
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.4), lineWidth: 1))
            }
        }
    }

    var gridView: some View {
        let cs = cellSize
        let total = CGFloat(gridSize) * cs
        return ZStack {
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    Circle().fill(Color.white.opacity(0.2)).frame(width: 5, height: 5)
                        .position(x: CGFloat(col) * cs + cs / 2, y: CGFloat(row) * cs + cs / 2)
                }
            }
            ForEach(Array(wires), id: \.self) { seg in
                wireView(seg, cs: cs)
            }
            ForEach(currentLayout.components.indices, id: \.self) { i in
                componentView(currentLayout.components[i], cs: cs)
            }
        }
        .frame(width: total, height: total)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { val in
                let col = Int(val.location.x / cs)
                let row = Int(val.location.y / cs)
                guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
                let pos = CircuitGridPos(row: row, col: col)
                if dragStart == nil {
                    dragStart = pos
                } else if let start = dragStart, start != pos {
                    if abs(start.row - pos.row) + abs(start.col - pos.col) == 1 {
                        wires.insert(CircuitWireSegment(from: start, to: pos))
                        dragStart = pos
                        checkCompletion()
                    }
                }
            }
            .onEnded { _ in dragStart = nil }
        )
    }

    func wireView(_ seg: CircuitWireSegment, cs: CGFloat) -> some View {
        let x1 = CGFloat(seg.from.col) * cs + cs / 2
        let y1 = CGFloat(seg.from.row) * cs + cs / 2
        let x2 = CGFloat(seg.to.col) * cs + cs / 2
        let y2 = CGFloat(seg.to.row) * cs + cs / 2
        return Path { p in
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        .stroke(isComplete ? Color.yellow : Color.cyan, lineWidth: 3)
    }

    func componentView(_ comp: CircuitComponent, cs: CGFloat) -> some View {
        let x = CGFloat(comp.pos.col) * cs + cs / 2
        let y = CGFloat(comp.pos.row) * cs + cs / 2
        return Group {
            switch comp.type {
            case .batteryPlus:
                ZStack {
                    Circle().fill(LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)).frame(width: 26, height: 26)
                    Text("+").font(.system(size: 14, weight: .black)).foregroundColor(.black)
                }
            case .batteryMinus:
                ZStack {
                    Circle().fill(LinearGradient(colors: [.red, .pink], startPoint: .top, endPoint: .bottom)).frame(width: 26, height: 26)
                    Text("−").font(.system(size: 14, weight: .black)).foregroundColor(.black)
                }
            case .led:
                ZStack {
                    Circle()
                        .fill(isComplete ? Color.yellow : Color.gray.opacity(0.5))
                        .frame(width: 26, height: 26)
                        .shadow(color: isComplete ? .yellow.opacity(ledPulse ? 1.0 : 0.5) : .clear,
                                radius: isComplete ? (ledPulse ? 16 : 8) : 0)
                    Text("L").font(.system(size: 11, weight: .black)).foregroundColor(isComplete ? .black : .white)
                }
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: ledPulse)
            case .resistor:
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 26, height: 16)
                    Text("R").font(.system(size: 9, weight: .bold)).foregroundColor(.black)
                }
            }
        }.position(x: x, y: y)
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Text("COMPLETE!").font(.system(size: 36, weight: .black, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing))
            Text("Score: \(score)").font(.system(size: 40, weight: .bold, design: .monospaced)).foregroundColor(.cyan)
            if difficultyMultiplier > 1.0 {
                Text("Difficulty bonus active!").font(.caption).foregroundColor(.orange)
            }
            Button("PLAY AGAIN") {
                wires = []; isComplete = false; score = 0; layoutIndex = 0
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced)).foregroundColor(.white)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.yellow.opacity(0.6), lineWidth: 1.5))
        }
        .padding(32)
        .background(glassPanel)
        .padding(24)
    }

    func checkCompletion() {
        let path = currentLayout.requiredPath
        for i in 0..<path.count - 1 {
            if !wires.contains(CircuitWireSegment(from: path[i], to: path[i + 1])) { return }
        }
        isComplete = true
        ledPulse = true
        score += Int(100.0 * difficultyMultiplier)
        recentResults.append(true)
        if recentResults.count > 5 { recentResults = Array(recentResults.suffix(5)) }
        let trueCount = recentResults.filter { $0 }.count
        if recentResults.count == 5 && trueCount > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 2.0)
        }
        if layoutIndex + 1 < layouts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                layoutIndex += 1; wires = []; isComplete = false; ledPulse = false
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { phase = .complete }
        }
    }
}

#Preview { CircuitView() }

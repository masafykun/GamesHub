import SwiftUI

// MARK: - Models

enum CrcGamePhase { case start, playing, complete }

struct CrcGridPos: Hashable {
    let row: Int, col: Int
}

enum CrcComponentType { case batteryPlus, batteryMinus, led, resistor }

struct CrcComponent {
    let pos: CrcGridPos
    let type: CrcComponentType
}

struct CrcLayout {
    let components: [CrcComponent]
    let requiredPath: [CrcGridPos]
}

// MARK: - CircuitView

struct CircuitView: View {
    @State private var phase: CrcGamePhase = .start
    @State private var wires: Set<CrcWireSegment> = []
    @State private var layoutIndex: Int = 0
    @State private var isComplete: Bool = false
    @State private var score: Int = 0
    @State private var dragStart: CrcGridPos? = nil

    let gridSize = 7
    let cellSize: CGFloat = 42

    let layouts: [CrcLayout] = [
        CrcLayout(
            components: [
                CrcComponent(pos: CrcGridPos(row: 1, col: 1), type: .batteryPlus),
                CrcComponent(pos: CrcGridPos(row: 1, col: 5), type: .resistor),
                CrcComponent(pos: CrcGridPos(row: 5, col: 5), type: .led),
                CrcComponent(pos: CrcGridPos(row: 5, col: 1), type: .batteryMinus)
            ],
            requiredPath: [
                CrcGridPos(row: 1, col: 1), CrcGridPos(row: 1, col: 2), CrcGridPos(row: 1, col: 3),
                CrcGridPos(row: 1, col: 4), CrcGridPos(row: 1, col: 5), CrcGridPos(row: 2, col: 5),
                CrcGridPos(row: 3, col: 5), CrcGridPos(row: 4, col: 5), CrcGridPos(row: 5, col: 5),
                CrcGridPos(row: 5, col: 4), CrcGridPos(row: 5, col: 3), CrcGridPos(row: 5, col: 2),
                CrcGridPos(row: 5, col: 1)
            ]
        ),
        CrcLayout(
            components: [
                CrcComponent(pos: CrcGridPos(row: 0, col: 3), type: .batteryPlus),
                CrcComponent(pos: CrcGridPos(row: 3, col: 0), type: .resistor),
                CrcComponent(pos: CrcGridPos(row: 6, col: 3), type: .led),
                CrcComponent(pos: CrcGridPos(row: 3, col: 6), type: .batteryMinus)
            ],
            requiredPath: [
                CrcGridPos(row: 0, col: 3), CrcGridPos(row: 1, col: 3), CrcGridPos(row: 2, col: 3),
                CrcGridPos(row: 3, col: 3), CrcGridPos(row: 3, col: 2), CrcGridPos(row: 3, col: 1),
                CrcGridPos(row: 3, col: 0), CrcGridPos(row: 4, col: 0), CrcGridPos(row: 5, col: 0),
                CrcGridPos(row: 6, col: 0), CrcGridPos(row: 6, col: 1), CrcGridPos(row: 6, col: 2),
                CrcGridPos(row: 6, col: 3), CrcGridPos(row: 6, col: 4), CrcGridPos(row: 6, col: 5),
                CrcGridPos(row: 6, col: 6), CrcGridPos(row: 5, col: 6), CrcGridPos(row: 4, col: 6),
                CrcGridPos(row: 3, col: 6)
            ]
        ),
        CrcLayout(
            components: [
                CrcComponent(pos: CrcGridPos(row: 2, col: 0), type: .batteryPlus),
                CrcComponent(pos: CrcGridPos(row: 0, col: 4), type: .resistor),
                CrcComponent(pos: CrcGridPos(row: 4, col: 6), type: .led),
                CrcComponent(pos: CrcGridPos(row: 6, col: 2), type: .batteryMinus)
            ],
            requiredPath: [
                CrcGridPos(row: 2, col: 0), CrcGridPos(row: 1, col: 0), CrcGridPos(row: 0, col: 0),
                CrcGridPos(row: 0, col: 1), CrcGridPos(row: 0, col: 2), CrcGridPos(row: 0, col: 3),
                CrcGridPos(row: 0, col: 4), CrcGridPos(row: 0, col: 5), CrcGridPos(row: 0, col: 6),
                CrcGridPos(row: 1, col: 6), CrcGridPos(row: 2, col: 6), CrcGridPos(row: 3, col: 6),
                CrcGridPos(row: 4, col: 6), CrcGridPos(row: 5, col: 6), CrcGridPos(row: 6, col: 6),
                CrcGridPos(row: 6, col: 5), CrcGridPos(row: 6, col: 4), CrcGridPos(row: 6, col: 3),
                CrcGridPos(row: 6, col: 2)
            ]
        )
    ]

    var currentLayout: CrcLayout { layouts[layoutIndex % layouts.count] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .complete: completeScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("CIRCUIT").font(.system(size: 48, weight: .black, design: .monospaced)).foregroundColor(.green)
            Text("Draw wires to complete the circuit").font(.headline).foregroundColor(.gray).multilineTextAlignment(.center)
            Text("Connect battery (+) through\nresistors and LED to battery (-)").font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
            Button("START") {
                wires = []
                isComplete = false
                score = 0
                layoutIndex = 0
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(.black)
            .padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.green)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }.padding(32)
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            HStack {
                Text("CIRCUIT \(layoutIndex + 1)/\(layouts.count)").font(.system(.headline, design: .monospaced)).foregroundColor(.green)
                Spacer()
                Text("SCORE: \(score)").font(.system(.headline, design: .monospaced)).foregroundColor(.yellow)
            }.padding(.horizontal)

            gridView

            HStack(spacing: 16) {
                Button("CLEAR") { wires = []; isComplete = false }
                    .font(.system(.subheadline, design: .monospaced)).foregroundColor(.red)
                    .padding(.horizontal, 20).padding(.vertical, 8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
            }
        }
    }

    var gridView: some View {
        let total = CGFloat(gridSize) * cellSize
        return ZStack {
            // Grid lines
            ForEach(0..<gridSize, id: \.self) { row in
                ForEach(0..<gridSize, id: \.self) { col in
                    Circle()
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .position(x: CGFloat(col) * cellSize + cellSize / 2,
                                  y: CGFloat(row) * cellSize + cellSize / 2)
                }
            }
            // Wires
            ForEach(Array(wires), id: \.self) { seg in
                wireView(seg)
            }
            // Components
            ForEach(currentLayout.components.indices, id: \.self) { i in
                componentView(currentLayout.components[i])
            }
        }
        .frame(width: total, height: total)
        .background(Color.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { val in
                let col = Int(val.location.x / cellSize)
                let row = Int(val.location.y / cellSize)
                guard row >= 0, row < gridSize, col >= 0, col < gridSize else { return }
                let pos = CrcGridPos(row: row, col: col)
                if dragStart == nil {
                    dragStart = pos
                } else if let start = dragStart, start != pos {
                    if abs(start.row - pos.row) + abs(start.col - pos.col) == 1 {
                        let seg = CrcWireSegment(from: start, to: pos)
                        wires.insert(seg)
                        dragStart = pos
                        checkCompletion()
                    }
                }
            }
            .onEnded { _ in dragStart = nil }
        )
    }

    func wireView(_ seg: CrcWireSegment) -> some View {
        let x1 = CGFloat(seg.from.col) * cellSize + cellSize / 2
        let y1 = CGFloat(seg.from.row) * cellSize + cellSize / 2
        let x2 = CGFloat(seg.to.col) * cellSize + cellSize / 2
        let y2 = CGFloat(seg.to.row) * cellSize + cellSize / 2
        return Path { p in
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        .stroke(isComplete ? Color.yellow : Color.green, lineWidth: 3)
    }

    func componentView(_ comp: CrcComponent) -> some View {
        let x = CGFloat(comp.pos.col) * cellSize + cellSize / 2
        let y = CGFloat(comp.pos.row) * cellSize + cellSize / 2
        return Group {
            switch comp.type {
            case .batteryPlus:
                ZStack {
                    Circle().fill(Color.green).frame(width: 28, height: 28)
                    Text("+").font(.system(size: 16, weight: .black)).foregroundColor(.black)
                }
            case .batteryMinus:
                ZStack {
                    Circle().fill(Color.red).frame(width: 28, height: 28)
                    Text("−").font(.system(size: 16, weight: .black)).foregroundColor(.black)
                }
            case .led:
                ZStack {
                    Circle().fill(isComplete ? Color.yellow : Color.gray).frame(width: 28, height: 28)
                        .shadow(color: isComplete ? .yellow : .clear, radius: isComplete ? 12 : 0)
                    Text("L").font(.system(size: 12, weight: .black)).foregroundColor(.black)
                }
            case .resistor:
                ZStack {
                    RoundedRectangle(cornerRadius: 4).fill(Color.orange).frame(width: 28, height: 18)
                    Text("R").font(.system(size: 10, weight: .bold)).foregroundColor(.black)
                }
            }
        }.position(x: x, y: y)
    }

    var completeScreen: some View {
        VStack(spacing: 24) {
            Text("CIRCUIT COMPLETE!").font(.system(size: 28, weight: .black, design: .monospaced)).foregroundColor(.yellow)
            Text("Score: \(score)").font(.system(size: 36, weight: .bold, design: .monospaced)).foregroundColor(.green)
            Button("PLAY AGAIN") {
                wires = []
                isComplete = false
                score = 0
                layoutIndex = 0
                phase = .playing
            }
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundColor(.black).padding(.horizontal, 40).padding(.vertical, 14)
            .background(Color.green).clipShape(RoundedRectangle(cornerRadius: 10))
        }.padding(32)
    }

    func checkCompletion() {
        let path = currentLayout.requiredPath
        for i in 0..<path.count - 1 {
            let seg = CrcWireSegment(from: path[i], to: path[i + 1])
            if !wires.contains(seg) { return }
        }
        isComplete = true
        score += 100
        if layoutIndex + 1 < layouts.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                layoutIndex += 1
                wires = []
                isComplete = false
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                phase = .complete
            }
        }
    }
}

struct CrcWireSegment: Hashable {
    let from: CrcGridPos
    let to: CrcGridPos
    init(from: CrcGridPos, to: CrcGridPos) {
        // Normalize so order doesn't matter
        if from.row < to.row || (from.row == to.row && from.col < to.col) {
            self.from = from; self.to = to
        } else {
            self.from = to; self.to = from
        }
    }
}

#Preview { CircuitView() }

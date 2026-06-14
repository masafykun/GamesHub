import SwiftUI

// MARK: - LCG Random
struct SdFlLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Cell Type V3
enum SdFlV3CellType: UInt8 {
    case empty = 0
    case sand = 1
    case rock = 2
    case water = 3
}

// MARK: - Grid V3
struct SdFlV3Grid {
    static let cols = 60
    static let rows = 100
    var cells: [SdFlV3CellType]

    init() {
        cells = Array(repeating: .empty, count: SdFlV3Grid.cols * SdFlV3Grid.rows)
    }

    subscript(col: Int, row: Int) -> SdFlV3CellType {
        get {
            guard col >= 0, col < SdFlV3Grid.cols, row >= 0, row < SdFlV3Grid.rows else { return .rock }
            return cells[row * SdFlV3Grid.cols + col]
        }
        set {
            guard col >= 0, col < SdFlV3Grid.cols, row >= 0, row < SdFlV3Grid.rows else { return }
            cells[row * SdFlV3Grid.cols + col] = newValue
        }
    }

    mutating func step(rng: inout SdFlLCG) {
        for row in stride(from: SdFlV3Grid.rows - 2, through: 0, by: -1) {
            for col in 0..<SdFlV3Grid.cols {
                let cell = cells[row * SdFlV3Grid.cols + col]
                if cell == .sand {
                    if self[col, row + 1] == .empty {
                        self[col, row + 1] = .sand
                        self[col, row] = .empty
                    } else {
                        let leftFree = self[col - 1, row + 1] == .empty
                        let rightFree = self[col + 1, row + 1] == .empty
                        if leftFree && rightFree {
                            let dir = rng.nextInt(2) == 0 ? -1 : 1
                            self[col + dir, row + 1] = .sand
                            self[col, row] = .empty
                        } else if leftFree {
                            self[col - 1, row + 1] = .sand
                            self[col, row] = .empty
                        } else if rightFree {
                            self[col + 1, row + 1] = .sand
                            self[col, row] = .empty
                        }
                    }
                } else if cell == .water {
                    if self[col, row + 1] == .empty {
                        self[col, row + 1] = .water
                        self[col, row] = .empty
                    } else {
                        let leftFree = self[col - 1, row] == .empty
                        let rightFree = self[col + 1, row] == .empty
                        if leftFree && rightFree {
                            let dir = rng.nextInt(2) == 0 ? -1 : 1
                            self[col + dir, row] = .water
                            self[col, row] = .empty
                        } else if leftFree {
                            self[col - 1, row] = .water
                            self[col, row] = .empty
                        } else if rightFree {
                            self[col + 1, row] = .water
                            self[col, row] = .empty
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Brush V3
enum SdFlV3Brush: CaseIterable {
    case sand, rock, water, eraser

    var label: String {
        switch self {
        case .sand: return "Sand"
        case .rock: return "Rock"
        case .water: return "Water"
        case .eraser: return "Erase"
        }
    }

    var color: Color {
        switch self {
        case .sand: return Color(red: 0.9, green: 0.65, blue: 0.25)
        case .rock: return Color(red: 0.5, green: 0.38, blue: 0.28)
        case .water: return Color(red: 0.3, green: 0.55, blue: 0.95)
        case .eraser: return Color.gray
        }
    }
}

// MARK: - Phase V3
enum SdFlV3Phase {
    case start, playing, results
}

// MARK: - Preset Wall Structure
struct SdFlV3Wall {
    let col: Int
    let row: Int
    let width: Int
    let height: Int
}

// MARK: - SandFallViewV3
struct SandFallViewV3: View {
    @State private var grid = SdFlV3Grid()
    @State private var phase: SdFlV3Phase = .start
    @State private var brush: SdFlV3Brush = .sand
    @State private var score: Int = 0
    @State private var timer: Timer? = nil
    @State private var seedInt: Int = 1
    @State private var rng = SdFlLCG(seed: 1)
    @State private var presetWalls: [SdFlV3Wall] = []
    @State private var tickCount: Int = 0

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start:
                startScreen
            case .playing:
                playingScreen
            case .results:
                resultsScreen
            }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("SandFall")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(Color(.label))
                Text("Procedural Edition")
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            VStack(spacing: 10) {
                Text("Each game generates unique structures.")
                    .foregroundColor(Color(.secondaryLabel))
                Text("Paint sand, rock, or water on the canvas.")
                    .foregroundColor(Color(.secondaryLabel))
            }
            .font(.body)
            .multilineTextAlignment(.center)
            .padding(20)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("Start Game")
                    .font(.title3.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 44)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 12)
            }
        }
        .padding(24)
    }

    // MARK: - Playing Screen
    var playingScreen: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAND")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("\(sandCount)")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundColor(Color(red: 0.85, green: 0.55, blue: 0.15))
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SCORE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(.tertiaryLabel))
                    Text("\(score)")
                        .font(.system(size: 17, weight: .bold).monospacedDigit())
                        .foregroundColor(Color(.label))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))

            // Canvas
            GeometryReader { geo in
                Canvas { ctx, size in
                    let cellW = size.width / CGFloat(SdFlV3Grid.cols)
                    let cellH = size.height / CGFloat(SdFlV3Grid.rows)
                    for row in 0..<SdFlV3Grid.rows {
                        for col in 0..<SdFlV3Grid.cols {
                            let cell = grid[col, row]
                            guard cell != .empty else { continue }
                            let color: Color
                            switch cell {
                            case .sand:  color = Color(red: 0.9, green: 0.65, blue: 0.25)
                            case .rock:  color = Color(red: 0.5, green: 0.38, blue: 0.28)
                            case .water: color = Color(red: 0.3, green: 0.55, blue: 0.9)
                            default:     color = .clear
                            }
                            ctx.fill(
                                Path(CGRect(x: CGFloat(col) * cellW, y: CGFloat(row) * cellH, width: cellW + 0.5, height: cellH + 0.5)),
                                with: .color(color)
                            )
                        }
                    }
                    // Draw preset walls as outlines for visibility
                    for wall in presetWalls {
                        let rect = CGRect(
                            x: CGFloat(wall.col) * cellW,
                            y: CGFloat(wall.row) * cellH,
                            width: CGFloat(wall.width) * cellW,
                            height: CGFloat(wall.height) * cellH
                        )
                        ctx.stroke(Path(rect), with: .color(.gray.opacity(0.2)), lineWidth: 0.5)
                    }
                }
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let canvasSize = CGSize(
                                width: geo.size.width - 16,
                                height: geo.size.height
                            )
                            let adjusted = CGPoint(x: val.location.x - 8, y: val.location.y)
                            paintAt(adjusted, in: canvasSize)
                        }
                )
            }

            // Toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SdFlV3Brush.allCases, id: \.label) { b in
                        neuBrushButton(b)
                    }
                    Spacer(minLength: 12)
                    Button {
                        grid = SdFlV3Grid()
                        applyPresetWalls()
                        score = 0
                    } label: {
                        Text("Clear")
                            .font(.caption.bold())
                            .foregroundColor(Color(.secondaryLabel))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .neumorphicCard(radius: 8)
                    }
                    Button {
                        stopGame()
                        phase = .results
                    } label: {
                        Text("End")
                            .font(.caption.bold())
                            .foregroundColor(Color(.label))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .neumorphicCard(radius: 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGray6))
        }
    }

    func neuBrushButton(_ b: SdFlV3Brush) -> some View {
        Button { brush = b } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(b.color)
                    .frame(width: 10, height: 10)
                Text(b.label)
                    .font(.caption.bold())
                    .foregroundColor(brush == b ? b.color : Color(.secondaryLabel))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .neumorphicCard(radius: 8)
            .overlay(
                brush == b
                    ? RoundedRectangle(cornerRadius: 8).stroke(b.color.opacity(0.6), lineWidth: 1.5)
                    : nil
            )
        }
    }

    // MARK: - Results Screen
    var resultsScreen: some View {
        VStack(spacing: 24) {
            Text("Session Over")
                .font(.largeTitle.bold())
                .foregroundColor(Color(.label))
                .padding(.bottom, 4)

            VStack(spacing: 16) {
                neuStatRow("Sand Placed", value: "\(score)")
                neuStatRow("Seed Used", value: "#\(seedInt)")
                neuStatRow("Cell Types", value: "Sand / Rock / Water")
            }
            .padding(20)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("New Game (Seed #\(seedInt + 1))")
                    .font(.callout.bold())
                    .foregroundColor(Color(.label))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .neumorphicCard(radius: 12)
            }
        }
        .padding(24)
    }

    func neuStatRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(Color(.secondaryLabel))
            Spacer()
            Text(value)
                .font(.body.bold())
                .foregroundColor(Color(.label))
        }
    }

    // MARK: - Helpers
    var sandCount: Int {
        grid.cells.filter { $0 == .sand }.count
    }

    func paintAt(_ location: CGPoint, in size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let col = Int(location.x / size.width * CGFloat(SdFlV3Grid.cols))
        let row = Int(location.y / size.height * CGFloat(SdFlV3Grid.rows))
        guard col >= 0, col < SdFlV3Grid.cols, row >= 0, row < SdFlV3Grid.rows else { return }
        switch brush {
        case .sand:
            if grid[col, row] == .empty {
                grid[col, row] = .sand
                score += 1
            }
        case .rock:
            grid[col, row] = .rock
        case .water:
            if grid[col, row] == .empty {
                grid[col, row] = .water
            }
        case .eraser:
            grid[col, row] = .empty
        }
    }

    func generatePresetWalls(using rng: inout SdFlLCG) -> [SdFlV3Wall] {
        var walls: [SdFlV3Wall] = []
        let wallCount = 3 + rng.nextInt(4)
        for _ in 0..<wallCount {
            let isHorizontal = rng.nextInt(2) == 0
            if isHorizontal {
                let w = 8 + rng.nextInt(14)
                let col = rng.nextInt(SdFlV3Grid.cols - w)
                let row = 20 + rng.nextInt(SdFlV3Grid.rows - 40)
                walls.append(SdFlV3Wall(col: col, row: row, width: w, height: 1))
            } else {
                let h = 5 + rng.nextInt(10)
                let col = rng.nextInt(SdFlV3Grid.cols - 1)
                let row = 15 + rng.nextInt(SdFlV3Grid.rows - 30)
                walls.append(SdFlV3Wall(col: col, row: row, width: 1, height: h))
            }
        }
        return walls
    }

    func applyPresetWalls() {
        for wall in presetWalls {
            for r in wall.row..<min(wall.row + wall.height, SdFlV3Grid.rows) {
                for c in wall.col..<min(wall.col + wall.width, SdFlV3Grid.cols) {
                    grid[c, r] = .rock
                }
            }
        }
    }

    func startGame() {
        seedInt += 1
        rng = SdFlLCG(seed: seedInt)
        grid = SdFlV3Grid()
        score = 0
        presetWalls = generatePresetWalls(using: &rng)
        applyPresetWalls()
        phase = .playing
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15.0, repeats: true) { _ in
            grid.step(rng: &rng)
            tickCount += 1
        }
    }

    func stopGame() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview { SandFallViewV3() }

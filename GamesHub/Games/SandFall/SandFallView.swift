import SwiftUI

// MARK: - Model

enum SandFallCellType: UInt8 {
    case empty = 0
    case sand = 1
    case rock = 2
}

struct SandFallGrid {
    static let cols = 48
    static let rows = 80

    var cells: [SandFallCellType]

    init() {
        cells = Array(repeating: .empty, count: SandFallGrid.cols * SandFallGrid.rows)
    }

    subscript(col: Int, row: Int) -> SandFallCellType {
        get {
            guard col >= 0, col < SandFallGrid.cols, row >= 0, row < SandFallGrid.rows else { return .rock }
            return cells[row * SandFallGrid.cols + col]
        }
        set {
            guard col >= 0, col < SandFallGrid.cols, row >= 0, row < SandFallGrid.rows else { return }
            cells[row * SandFallGrid.cols + col] = newValue
        }
    }

    /// Classic falling-sand rule: straight down first, then diagonally.
    mutating func step() {
        for row in stride(from: SandFallGrid.rows - 2, through: 0, by: -1) {
            for col in 0..<SandFallGrid.cols {
                guard cells[row * SandFallGrid.cols + col] == .sand else { continue }
                if self[col, row + 1] == .empty {
                    self[col, row + 1] = .sand
                    self[col, row] = .empty
                } else {
                    let leftFree = self[col - 1, row + 1] == .empty
                    let rightFree = self[col + 1, row + 1] == .empty
                    if leftFree && rightFree {
                        let dir = Bool.random() ? -1 : 1
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
            }
        }
    }
}

enum SandFallBrush { case rock, eraser }
enum SandFallPhase { case start, playing, results }

struct SandFallBucket: Identifiable {
    let id: Int
    let minCol: Int
    let maxCol: Int
    var caught: Int = 0
    var contains: (Int) -> Bool { { col in col >= minCol && col <= maxCol } }
}

// MARK: - Engine

/// The three shipped versions were sandboxes with no goal, so this rebuilds
/// the same sand simulation as a game: guide the falling stream into the
/// buckets with a limited amount of stone before the timer runs out.
final class SandFallEngine: ObservableObject {
    @Published var grid = SandFallGrid()
    @Published var buckets: [SandFallBucket] = []
    @Published var phase: SandFallPhase = .start
    @Published var brush: SandFallBrush = .rock
    @Published var score: Int = 0
    @Published var spilled: Int = 0
    @Published var stoneLeft: Int = 0
    @Published var timeLeft: Int = 45
    @Published var level: Int = 1
    @Published var target: Int = 60

    private var timer: Timer?
    private var secondTimer: Timer?
    private var spoutCol: Int = SandFallGrid.cols / 2
    private var frame: Int = 0

    private let bucketRow = SandFallGrid.rows - 3
    private var stonePerLevel: Int { max(90, 190 - level * 20) }

    // MARK: Lifecycle

    func start(level newLevel: Int = 1) {
        stop()
        level = newLevel
        grid = SandFallGrid()
        score = 0
        spilled = 0
        frame = 0
        stoneLeft = stonePerLevel
        timeLeft = 45
        target = 40 + level * 20
        phase = .playing

        layoutBuckets()

        let sim = Timer(timeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in self?.tick() }
        timer = sim
        RunLoop.main.add(sim, forMode: .common)

        let clock = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.tickClock() }
        secondTimer = clock
        RunLoop.main.add(clock, forMode: .common)
    }

    func stop() {
        timer?.invalidate(); timer = nil
        secondTimer?.invalidate(); secondTimer = nil
    }

    private func layoutBuckets() {
        // Buckets sit at the bottom; the spout is offset so sand needs steering.
        let width = 7
        let positions: [Int]
        switch level {
        case 1:  positions = [8, SandFallGrid.cols - 15]
        case 2:  positions = [4, SandFallGrid.cols / 2 - 3, SandFallGrid.cols - 11]
        default: positions = [3, SandFallGrid.cols / 2 - 4, SandFallGrid.cols - 10]
        }
        buckets = positions.enumerated().map { idx, start in
            SandFallBucket(id: idx, minCol: start, maxCol: start + width - 1)
        }
        spoutCol = level % 2 == 0 ? SandFallGrid.cols / 3 : SandFallGrid.cols / 2

        // Bucket walls, so grains that land inside stay put.
        for bucket in buckets {
            for row in (bucketRow - 4)...(SandFallGrid.rows - 1) {
                grid[bucket.minCol - 1, row] = .rock
                grid[bucket.maxCol + 1, row] = .rock
            }
        }
        for col in 0..<SandFallGrid.cols {
            grid[col, SandFallGrid.rows - 1] = .rock
        }
    }

    // MARK: Loop

    private func tick() {
        guard phase == .playing else { return }
        frame += 1

        // Pour a few grains from the spout.
        if frame % 2 == 0 {
            for offset in -1...1 where grid[spoutCol + offset, 0] == .empty {
                grid[spoutCol + offset, 0] = .sand
            }
        }

        grid.step()
        collect()
    }

    private func collect() {
        // Any grain that reaches the bucket floor is banked and removed.
        let floor = SandFallGrid.rows - 2
        for col in 0..<SandFallGrid.cols where grid[col, floor] == .sand {
            grid[col, floor] = .empty
            if let idx = buckets.firstIndex(where: { $0.contains(col) }) {
                buckets[idx].caught += 1
                score += 1
            } else {
                spilled += 1
            }
        }
    }

    private func tickClock() {
        guard phase == .playing else { return }
        timeLeft -= 1
        if timeLeft <= 0 {
            timeLeft = 0
            finish()
        }
    }

    private func finish() {
        stop()
        phase = .results
    }

    // MARK: Input

    func paint(at location: CGPoint, in size: CGSize) {
        guard phase == .playing else { return }
        let col = Int(location.x / size.width * CGFloat(SandFallGrid.cols))
        let row = Int(location.y / size.height * CGFloat(SandFallGrid.rows))
        guard col >= 0, col < SandFallGrid.cols, row >= 0, row < SandFallGrid.rows else { return }
        // Keep the spout and the bucket floor out of reach.
        guard row > 2, row < SandFallGrid.rows - 2 else { return }

        switch brush {
        case .rock:
            guard stoneLeft > 0, grid[col, row] != .rock else { return }
            grid[col, row] = .rock
            stoneLeft -= 1
        case .eraser:
            guard grid[col, row] == .rock else { return }
            grid[col, row] = .empty
            stoneLeft += 1
        }
    }

    var didClearTarget: Bool { score >= target }

    deinit { stop() }
}

// MARK: - View

struct SandFallView: View {
    @StateObject private var engine = SandFallEngine()
    @AppStorage("sandFallBestScore") private var bestScore: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.06, blue: 0.14), Color(red: 0.14, green: 0.08, blue: 0.16)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            switch engine.phase {
            case .start:   startScreen
            case .playing: playingScreen
            case .results: resultsScreen
            }
        }
        .onDisappear { engine.stop() }
        .preferredColorScheme(.dark)
    }

    // MARK: Screens

    private var startScreen: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                Text("SAND FALL")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.orange)
                Text("Steer the stream into the buckets")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Sand pours from the spout non-stop", systemImage: "drop.fill")
                Label("Draw stone ramps to guide it", systemImage: "pencil.tip")
                Label("Every grain banked is a point — spills are wasted", systemImage: "target")
                Label("Hit the target before the 45s timer ends", systemImage: "clock")
            }
            .font(.footnote)
            .foregroundColor(.white.opacity(0.85))
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

            if bestScore > 0 {
                Text("Best: \(bestScore) grains")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Button(action: { engine.start(level: 1) }) {
                Text("Begin")
                    .font(.title2.bold())
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 15)
                    .background(Capsule().fill(Color.orange))
                    .shadow(color: .orange.opacity(0.5), radius: 12)
            }
        }
        .padding(28)
    }

    private var playingScreen: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                ZStack {
                    Canvas { ctx, size in
                        let cw = size.width / CGFloat(SandFallGrid.cols)
                        let ch = size.height / CGFloat(SandFallGrid.rows)

                        // Bucket mouths
                        for bucket in engine.buckets {
                            let rect = CGRect(
                                x: CGFloat(bucket.minCol) * cw,
                                y: size.height - ch * 6,
                                width: CGFloat(bucket.maxCol - bucket.minCol + 1) * cw,
                                height: ch * 6
                            )
                            ctx.fill(Path(rect), with: .color(.green.opacity(0.18)))
                        }

                        for row in 0..<SandFallGrid.rows {
                            for col in 0..<SandFallGrid.cols {
                                let cell = engine.grid[col, row]
                                guard cell != .empty else { continue }
                                let rect = CGRect(x: CGFloat(col) * cw, y: CGFloat(row) * ch, width: cw, height: ch)
                                let color: Color = cell == .sand
                                    ? Color(hue: 0.1, saturation: 0.75, brightness: 0.95)
                                    : Color(white: 0.45)
                                ctx.fill(Path(rect), with: .color(color))
                            }
                        }
                    }
                    .background(Color.black.opacity(0.25))
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in engine.paint(at: value.location, in: geo.size) }
                    )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            toolbar
        }
    }

    private var header: some View {
        HStack {
            stat(title: "BANKED", value: "\(engine.score)/\(engine.target)", color: .orange)
            Spacer()
            stat(title: "STONE", value: "\(engine.stoneLeft)", color: engine.stoneLeft > 0 ? .white : .red)
            Spacer()
            stat(title: "SPILLED", value: "\(engine.spilled)", color: .white.opacity(0.6))
            Spacer()
            stat(title: "TIME", value: "\(engine.timeLeft)s", color: engine.timeLeft <= 10 ? .red : .cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func stat(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 17, weight: .bold).monospacedDigit())
                .foregroundColor(color)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            toolButton(title: "Stone", icon: "square.fill", active: engine.brush == .rock) {
                engine.brush = .rock
            }
            toolButton(title: "Erase", icon: "eraser.fill", active: engine.brush == .eraser) {
                engine.brush = .eraser
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func toolButton(title: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .foregroundColor(active ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(active ? Color.orange : Color.white.opacity(0.12))
                )
        }
    }

    private var resultsScreen: some View {
        VStack(spacing: 22) {
            Text(engine.didClearTarget ? "TARGET MET!" : "TIME UP")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(engine.didClearTarget ? .green : .orange)

            VStack(spacing: 10) {
                resultRow("Banked", "\(engine.score) / \(engine.target)")
                resultRow("Spilled", "\(engine.spilled)")
                resultRow("Best", "\(bestScore)")
                ForEach(engine.buckets) { bucket in
                    resultRow("Bucket \(bucket.id + 1)", "\(bucket.caught)")
                }
            }
            .padding(22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))

            HStack(spacing: 12) {
                if engine.didClearTarget {
                    Button("Next Level") { engine.start(level: engine.level + 1) }
                        .buttonStyle(SandFallButtonStyle(tint: .green))
                }
                Button(engine.didClearTarget ? "Replay" : "Try Again") { engine.start(level: engine.level) }
                    .buttonStyle(SandFallButtonStyle(tint: .orange))
            }
        }
        .padding(28)
        .onAppear { bestScore = max(bestScore, engine.score) }
    }

    private func resultRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.white.opacity(0.65))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .bold()
                .monospacedDigit()
        }
        .font(.subheadline)
        .frame(width: 220)
    }
}

struct SandFallButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 28)
            .padding(.vertical, 13)
            .background(Capsule().fill(tint))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

#Preview {
    SandFallView()
}

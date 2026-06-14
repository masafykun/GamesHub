import SwiftUI

struct TfLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum TfV3Phase { case start, playing, gameOver }
enum TfV3Dir: Int, CaseIterable { case north, south, east, west }

struct TfV3Car: Identifiable {
    let id = UUID()
    let direction: TfV3Dir
    let laneOffset: CGFloat
    var position: CGFloat = 0.0
    var stopped: Bool = false
}

struct TrafficViewV3: View {
    @State private var phase: TfV3Phase = .start
    @State private var cars: [TfV3Car] = []
    @State private var score: Int = 0
    @State private var spawnInterval: Double = 2.4
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var spawnCount: Int = 0
    @State private var seedInt: Int = 1
    @State private var lcg: TfLCG = TfLCG(seed: 1)

    let boardSize: CGFloat = 270
    let roadWidth: CGFloat = 60
    let intersectionSize: CGFloat = 60
    let carSize: CGFloat = 20
    let carSpeed: CGFloat = 0.007

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: playingScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 28) {
            Text("TRAFFIC")
                .font(.system(size: 46, weight: .black))
                .foregroundColor(Color(.label))
            Text("Tap cars to stop or go\nPrevent collisions at the intersection")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
                .font(.callout)
            neumorphButton("START", action: startGame)
        }
        .padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("COLLISION!")
                .font(.system(size: 34, weight: .black))
                .foregroundColor(.red)
            VStack(spacing: 6) {
                Text("Cars Safely Crossed")
                    .foregroundColor(Color(.secondaryLabel)).font(.subheadline)
                Text("\(score)")
                    .font(.system(size: 60, weight: .black))
                    .foregroundColor(Color(.label))
            }
            .padding(24)
            .neumorphicCard(radius: 16)
            neumorphButton("RETRY", action: startGame)
        }
        .padding(32)
    }

    var playingScreen: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Score").font(.caption).foregroundColor(Color(.secondaryLabel))
                    Text("\(score)").font(.title.bold()).foregroundColor(Color(.label))
                }
                Spacer()
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
            .neumorphicCard(radius: 16)
            .padding(.horizontal, 20)

            ZStack {
                roadCanvas
                ForEach(cars) { car in
                    carTile(car: car).onTapGesture { toggleCar(id: car.id) }
                }
            }
            .frame(width: boardSize, height: boardSize)
            .neumorphicCard(radius: 20)

            Text("Tap to stop / resume cars")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
    }

    // MARK: - Neumorphic button

    func neumorphButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.headline.bold())
                .foregroundColor(Color(.label))
                .padding(.horizontal, 44).padding(.vertical, 14)
        }
        .neumorphicCard(radius: 14)
    }

    // MARK: - Road

    var roadCanvas: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let rw = roadWidth
            let roadColor = Color(.systemGray4)
            ctx.fill(Path(CGRect(x: 0, y: mid - rw/2, width: size.width, height: rw)), with: .color(roadColor))
            ctx.fill(Path(CGRect(x: mid - rw/2, y: 0, width: rw, height: size.height)), with: .color(roadColor))
            ctx.fill(Path(CGRect(x: mid - intersectionSize/2, y: mid - intersectionSize/2, width: intersectionSize, height: intersectionSize)), with: .color(Color(.systemGray3)))
            // Center markings
            var dashPath = Path()
            dashPath.move(to: CGPoint(x: mid, y: 0))
            dashPath.addLine(to: CGPoint(x: mid, y: mid - intersectionSize/2 - 4))
            dashPath.move(to: CGPoint(x: mid, y: mid + intersectionSize/2 + 4))
            dashPath.addLine(to: CGPoint(x: mid, y: size.height))
            dashPath.move(to: CGPoint(x: 0, y: mid))
            dashPath.addLine(to: CGPoint(x: mid - intersectionSize/2 - 4, y: mid))
            dashPath.move(to: CGPoint(x: mid + intersectionSize/2 + 4, y: mid))
            dashPath.addLine(to: CGPoint(x: size.width, y: mid))
            ctx.stroke(dashPath, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
        }
    }

    // MARK: - Car

    func carPos(_ car: TfV3Car) -> CGPoint {
        let mid = boardSize / 2
        let t = car.position
        let offset = car.laneOffset
        switch car.direction {
        case .north: return CGPoint(x: mid + offset, y: boardSize - t * boardSize)
        case .south: return CGPoint(x: mid - offset, y: t * boardSize)
        case .west:  return CGPoint(x: boardSize - t * boardSize, y: mid + offset)
        case .east:  return CGPoint(x: t * boardSize, y: mid - offset)
        }
    }

    func carTile(car: TfV3Car) -> some View {
        let pos = carPos(car)
        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(car.stopped ? Color(red:0.9,green:0.25,blue:0.25) : Color(red:0.25,green:0.75,blue:0.35))
                .frame(width: carSize, height: carSize)
                .shadow(color: Color(.systemGray4), radius: 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.8), radius: 3, x: -2, y: -2)
            Circle().fill(.white.opacity(0.7)).frame(width: 5, height: 5)
        }.position(pos)
    }

    // MARK: - Logic

    func startGame() {
        seedInt += 1
        lcg = TfLCG(seed: seedInt)
        cars = []
        score = 0
        spawnInterval = 2.4
        spawnCount = 0
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in tick() }
        scheduleSpawn()
    }

    func scheduleSpawn() {
        spawnTimer?.invalidate()
        let interval = spawnInterval + (lcg.nextDouble() * 0.6 - 0.3)
        spawnTimer = Timer.scheduledTimer(withTimeInterval: max(0.5, interval), repeats: false) { _ in
            spawnCar()
            scheduleSpawn()
        }
    }

    func spawnCar() {
        let dirIdx = lcg.nextInt(4)
        let dir = TfV3Dir(rawValue: dirIdx) ?? .north
        let offset: CGFloat = dirIdx % 2 == 0 ? -10 : 10
        cars.append(TfV3Car(direction: dir, laneOffset: offset))
        spawnCount += 1
        if spawnCount % 6 == 0 {
            spawnInterval = max(0.7, spawnInterval - 0.25)
        }
    }

    func toggleCar(id: UUID) {
        if let idx = cars.firstIndex(where: { $0.id == id }) { cars[idx].stopped.toggle() }
    }

    func inIntersection(_ car: TfV3Car) -> Bool {
        let pos = carPos(car)
        let mid = boardSize / 2
        let half = intersectionSize / 2
        return abs(pos.x - mid) < half && abs(pos.y - mid) < half
    }

    func tick() {
        var toRemove: [UUID] = []
        for i in cars.indices {
            if !cars[i].stopped { cars[i].position += carSpeed }
            if cars[i].position > 1.05 {
                score += 1
                toRemove.append(cars[i].id)
            }
        }
        cars.removeAll { toRemove.contains($0.id) }
        let inZone = cars.filter { inIntersection($0) }
        if inZone.count >= 2 { endGame(); return }
    }

    func endGame() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        phase = .gameOver
    }
}

#Preview { TrafficViewV3() }

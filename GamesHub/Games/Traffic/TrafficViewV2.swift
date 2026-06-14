import SwiftUI

enum TfV2Phase { case start, playing, gameOver }
enum TfV2Dir { case north, south, east, west }

struct TfV2Car: Identifiable {
    let id = UUID()
    let direction: TfV2Dir
    var position: CGFloat = 0.0
    var stopped: Bool = false
}

struct TrafficViewV2: View {
    @State private var phase: TfV2Phase = .start
    @State private var cars: [TfV2Car] = []
    @State private var score: Int = 0
    @State private var spawnInterval: Double = 2.5
    @State private var carSpeed: CGFloat = 0.007
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var spawnCount: Int = 0
    @State private var recentResults: [Bool] = []

    let boardSize: CGFloat = 270
    let roadWidth: CGFloat = 58
    let intersectionSize: CGFloat = 58
    let carSize: CGFloat = 20

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.28), Color(red: 0.18, green: 0.06, blue: 0.26)],
                           startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
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
            Text("TRAFFIC").font(.system(size: 48, weight: .black)).foregroundColor(.white)
            Text("Tap cars to stop or go\nPrevent collisions in the intersection")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.75)).font(.callout)
            glassButton("START", action: startGame)
        }.padding(32)
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("COLLISION!").font(.system(size: 34, weight: .black)).foregroundColor(Color(red:1,green:0.3,blue:0.3))
            VStack(spacing: 4) {
                Text("Cars Safely Crossed").foregroundColor(.white.opacity(0.65)).font(.subheadline)
                Text("\(score)").font(.system(size: 64, weight: .black)).foregroundColor(.white)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            glassButton("RETRY", action: startGame)
        }.padding(32)
    }

    var playingScreen: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Score").foregroundColor(.white.opacity(0.65)).font(.subheadline)
                Spacer()
                Text("\(score)").font(.title.bold()).foregroundColor(.white)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.3), lineWidth: 1))
            .padding(.horizontal, 24)

            ZStack {
                roadCanvas
                ForEach(cars) { car in
                    carChip(car: car).onTapGesture { toggleCar(id: car.id) }
                }
            }
            .frame(width: boardSize, height: boardSize)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.3), lineWidth: 1))

            Text("Tap to stop/resume cars").font(.caption).foregroundColor(.white.opacity(0.45))
        }
    }

    // MARK: - Glass button

    func glassButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.headline.bold()).foregroundColor(.white)
                .padding(.horizontal, 44).padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Road

    var roadCanvas: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let rw = roadWidth
            ctx.fill(Path(CGRect(x: 0, y: mid - rw/2, width: size.width, height: rw)), with: .color(.white.opacity(0.12)))
            ctx.fill(Path(CGRect(x: mid - rw/2, y: 0, width: rw, height: size.height)), with: .color(.white.opacity(0.12)))
            ctx.fill(Path(CGRect(x: mid - intersectionSize/2, y: mid - intersectionSize/2, width: intersectionSize, height: intersectionSize)), with: .color(.white.opacity(0.18)))
        }
    }

    // MARK: - Car

    func carPos(_ car: TfV2Car) -> CGPoint {
        let mid = boardSize / 2
        let t = car.position
        switch car.direction {
        case .north: return CGPoint(x: mid - 10, y: boardSize - t * boardSize)
        case .south: return CGPoint(x: mid + 10, y: t * boardSize)
        case .west:  return CGPoint(x: boardSize - t * boardSize, y: mid - 10)
        case .east:  return CGPoint(x: t * boardSize, y: mid + 10)
        }
    }

    func carChip(car: TfV2Car) -> some View {
        let pos = carPos(car)
        return ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(car.stopped ? Color(red:1,green:0.3,blue:0.3).opacity(0.85) : Color(red:0.2,green:0.9,blue:0.5).opacity(0.85))
                .frame(width: carSize, height: carSize)
                .shadow(color: car.stopped ? .red.opacity(0.6) : .green.opacity(0.5), radius: 6)
            Circle().fill(.white.opacity(0.8)).frame(width: 5, height: 5)
        }.position(pos)
    }

    // MARK: - Logic

    func startGame() {
        cars = []
        score = 0
        spawnInterval = 2.5
        carSpeed = 0.007
        spawnCount = 0
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        phase = .playing
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in tick() }
        scheduleSpawn()
    }

    func scheduleSpawn() {
        spawnTimer?.invalidate()
        spawnTimer = Timer.scheduledTimer(withTimeInterval: spawnInterval, repeats: false) { _ in
            spawnCar()
            scheduleSpawn()
        }
    }

    func spawnCar() {
        let dir = [TfV2Dir.north, .south, .east, .west].randomElement()!
        cars.append(TfV2Car(direction: dir))
        spawnCount += 1
    }

    func toggleCar(id: UUID) {
        if let idx = cars.firstIndex(where: { $0.id == id }) { cars[idx].stopped.toggle() }
    }

    func inIntersection(_ car: TfV2Car) -> Bool {
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
        recentResults.append(score >= 5)
        if recentResults.count > 5 { recentResults.removeFirst() }
        if recentResults.count == 5 && recentResults.filter({ $0 }).count > 4 {
            spawnInterval = max(0.6, spawnInterval * 0.8)
            carSpeed = min(0.018, carSpeed * 1.2)
        }
        phase = .gameOver
    }
}

#Preview { TrafficViewV2() }

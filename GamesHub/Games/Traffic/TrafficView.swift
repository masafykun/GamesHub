import SwiftUI

enum TfGamePhase { case start, playing, gameOver }
enum TfDirection { case north, south, east, west }

struct TfCar: Identifiable {
    let id = UUID()
    let direction: TfDirection
    var position: CGFloat  // 0.0 = entering, 1.0 = exited
    var stopped: Bool = false
    var crossed: Bool = false
}

struct TrafficView: View {
    @State private var phase: TfGamePhase = .start
    @State private var cars: [TfCar] = []
    @State private var score: Int = 0
    @State private var spawnInterval: Double = 2.5
    @State private var gameTimer: Timer? = nil
    @State private var spawnTimer: Timer? = nil
    @State private var tickCount: Int = 0

    let roadWidth: CGFloat = 60
    let intersectionSize: CGFloat = 60
    let boardSize: CGFloat = 260
    let carSize: CGFloat = 20
    let speed: CGFloat = 0.007

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Screens

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("TRAFFIC").font(.system(size: 44, weight: .black)).foregroundColor(.yellow)
            Text("Tap cars to stop/go\nAvoid collisions in the intersection")
                .multilineTextAlignment(.center).foregroundColor(.white.opacity(0.8)).font(.body)
            Button(action: startGame) {
                Text("START").font(.headline).bold().padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.yellow).foregroundColor(.black).clipShape(Capsule())
            }
        }.padding()
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("COLLISION!").font(.system(size: 36, weight: .black)).foregroundColor(.red)
            Text("Cars Crossed").foregroundColor(.white.opacity(0.7))
            Text("\(score)").font(.system(size: 64, weight: .black)).foregroundColor(.yellow)
            Button(action: startGame) {
                Text("RETRY").font(.headline).bold().padding(.horizontal, 40).padding(.vertical, 14)
                    .background(Color.yellow).foregroundColor(.black).clipShape(Capsule())
            }
        }.padding()
    }

    var gameScreen: some View {
        VStack(spacing: 16) {
            Text("Score: \(score)").font(.title2.bold()).foregroundColor(.white)
            ZStack {
                roadLayer
                ForEach(cars) { car in
                    carView(car: car)
                        .onTapGesture { toggleCar(id: car.id) }
                }
            }
            .frame(width: boardSize, height: boardSize)
            Text("Tap cars to stop them").font(.caption).foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Road

    var roadLayer: some View {
        Canvas { ctx, size in
            let mid = size.width / 2
            let rw = roadWidth
            ctx.fill(Path(CGRect(x: 0, y: mid - rw/2, width: size.width, height: rw)), with: .color(.gray.opacity(0.5)))
            ctx.fill(Path(CGRect(x: mid - rw/2, y: 0, width: rw, height: size.height)), with: .color(.gray.opacity(0.5)))
            ctx.fill(Path(CGRect(x: mid - intersectionSize/2, y: mid - intersectionSize/2, width: intersectionSize, height: intersectionSize)), with: .color(.gray.opacity(0.7)))
        }
    }

    // MARK: - Car

    func carPosition(_ car: TfCar) -> CGPoint {
        let mid = boardSize / 2
        let t = car.position
        switch car.direction {
        case .north: return CGPoint(x: mid - 10, y: boardSize - t * boardSize)
        case .south: return CGPoint(x: mid + 10, y: t * boardSize)
        case .west:  return CGPoint(x: boardSize - t * boardSize, y: mid - 10)
        case .east:  return CGPoint(x: t * boardSize, y: mid + 10)
        }
    }

    func carView(car: TfCar) -> some View {
        let pos = carPosition(car)
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(car.stopped ? Color.red.opacity(0.9) : Color.green)
                .frame(width: carSize, height: carSize)
            Circle().fill(car.stopped ? Color.red : Color.white).frame(width: 6, height: 6)
        }
        .position(pos)
    }

    // MARK: - Logic

    func startGame() {
        cars = []
        score = 0
        spawnInterval = 2.5
        tickCount = 0
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
        let dir = [TfDirection.north, .south, .east, .west].randomElement()!
        cars.append(TfCar(direction: dir, position: 0.0))
        tickCount += 1
        if tickCount % 5 == 0 { spawnInterval = max(0.8, spawnInterval - 0.2) }
    }

    func toggleCar(id: UUID) {
        if let idx = cars.firstIndex(where: { $0.id == id }) {
            cars[idx].stopped.toggle()
        }
    }

    func inIntersection(_ car: TfCar) -> Bool {
        let pos = carPosition(car)
        let mid = boardSize / 2
        let half = intersectionSize / 2
        return abs(pos.x - mid) < half && abs(pos.y - mid) < half
    }

    func tick() {
        var toRemove: [UUID] = []
        for i in cars.indices {
            if !cars[i].stopped {
                cars[i].position += speed
            }
            if cars[i].position > 1.05 {
                if !cars[i].crossed { score += 1 }
                toRemove.append(cars[i].id)
            }
        }
        cars.removeAll { toRemove.contains($0.id) }
        let inZone = cars.filter { inIntersection($0) }
        if inZone.count >= 2 {
            endGame()
        }
    }

    func endGame() {
        gameTimer?.invalidate()
        spawnTimer?.invalidate()
        phase = .gameOver
    }
}

#Preview { TrafficView() }

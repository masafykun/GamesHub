import SwiftUI

struct OrbLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

enum OrbV3Phase {
    case start, playing, gameOver
}

struct OrbV3Satellite: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var isAlive: Bool = true
    var stableTime: Double = 0.0
    var scored: Bool = false
    var color: Color
    var trail: [CGPoint] = []
}

struct OrbAsteroid: Identifiable {
    let id = UUID()
    var position: CGPoint
    let radius: CGFloat
}

struct OrbitViewV3: View {
    @State private var phase: OrbV3Phase = .start
    @State private var satellites: [OrbV3Satellite] = []
    @State private var asteroids: [OrbAsteroid] = []
    @State private var score: Int = 0
    @State private var launchCount: Int = 0
    @State private var timer: Timer?
    @State private var lastTime: Date = Date()
    @State private var planetPos: CGPoint = .zero
    @State private var canvasSize: CGSize = .zero
    @State private var seedInt: Int = 1
    @State private var planetSize: CGFloat = 40

    let maxLaunches = 5
    let satelliteRadius: CGFloat = 8
    let GM: Double = 8000.0
    let stableThreshold: Double = 5.0

    var escapeDistance: Double { Double(canvasSize.width * 0.55) }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            if phase == .start {
                startScreen
            } else if phase == .playing {
                gameScreen
            } else {
                gameOverScreen
            }
        }
    }

    var startScreen: some View {
        VStack(spacing: 24) {
            Text("ORBIT")
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundColor(Color(.label))
            Text("Tap anywhere to launch a satellite.\nKeep orbit stable for 5 seconds to score.")
                .multilineTextAlignment(.center)
                .foregroundColor(Color(.secondaryLabel))
                .font(.subheadline)
            Text("Avoid procedurally placed asteroids!")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
            Button("START ORBIT") {
                startGame()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 44)
            .padding(.vertical, 14)
            .background(Color(.label))
            .cornerRadius(14)
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                // Asteroids
                ForEach(asteroids) { asteroid in
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: asteroid.radius * 2, height: asteroid.radius * 2)
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 1)
                            .frame(width: asteroid.radius * 2, height: asteroid.radius * 2)
                    }
                    .position(asteroid.position)
                }

                // Satellite trails
                ForEach(satellites) { sat in
                    if sat.isAlive && sat.trail.count > 1 {
                        OrbV3TrailShape(points: sat.trail)
                            .stroke(sat.color.opacity(0.3), lineWidth: 1.5)
                    }
                }

                // Planet
                ZStack {
                    Circle()
                        .fill(Color(.systemIndigo).opacity(0.85))
                        .frame(width: planetSize * 2, height: planetSize * 2)
                        .shadow(color: Color(.systemIndigo).opacity(0.3), radius: 8)
                    Circle()
                        .stroke(Color(.systemBlue).opacity(0.4), lineWidth: 2)
                        .frame(width: planetSize * 2, height: planetSize * 2)
                    // Orbit guide rings
                    Circle()
                        .stroke(Color(.systemGray4).opacity(0.4), lineWidth: 0.5)
                        .frame(width: 160, height: 160)
                    Circle()
                        .stroke(Color(.systemGray4).opacity(0.25), lineWidth: 0.5)
                        .frame(width: 240, height: 240)
                }
                .position(planetPos)

                // Satellites
                ForEach(satellites) { sat in
                    if sat.isAlive {
                        ZStack {
                            Circle()
                                .fill(sat.color)
                                .frame(width: satelliteRadius * 2, height: satelliteRadius * 2)
                                .shadow(color: sat.color.opacity(0.4), radius: 4)
                            if !sat.scored {
                                Circle()
                                    .trim(from: 0, to: CGFloat(sat.stableTime / stableThreshold))
                                    .stroke(sat.color, lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                    .rotationEffect(.degrees(-90))
                                    .opacity(0.7)
                            } else {
                                Circle()
                                    .stroke(Color.yellow.opacity(0.7), lineWidth: 2)
                                    .frame(width: 22, height: 22)
                            }
                        }
                        .position(sat.position)
                    }
                }

                // HUD
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SCORE: \(score)")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(Color(.label))
                            Text("SEED: #\(seedInt)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(12)
                        .neumorphicCard(radius: 12)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(launchCount)/\(maxLaunches)")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(Color(.label))
                            Text("LAUNCHES")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(12)
                        .neumorphicCard(radius: 12)
                    }
                    .padding()
                    Spacer()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { location in
                handleTap(at: location, in: geo.size)
            }
            .onAppear {
                canvasSize = geo.size
                planetPos = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                generateLevel(size: geo.size)
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("ORBIT COMPLETE")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(Color(.label))
            Text("\(score) / \(maxLaunches)")
                .font(.system(size: 56, weight: .heavy, design: .monospaced))
                .foregroundColor(Color(.systemIndigo))
            Text("stable orbits achieved")
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
            Text("Seed #\(seedInt - 1)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color(.tertiaryLabel))
            HStack(spacing: 16) {
                Button("NEW SEED") {
                    startGame()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Color(.label))
                .cornerRadius(12)

                Button("MENU") {
                    phase = .start
                }
                .font(.headline)
                .foregroundColor(Color(.label))
                .padding(.horizontal, 28).padding(.vertical, 12)
                .neumorphicCard(radius: 12)
            }
        }
        .padding(32)
        .neumorphicCard(radius: 20)
        .padding(32)
    }

    func startGame() {
        satellites = []
        score = 0
        launchCount = 0
        phase = .playing
        lastTime = Date()
        seedInt += 1
        timer?.invalidate()
        if !canvasSize.equalTo(.zero) {
            generateLevel(size: canvasSize)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            updatePhysics()
        }
    }

    func generateLevel(size: CGSize) {
        var lcg = OrbLCG(seed: seedInt)
        let cx = size.width / 2
        let cy = size.height / 2

        // Vary planet size per seed
        planetSize = CGFloat(35 + lcg.nextInt(20))

        // Generate asteroids
        var newAsteroids: [OrbAsteroid] = []
        let count = 3 + lcg.nextInt(4)
        for _ in 0..<count {
            let angle = lcg.nextDouble() * .pi * 2
            let radius = 100.0 + lcg.nextDouble() * 100.0
            let ax = cx + CGFloat(cos(angle) * radius)
            let ay = cy + CGFloat(sin(angle) * radius)
            let ar = CGFloat(8 + lcg.nextInt(12))
            newAsteroids.append(OrbAsteroid(position: CGPoint(x: ax, y: ay), radius: ar))
        }
        asteroids = newAsteroids
    }

    let satelliteColors: [Color] = [.red, .orange, .green, .blue, .purple]

    func handleTap(at location: CGPoint, in size: CGSize) {
        guard launchCount < maxLaunches else { return }
        let dx = Double(location.x - planetPos.x)
        let dy = Double(location.y - planetPos.y)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > Double(planetSize) + Double(satelliteRadius) + 5 else { return }
        let speed = sqrt(GM / dist) * 0.85
        let vx = -dy / dist * speed
        let vy = dx / dist * speed
        let color = satelliteColors[launchCount % satelliteColors.count]
        var sat = OrbV3Satellite(
            position: location,
            velocity: CGVector(dx: vx, dy: vy),
            color: color
        )
        sat.trail = [location]
        satellites.append(sat)
        launchCount += 1
    }

    func updatePhysics() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTime), 0.05)
        lastTime = now

        for i in satellites.indices {
            guard satellites[i].isAlive else { continue }
            let dx = Double(planetPos.x - satellites[i].position.x)
            let dy = Double(planetPos.y - satellites[i].position.y)
            let distSq = dx * dx + dy * dy
            let dist = sqrt(distSq)

            if dist < Double(planetSize) + Double(satelliteRadius) {
                satellites[i].isAlive = false
                checkGameOver()
                continue
            }
            if dist > escapeDistance {
                satellites[i].isAlive = false
                checkGameOver()
                continue
            }

            // Check asteroid collisions
            var hitAsteroid = false
            for asteroid in asteroids {
                let adx = Double(asteroid.position.x - satellites[i].position.x)
                let ady = Double(asteroid.position.y - satellites[i].position.y)
                let adist = sqrt(adx * adx + ady * ady)
                if adist < Double(asteroid.radius) + Double(satelliteRadius) {
                    hitAsteroid = true
                    break
                }
            }
            if hitAsteroid {
                satellites[i].isAlive = false
                checkGameOver()
                continue
            }

            let grav = GM / distSq
            let ax = grav * dx / dist
            let ay = grav * dy / dist
            satellites[i].velocity.dx += ax * dt
            satellites[i].velocity.dy += ay * dt
            satellites[i].position.x += CGFloat(satellites[i].velocity.dx * dt)
            satellites[i].position.y += CGFloat(satellites[i].velocity.dy * dt)

            // Update trail
            satellites[i].trail.append(satellites[i].position)
            if satellites[i].trail.count > 50 {
                satellites[i].trail.removeFirst()
            }

            if !satellites[i].scored {
                satellites[i].stableTime += dt
                if satellites[i].stableTime >= stableThreshold {
                    satellites[i].scored = true
                    score += 1
                }
            }
        }
    }

    func checkGameOver() {
        let active = satellites.filter { $0.isAlive }.count
        if active == 0 && launchCount >= maxLaunches {
            timer?.invalidate()
            phase = .gameOver
        }
    }
}

struct OrbV3TrailShape: Shape {
    var points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        return path
    }
}

#Preview { OrbitViewV3() }

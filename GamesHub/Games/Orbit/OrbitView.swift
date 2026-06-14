import SwiftUI

enum OrbGamePhase {
    case start, playing, gameOver
}

struct OrbSatellite: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var isAlive: Bool = true
    var stableTime: Double = 0.0
    var scored: Bool = false
}

struct OrbitView: View {
    @State private var phase: OrbGamePhase = .start
    @State private var satellites: [OrbSatellite] = []
    @State private var score: Int = 0
    @State private var launchCount: Int = 0
    @State private var timer: Timer?
    @State private var lastTime: Date = Date()
    @State private var planetPos: CGPoint = .zero
    @State private var canvasSize: CGSize = .zero

    let maxLaunches = 5
    let planetRadius: CGFloat = 40
    let satelliteRadius: CGFloat = 8
    let GM: Double = 8000.0
    let escapeDistance: Double = 400.0
    let stableThreshold: Double = 5.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

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
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            Text("Tap to launch satellites\ninto stable orbit")
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
            Text("Keep orbit stable for 5 sec = +1 score")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
            Button("LAUNCH") {
                startGame()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.cyan)
            .cornerRadius(10)
        }
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                // Stars background
                ForEach(0..<50, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 2, height: 2)
                        .position(x: CGFloat((i * 137) % Int(geo.size.width)),
                                  y: CGFloat((i * 97 + 40) % Int(geo.size.height)))
                }

                // Planet
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [.blue, .indigo, .purple.opacity(0.6)],
                                             center: .topLeading,
                                             startRadius: 5,
                                             endRadius: 60))
                        .frame(width: planetRadius * 2, height: planetRadius * 2)
                    Circle()
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                        .frame(width: planetRadius * 2, height: planetRadius * 2)
                }
                .position(planetPos)

                // Satellites
                ForEach(satellites) { sat in
                    if sat.isAlive {
                        ZStack {
                            Circle()
                                .fill(sat.scored ? Color.yellow : Color.white)
                                .frame(width: satelliteRadius * 2, height: satelliteRadius * 2)
                            if sat.scored {
                                Circle()
                                    .stroke(Color.yellow.opacity(0.6), lineWidth: 3)
                                    .frame(width: satelliteRadius * 2 + 6, height: satelliteRadius * 2 + 6)
                            }
                        }
                        .position(sat.position)
                    }
                }

                // HUD
                VStack {
                    HStack {
                        Text("SCORE: \(score)")
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("LAUNCHES: \(launchCount)/\(maxLaunches)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
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
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("MISSION COMPLETE")
                .font(.system(size: 28, weight: .bold, design: .monospaced))
                .foregroundColor(.cyan)
            Text("SCORE: \(score) / \(maxLaunches)")
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Button("RETRY") {
                startGame()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(Color.cyan)
            .cornerRadius(10)
            Button("MENU") {
                phase = .start
            }
            .foregroundColor(.gray)
        }
    }

    func startGame() {
        satellites = []
        score = 0
        launchCount = 0
        phase = .playing
        lastTime = Date()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { _ in
            updatePhysics()
        }
    }

    func handleTap(at location: CGPoint, in size: CGSize) {
        guard launchCount < maxLaunches else { return }
        let dx = Double(location.x - planetPos.x)
        let dy = Double(location.y - planetPos.y)
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > Double(planetRadius) + Double(satelliteRadius) + 5 else { return }
        // Tangent velocity perpendicular to radius
        let speed = sqrt(GM / dist) * 0.85
        let vx = -dy / dist * speed
        let vy = dx / dist * speed
        let sat = OrbSatellite(position: location, velocity: CGVector(dx: vx, dy: vy))
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

            // Crash check
            if dist < Double(planetRadius) + Double(satelliteRadius) {
                satellites[i].isAlive = false
                checkGameOver()
                continue
            }

            // Escape check
            if dist > escapeDistance {
                satellites[i].isAlive = false
                checkGameOver()
                continue
            }

            // Gravity acceleration
            let grav = GM / distSq
            let ax = grav * dx / dist
            let ay = grav * dy / dist

            satellites[i].velocity.dx += ax * dt
            satellites[i].velocity.dy += ay * dt
            satellites[i].position.x += CGFloat(satellites[i].velocity.dx * dt)
            satellites[i].position.y += CGFloat(satellites[i].velocity.dy * dt)

            // Stable time tracking
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
        let remaining = maxLaunches - launchCount
        if active == 0 && remaining == 0 {
            timer?.invalidate()
            phase = .gameOver
        }
    }
}

#Preview { OrbitView() }

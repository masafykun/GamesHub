import SwiftUI

enum OrbV2Phase {
    case start, playing, gameOver
}

struct OrbV2Satellite: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGVector
    var isAlive: Bool = true
    var stableTime: Double = 0.0
    var scored: Bool = false
    var trail: [CGPoint] = []
}

struct OrbitViewV2: View {
    @State private var phase: OrbV2Phase = .start
    @State private var satellites: [OrbV2Satellite] = []
    @State private var score: Int = 0
    @State private var launchCount: Int = 0
    @State private var timer: Timer?
    @State private var lastTime: Date = Date()
    @State private var planetPos: CGPoint = .zero
    @State private var recentResults: [Bool] = []
    @State private var difficultyMultiplier: Double = 1.0

    let maxLaunches = 5
    let planetRadius: CGFloat = 40
    let satelliteRadius: CGFloat = 8
    let baseGM: Double = 8000.0
    let baseEscape: Double = 400.0
    let stableThreshold: Double = 5.0

    var GM: Double { baseGM * difficultyMultiplier }
    var escapeDistance: Double { baseEscape / difficultyMultiplier }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.25),
                         Color(red: 0.15, green: 0.05, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()

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
        VStack(spacing: 28) {
            Text("ORBIT")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.cyan, .purple], startPoint: .leading, endPoint: .trailing))
            Text("Tap to launch satellites into stable orbit\nHold for 5 seconds to score a point")
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.7))
                .font(.subheadline)
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: x\(String(format: "%.1f", difficultyMultiplier))")
                    .font(.caption)
                    .foregroundColor(.orange.opacity(0.8))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            Button("BEGIN MISSION") { startGame() }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 44)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
                .shadow(color: .cyan.opacity(0.4), radius: 12)
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
    }

    var gameScreen: some View {
        GeometryReader { geo in
            ZStack {
                // Starfield
                ForEach(0..<60, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(Double((i % 5) + 1) / 10.0))
                        .frame(width: CGFloat((i % 3) + 1), height: CGFloat((i % 3) + 1))
                        .position(x: CGFloat((i * 173) % Int(geo.size.width)),
                                  y: CGFloat((i * 113 + 60) % Int(geo.size.height)))
                }

                // Satellite trails
                ForEach(satellites) { sat in
                    if sat.isAlive && sat.trail.count > 1 {
                        OrbTrailShape(points: sat.trail)
                            .stroke(
                                LinearGradient(colors: [.cyan.opacity(0), .cyan.opacity(0.5)],
                                               startPoint: .leading, endPoint: .trailing),
                                lineWidth: 1.5
                            )
                    }
                }

                // Planet
                ZStack {
                    Circle()
                        .fill(RadialGradient(
                            colors: [.cyan.opacity(0.8), .blue.opacity(0.6), .purple.opacity(0.3)],
                            center: .topLeading, startRadius: 5, endRadius: 80
                        ))
                        .frame(width: planetRadius * 2, height: planetRadius * 2)
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                        .frame(width: planetRadius * 2, height: planetRadius * 2)
                    // Gravity ring
                    Circle()
                        .stroke(.cyan.opacity(0.1), lineWidth: 1)
                        .frame(width: 150, height: 150)
                    Circle()
                        .stroke(.cyan.opacity(0.07), lineWidth: 1)
                        .frame(width: 250, height: 250)
                }
                .position(planetPos)

                // Satellites
                ForEach(satellites) { sat in
                    if sat.isAlive {
                        ZStack {
                            Circle()
                                .fill(sat.scored ? Color.yellow : Color.white)
                                .frame(width: satelliteRadius * 2, height: satelliteRadius * 2)
                                .shadow(color: sat.scored ? .yellow : .white, radius: 4)
                            if sat.scored {
                                Circle()
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                                    .frame(width: 22, height: 22)
                            } else {
                                // Progress ring
                                Circle()
                                    .trim(from: 0, to: CGFloat(sat.stableTime / stableThreshold))
                                    .stroke(.cyan.opacity(0.8), lineWidth: 2)
                                    .frame(width: 22, height: 22)
                                    .rotationEffect(.degrees(-90))
                            }
                        }
                        .position(sat.position)
                    }
                }

                // HUD
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SCORE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(score)")
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("LAUNCHES")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(launchCount)/\(maxLaunches)")
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.3), lineWidth: 1))
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
                planetPos = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
    }

    var gameOverScreen: some View {
        VStack(spacing: 20) {
            Text("MISSION COMPLETE")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("\(score)")
                .font(.system(size: 72, weight: .bold, design: .monospaced))
                .foregroundStyle(LinearGradient(colors: [.cyan, .yellow], startPoint: .top, endPoint: .bottom))
            Text("out of \(maxLaunches) stable orbits")
                .foregroundColor(.white.opacity(0.6))
            if difficultyMultiplier > 1.0 {
                Text("Difficulty: x\(String(format: "%.1f", difficultyMultiplier))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            HStack(spacing: 16) {
                Button("RETRY") { startGame() }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(.cyan)
                    .clipShape(Capsule())
                Button("MENU") { phase = .start }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(32)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.3), lineWidth: 1))
        .padding(32)
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
        let speed = sqrt(GM / dist) * 0.85
        let vx = -dy / dist * speed
        let vy = dx / dist * speed
        var sat = OrbV2Satellite(position: location, velocity: CGVector(dx: vx, dy: vy))
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

            if dist < Double(planetRadius) + Double(satelliteRadius) {
                satellites[i].isAlive = false
                recordResult(scored: satellites[i].scored)
                checkGameOver()
                continue
            }
            if dist > escapeDistance {
                satellites[i].isAlive = false
                recordResult(scored: false)
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
            if satellites[i].trail.count == 0 || dist > 2 {
                satellites[i].trail.append(satellites[i].position)
                if satellites[i].trail.count > 40 {
                    satellites[i].trail.removeFirst()
                }
            }

            if !satellites[i].scored {
                satellites[i].stableTime += dt
                if satellites[i].stableTime >= stableThreshold {
                    satellites[i].scored = true
                    score += 1
                    recordResult(scored: true)
                }
            }
        }
    }

    func recordResult(scored: Bool) {
        recentResults.append(scored)
        if recentResults.count > 10 { recentResults.removeFirst() }
        let lastFive = recentResults.suffix(5)
        if lastFive.count == 5 && lastFive.filter({ $0 }).count > 4 {
            difficultyMultiplier = min(difficultyMultiplier * 1.2, 3.0)
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

struct OrbTrailShape: Shape {
    var points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        path.move(to: points[0])
        for pt in points.dropFirst() { path.addLine(to: pt) }
        return path
    }
}

#Preview { OrbitViewV2() }

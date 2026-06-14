import SwiftUI

// MARK: - PixelArtViewV2 (Glassmorphism Style)

struct PixelArtViewV2: View {

    // MARK: - Private Patterns

    private static let patterns: [[[Int]]] = [
        // Pattern 0: Heart
        [
            [0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,1,1,1,0,0,1,1,1,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,0,0,1,1,1,1,1,1,0,0,0],
            [0,0,0,0,1,1,1,1,0,0,0,0],
            [0,0,0,0,0,1,1,0,0,0,0,0],
        ],
        // Pattern 1: Smiley Face
        [
            [0,0,0,0,0,0,0,0,0,0,0,0],
            [0,0,0,3,3,3,3,3,3,0,0,0],
            [0,0,3,3,3,3,3,3,3,3,0,0],
            [0,3,3,0,0,3,3,0,0,3,3,0],
            [0,3,3,0,0,3,3,0,0,3,3,0],
            [0,3,3,3,3,3,3,3,3,3,3,0],
            [0,3,3,1,3,3,3,3,1,3,3,0],
            [0,3,3,3,1,3,3,1,3,3,3,0],
            [0,3,3,3,3,1,1,3,3,3,3,0],
            [0,0,3,3,3,3,3,3,3,3,0,0],
            [0,0,0,3,3,3,3,3,3,0,0,0],
            [0,0,0,0,0,0,0,0,0,0,0,0],
        ],
        // Pattern 2: Star
        [
            [0,0,0,0,0,3,3,0,0,0,0,0],
            [0,0,0,0,0,3,3,0,0,0,0,0],
            [0,0,0,0,3,3,3,3,0,0,0,0],
            [3,3,3,3,3,3,3,3,3,3,3,3],
            [0,3,3,3,3,3,3,3,3,3,3,0],
            [0,0,3,3,3,3,3,3,3,3,0,0],
            [0,0,0,3,3,3,3,3,3,0,0,0],
            [0,0,3,3,0,3,3,0,3,3,0,0],
            [0,3,3,0,0,3,3,0,0,3,3,0],
            [3,3,0,0,0,3,3,0,0,0,3,3],
            [0,0,0,0,0,3,3,0,0,0,0,0],
            [0,0,0,0,0,3,3,0,0,0,0,0],
        ],
        // Pattern 3: House
        [
            [0,0,0,0,0,1,1,0,0,0,0,0],
            [0,0,0,0,1,1,1,1,0,0,0,0],
            [0,0,0,1,1,1,1,1,1,0,0,0],
            [0,0,1,1,1,1,1,1,1,1,0,0],
            [0,1,1,1,1,1,1,1,1,1,1,0],
            [1,1,1,1,1,1,1,1,1,1,1,1],
            [0,2,2,2,2,2,2,2,2,2,2,0],
            [0,2,2,2,2,2,2,2,2,2,2,0],
            [0,2,2,4,4,2,2,4,4,2,2,0],
            [0,2,2,4,4,2,2,4,4,2,2,0],
            [0,2,2,2,2,4,4,2,2,2,2,0],
            [0,2,2,2,2,4,4,2,2,2,2,0],
        ],
        // Pattern 4: Rocket
        [
            [0,0,0,0,0,5,5,0,0,0,0,0],
            [0,0,0,0,5,5,5,5,0,0,0,0],
            [0,0,0,5,5,5,5,5,5,0,0,0],
            [0,0,0,5,5,1,1,5,5,0,0,0],
            [0,0,0,5,5,1,1,5,5,0,0,0],
            [0,0,0,5,5,5,5,5,5,0,0,0],
            [0,0,1,5,5,5,5,5,5,1,0,0],
            [0,0,1,5,5,5,5,5,5,1,0,0],
            [0,0,0,5,5,5,5,5,5,0,0,0],
            [0,0,0,0,5,2,2,5,0,0,0,0],
            [0,0,0,0,2,2,2,2,0,0,0,0],
            [0,0,0,0,2,0,0,2,0,0,0,0],
        ],
    ]

    private static let patternNames = ["Heart", "Smiley", "Star", "House", "Rocket"]

    private static let colors: [Color] = [
        .clear,
        .red,
        .orange,
        .yellow,
        .green,
        .blue,
        .purple
    ]

    private static let accentColors: [Color] = [
        .clear, .red, .orange, .yellow, .green, .blue, .purple
    ]

    // MARK: - State

    @State private var userGrid: [[Int]] = Array(repeating: Array(repeating: 0, count: 12), count: 12)
    @State private var selectedColor: Int = 1
    @State private var currentPattern: Int = 0
    @State private var isComplete: Bool = false
    @State private var showTarget: Bool = false
    @State private var lastPaintedCell: (Int, Int)? = nil
    @State private var glowPulse: Bool = false

    private var targetPattern: [[Int]] { Self.patterns[currentPattern] }
    private var accentColor: Color { Self.accentColors[selectedColor] }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.20),
                    Color(red: 0.10, green: 0.05, blue: 0.28),
                    Color(red: 0.08, green: 0.10, blue: 0.25),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Ambient glow blobs
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: -80, y: -150)
                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: glowPulse)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 250, height: 250)
                .blur(radius: 60)
                .offset(x: 100, y: 200)

            VStack(spacing: 12) {
                // Title
                Text("Pixel Art")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: accentColor.opacity(0.6), radius: 12)
                    .padding(.top, 16)

                // Pattern picker card
                patternPickerCard
                    .padding(.horizontal, 20)

                // Grid card
                ZStack {
                    gridCard
                    if isComplete {
                        completeOverlay
                    }
                }
                .padding(.horizontal, 20)

                // Hint toggle
                hintCard
                    .padding(.horizontal, 20)

                // Color palette
                paletteCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .onAppear { glowPulse.toggle() }
    }

    // MARK: - Subviews

    private var patternPickerCard: some View {
        HStack {
            Button(action: previousPattern) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(currentPattern == 0 ? Color.white.opacity(0.3) : Color.white)
                    .shadow(color: .white.opacity(0.3), radius: 4)
            }
            .disabled(currentPattern == 0)

            Spacer()

            VStack(spacing: 3) {
                Text(Self.patternNames[currentPattern])
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(currentPattern + 1) of \(Self.patterns.count)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button(action: nextPattern) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(currentPattern == Self.patterns.count - 1 ? Color.white.opacity(0.3) : Color.white)
                    .shadow(color: .white.opacity(0.3), radius: 4)
            }
            .disabled(currentPattern == Self.patterns.count - 1)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
    }

    private var gridCard: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let size = min(geo.size.width / 12, 28.0)
                let gridSize = size * 12
                ZStack {
                    if showTarget {
                        targetOverlayV2(cellSize: size)
                            .frame(width: gridSize, height: gridSize)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    userGridViewV2(cellSize: size)
                        .frame(width: gridSize, height: gridSize)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .gesture(paintGesture(cellSize: size, origin: CGPoint(
                            x: (geo.size.width - gridSize) / 2,
                            y: (geo.size.height - gridSize) / 2
                        )))
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(12)
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: accentColor.opacity(0.4), radius: 20, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private func userGridViewV2(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        let colorIdx = userGrid[row][col]
                        Rectangle()
                            .fill(colorIdx == 0 ? Color.white.opacity(0.08) : Self.colors[colorIdx])
                            .frame(width: cellSize - 1, height: cellSize - 1)
                            .shadow(
                                color: colorIdx == 0 ? .clear : Self.colors[colorIdx].opacity(0.5),
                                radius: colorIdx == 0 ? 0 : 2
                            )
                    }
                }
            }
        }
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func targetOverlayV2(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        let colorIdx = targetPattern[row][col]
                        Rectangle()
                            .fill(colorIdx == 0 ? Color.clear : Self.colors[colorIdx].opacity(0.3))
                            .frame(width: cellSize - 1, height: cellSize - 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hintCard: some View {
        HStack {
            Label("Show Hint", systemImage: showTarget ? "eye.fill" : "eye")
                .foregroundStyle(.white)
                .font(.subheadline)
            Spacer()
            Toggle("", isOn: $showTarget)
                .labelsHidden()
                .tint(accentColor)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var paletteCard: some View {
        HStack(spacing: 10) {
            ForEach(1..<Self.colors.count, id: \.self) { idx in
                Button(action: { selectedColor = idx }) {
                    ZStack {
                        Circle()
                            .fill(Self.colors[idx])
                            .frame(width: 36, height: 36)
                            .shadow(
                                color: selectedColor == idx ? Self.colors[idx].opacity(0.8) : .clear,
                                radius: selectedColor == idx ? 10 : 0
                            )

                        if selectedColor == idx {
                            Circle()
                                .stroke(Color.white, lineWidth: 2.5)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .scaleEffect(selectedColor == idx ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: selectedColor)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: accentColor.opacity(0.4), radius: 16, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var completeOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 16) {
                Text("Perfect! ⭐")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .yellow.opacity(0.8), radius: 16)

                Text("Pattern matched!")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.8))

                HStack(spacing: 12) {
                    Button("Next Pattern") {
                        if currentPattern < Self.patterns.count - 1 { nextPattern() }
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(accentColor.opacity(0.7))
                    .clipShape(Capsule())
                    .disabled(currentPattern == Self.patterns.count - 1)

                    Button("Try Again") { clearGrid() }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .padding(28)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .yellow.opacity(0.3), radius: 20)
            .padding(24)
        }
    }

    // MARK: - Gesture

    private func paintGesture(cellSize: CGFloat, origin: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                let loc = value.location
                let col = Int((loc.x - origin.x) / cellSize)
                let row = Int((loc.y - origin.y) / cellSize)
                guard row >= 0, row < 12, col >= 0, col < 12 else { return }
                let cell = (row, col)
                if let last = lastPaintedCell, last == cell { return }
                lastPaintedCell = cell
                paintCell(row: row, col: col)
            }
            .onEnded { _ in lastPaintedCell = nil }
    }

    // MARK: - Actions

    private func paintCell(row: Int, col: Int) {
        if userGrid[row][col] == selectedColor {
            userGrid[row][col] = 0
        } else {
            userGrid[row][col] = selectedColor
        }
        checkCompletion()
    }

    private func checkCompletion() {
        isComplete = userGrid == targetPattern
    }

    private func clearGrid() {
        userGrid = Array(repeating: Array(repeating: 0, count: 12), count: 12)
        isComplete = false
    }

    private func nextPattern() {
        guard currentPattern < Self.patterns.count - 1 else { return }
        currentPattern += 1
        clearGrid()
    }

    private func previousPattern() {
        guard currentPattern > 0 else { return }
        currentPattern -= 1
        clearGrid()
    }
}

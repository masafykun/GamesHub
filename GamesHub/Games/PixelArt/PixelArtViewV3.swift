import SwiftUI

// MARK: - PixelArtViewV3 (Neumorphism Style)

struct PixelArtViewV3: View {

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

    // Muted neumorphic-friendly versions
    private static let softColors: [Color] = [
        .clear,
        Color(red: 0.9, green: 0.3, blue: 0.3),
        Color(red: 0.95, green: 0.6, blue: 0.2),
        Color(red: 0.95, green: 0.85, blue: 0.2),
        Color(red: 0.3, green: 0.75, blue: 0.4),
        Color(red: 0.3, green: 0.5, blue: 0.9),
        Color(red: 0.65, green: 0.3, blue: 0.85),
    ]

    private static let bgColor = Color(red: 0.92, green: 0.92, blue: 0.94)

    // MARK: - State

    @State private var userGrid: [[Int]] = Array(repeating: Array(repeating: 0, count: 12), count: 12)
    @State private var selectedColor: Int = 1
    @State private var currentPattern: Int = 0
    @State private var isComplete: Bool = false
    @State private var showTarget: Bool = false
    @State private var lastPaintedCell: (Int, Int)? = nil

    private var targetPattern: [[Int]] { Self.patterns[currentPattern] }

    // MARK: - Body

    var body: some View {
        ZStack {
            Self.bgColor.ignoresSafeArea()

            VStack(spacing: 14) {
                // Title
                Text("Pixel Art")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.35))
                    .padding(.top, 16)
                    .shadow(color: .white.opacity(0.9), radius: 1, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.08), radius: 1, x: 1, y: 1)

                // Pattern picker
                patternPickerV3
                    .padding(.horizontal, 20)

                // Grid
                ZStack {
                    gridCardV3
                    if isComplete {
                        completeOverlayV3
                    }
                }
                .padding(.horizontal, 20)

                // Hint
                hintRowV3
                    .padding(.horizontal, 20)

                // Palette
                paletteV3
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Subviews

    private var patternPickerV3: some View {
        HStack {
            Button(action: previousPattern) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(currentPattern == 0 ? Color.gray.opacity(0.4) : Color(red: 0.4, green: 0.4, blue: 0.5))
                    .frame(width: 38, height: 38)
                    .background(Self.bgColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.85), radius: 6, x: -4, y: -4)
            }
            .disabled(currentPattern == 0)

            Spacer()

            VStack(spacing: 4) {
                Text(Self.patternNames[currentPattern])
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.30))
                Text("\(currentPattern + 1) / \(Self.patterns.count)")
                    .font(.caption)
                    .foregroundStyle(Color.gray.opacity(0.7))
            }

            Spacer()

            Button(action: nextPattern) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(currentPattern == Self.patterns.count - 1 ? Color.gray.opacity(0.4) : Color(red: 0.4, green: 0.4, blue: 0.5))
                    .frame(width: 38, height: 38)
                    .background(Self.bgColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.85), radius: 6, x: -4, y: -4)
            }
            .disabled(currentPattern == Self.patterns.count - 1)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
        .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    private var gridCardV3: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                let size = min(geo.size.width / 12, 28.0)
                let gridSize = size * 12
                ZStack {
                    if showTarget {
                        targetOverlayV3(cellSize: size)
                            .frame(width: gridSize, height: gridSize)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    neuGridV3(cellSize: size)
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
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
        .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    private func neuGridV3(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        let colorIdx = userGrid[row][col]
                        ZStack {
                            // Inset background for empty, raised for filled
                            if colorIdx == 0 {
                                Rectangle()
                                    .fill(Self.bgColor)
                                    .frame(width: cellSize - 1, height: cellSize - 1)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                                    )
                                    // Inset shadow for empty cells
                                    .shadow(color: .black.opacity(0.12), radius: 1, x: 1, y: 1)
                            } else {
                                Rectangle()
                                    .fill(Self.softColors[colorIdx])
                                    .frame(width: cellSize - 1, height: cellSize - 1)
                                    .shadow(color: Self.softColors[colorIdx].opacity(0.5), radius: 2, x: 1, y: 1)
                                    .shadow(color: .white.opacity(0.4), radius: 1, x: -1, y: -1)
                            }
                        }
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Self.bgColor)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 2, y: 2)
                .shadow(color: .white.opacity(0.6), radius: 4, x: -2, y: -2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func targetOverlayV3(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        let colorIdx = targetPattern[row][col]
                        Rectangle()
                            .fill(colorIdx == 0 ? Color.clear : Self.softColors[colorIdx].opacity(0.25))
                            .frame(width: cellSize - 1, height: cellSize - 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hintRowV3: some View {
        HStack {
            Label("Show Hint", systemImage: showTarget ? "eye.fill" : "eye")
                .font(.subheadline)
                .foregroundStyle(Color(red: 0.3, green: 0.3, blue: 0.35))

            Spacer()

            // Custom neumorphic toggle
            ZStack {
                Capsule()
                    .fill(Self.bgColor)
                    .frame(width: 48, height: 28)
                    .shadow(color: .black.opacity(0.18), radius: 4, x: 2, y: 2)
                    .shadow(color: .white.opacity(0.7), radius: 4, x: -2, y: -2)

                if showTarget {
                    Capsule()
                        .fill(Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.3))
                        .frame(width: 48, height: 28)
                }

                Circle()
                    .fill(showTarget ? Color(red: 0.3, green: 0.5, blue: 0.9) : Self.bgColor)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 1, y: 1)
                    .shadow(color: .white.opacity(0.8), radius: 2, x: -1, y: -1)
                    .offset(x: showTarget ? 10 : -10)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showTarget)
            }
            .onTapGesture { showTarget.toggle() }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
        .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    private var paletteV3: some View {
        HStack(spacing: 10) {
            ForEach(1..<Self.softColors.count, id: \.self) { idx in
                Button(action: { selectedColor = idx }) {
                    ZStack {
                        Circle()
                            .fill(Self.bgColor)
                            .frame(width: 38, height: 38)
                            .shadow(
                                color: selectedColor == idx ? .black.opacity(0.08) : .black.opacity(0.18),
                                radius: selectedColor == idx ? 3 : 6,
                                x: selectedColor == idx ? 2 : 4,
                                y: selectedColor == idx ? 2 : 4
                            )
                            .shadow(
                                color: selectedColor == idx ? .black.opacity(0.05) : .white.opacity(0.85),
                                radius: selectedColor == idx ? 3 : 6,
                                x: selectedColor == idx ? -2 : -4,
                                y: selectedColor == idx ? -2 : -4
                            )

                        Circle()
                            .fill(Self.softColors[idx])
                            .frame(width: selectedColor == idx ? 22 : 26, height: selectedColor == idx ? 22 : 26)
                            .shadow(color: Self.softColors[idx].opacity(0.5), radius: 3, x: 1, y: 1)
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selectedColor)
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .background(Self.bgColor)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 4, y: 4)
        .shadow(color: .white.opacity(0.7), radius: 8, x: -4, y: -4)
    }

    private var completeOverlayV3: some View {
        ZStack {
            Self.bgColor.opacity(0.85)
                .clipShape(RoundedRectangle(cornerRadius: 20))

            VStack(spacing: 16) {
                Text("Perfect! ⭐")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.25, green: 0.25, blue: 0.30))
                    .shadow(color: .white.opacity(0.9), radius: 2, x: -1, y: -1)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 1, y: 1)

                Text("Pattern matched!")
                    .font(.subheadline)
                    .foregroundStyle(Color.gray.opacity(0.7))

                HStack(spacing: 14) {
                    Button("Next") {
                        if currentPattern < Self.patterns.count - 1 { nextPattern() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(red: 0.3, green: 0.5, blue: 0.9))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Self.bgColor)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 3, y: 3)
                    .shadow(color: .white.opacity(0.8), radius: 6, x: -3, y: -3)
                    .disabled(currentPattern == Self.patterns.count - 1)

                    Button("Again") { clearGrid() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.4, green: 0.4, blue: 0.45))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Self.bgColor)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 6, x: 3, y: 3)
                        .shadow(color: .white.opacity(0.8), radius: 6, x: -3, y: -3)
                }
            }
            .padding(30)
            .background(Self.bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 5, y: 5)
            .shadow(color: .white.opacity(0.75), radius: 10, x: -5, y: -5)
            .padding(28)
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

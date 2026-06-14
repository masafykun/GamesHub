import SwiftUI

// MARK: - PixelArtView (Standard Style)

struct PixelArtView: View {

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
        NavigationStack {
            VStack(spacing: 0) {
                patternPickerView
                    .padding(.horizontal)
                    .padding(.top, 8)

                Spacer(minLength: 8)

                ZStack {
                    gridView
                    if isComplete {
                        completeOverlay
                    }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 8)

                hintToggle
                    .padding(.horizontal)

                colorPalette
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }
            .navigationTitle("Pixel Art")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { clearGrid() }
                }
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Subviews

    private var patternPickerView: some View {
        HStack {
            Button(action: previousPattern) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(currentPattern == 0)

            Spacer()

            VStack(spacing: 2) {
                Text(Self.patternNames[currentPattern])
                    .font(.headline)
                Text("\(currentPattern + 1) / \(Self.patterns.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: nextPattern) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .disabled(currentPattern == Self.patterns.count - 1)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var gridView: some View {
        GeometryReader { geo in
            let size = min((geo.size.width) / 12, 28.0)
            let gridSize = size * 12
            ZStack {
                // Target hint overlay
                if showTarget {
                    targetOverlay(cellSize: size)
                        .frame(width: gridSize, height: gridSize)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                // User grid
                userGridView(cellSize: size)
                    .frame(width: gridSize, height: gridSize)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .gesture(paintGesture(cellSize: size, origin: CGPoint(
                        x: (geo.size.width - gridSize) / 2,
                        y: (geo.size.height - gridSize) / 2
                    )))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func userGridView(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        cellView(row: row, col: col, cellSize: cellSize)
                    }
                }
            }
        }
        .background(Color(.systemGray4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func cellView(row: Int, col: Int, cellSize: CGFloat) -> some View {
        let colorIdx = userGrid[row][col]
        return Rectangle()
            .fill(colorIdx == 0 ? Color(.systemBackground) : Self.colors[colorIdx])
            .frame(width: cellSize - 1, height: cellSize - 1)
    }

    private func targetOverlay(cellSize: CGFloat) -> some View {
        VStack(spacing: 1) {
            ForEach(0..<12, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(0..<12, id: \.self) { col in
                        let colorIdx = targetPattern[row][col]
                        Rectangle()
                            .fill(colorIdx == 0 ? Color.clear : Self.colors[colorIdx].opacity(0.35))
                            .frame(width: cellSize - 1, height: cellSize - 1)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var hintToggle: some View {
        Toggle(isOn: $showTarget) {
            Label("Show Hint", systemImage: "eye")
                .font(.subheadline)
        }
        .toggleStyle(.switch)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var colorPalette: some View {
        HStack(spacing: 12) {
            ForEach(1..<Self.colors.count, id: \.self) { idx in
                Button(action: { selectedColor = idx }) {
                    Circle()
                        .fill(Self.colors[idx])
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle()
                                .stroke(selectedColor == idx ? Color.primary : Color.clear, lineWidth: 3)
                        )
                        .shadow(color: selectedColor == idx ? Self.colors[idx].opacity(0.6) : .clear, radius: 6)
                        .scaleEffect(selectedColor == idx ? 1.15 : 1.0)
                        .animation(.spring(response: 0.3), value: selectedColor)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.top, 8)
    }

    private var completeOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Perfect! ⭐")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                Text("You matched the pattern!")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
                HStack(spacing: 12) {
                    Button("Next") {
                        if currentPattern < Self.patterns.count - 1 {
                            nextPattern()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentPattern == Self.patterns.count - 1)

                    Button("Try Again") { clearGrid() }
                        .buttonStyle(.bordered)
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(40)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
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

import SwiftUI

// MARK: - Models (V3, file-scoped)

private struct SolitaireV3Card: Identifiable, Equatable {
    let id = UUID()
    let suit: String
    let rank: String
    let rankValue: Int
    let isRed: Bool
    var isFaceUp: Bool
}

private enum SolitaireV3Source: Equatable {
    case tableau(Int)
    case waste
}

// MARK: - Neumorphic Helpers

private struct NeuShadowModifier: ViewModifier {
    var isInset: Bool = false
    var radius: CGFloat = 8
    var intensity: CGFloat = 1.0

    func body(content: Content) -> some View {
        if isInset {
            content
                .shadow(color: Color.white.opacity(0.7 * intensity), radius: radius, x: -radius / 2, y: -radius / 2)
                .shadow(color: Color.black.opacity(0.18 * intensity), radius: radius, x: radius / 2, y: radius / 2)
        } else {
            content
                .shadow(color: Color.black.opacity(0.18 * intensity), radius: radius, x: 4, y: 4)
                .shadow(color: Color.white.opacity(0.7 * intensity), radius: radius, x: -4, y: -4)
        }
    }
}

private extension View {
    func neuShadow(inset: Bool = false, radius: CGFloat = 8, intensity: CGFloat = 1.0) -> some View {
        modifier(NeuShadowModifier(isInset: inset, radius: radius, intensity: intensity))
    }
}

private let neuBackground = Color(red: 0.92, green: 0.92, blue: 0.94)
private let neuDark = Color(red: 0.78, green: 0.78, blue: 0.82)
private let neuLight = Color.white

// MARK: - Game Engine

private class SolitaireV3Game: ObservableObject {
    @Published var tableau: [[SolitaireV3Card]] = Array(repeating: [], count: 7)
    @Published var foundations: [[SolitaireV3Card]] = Array(repeating: [], count: 4)
    @Published var stock: [SolitaireV3Card] = []
    @Published var waste: [SolitaireV3Card] = []
    @Published var selectedSource: SolitaireV3Source? = nil
    @Published var moves: Int = 0
    @Published var isWon: Bool = false

    let suits = ["♠️", "♥️", "♣️", "♦️"]
    let ranks = ["A","2","3","4","5","6","7","8","9","10","J","Q","K"]

    func newGame() {
        var deck: [SolitaireV3Card] = []
        for (si, suit) in suits.enumerated() {
            let isRed = si == 1 || si == 3
            for (ri, rank) in ranks.enumerated() {
                deck.append(SolitaireV3Card(suit: suit, rank: rank, rankValue: ri + 1, isRed: isRed, isFaceUp: false))
            }
        }
        deck.shuffle()

        tableau = Array(repeating: [], count: 7)
        foundations = Array(repeating: [], count: 4)
        waste = []
        selectedSource = nil
        moves = 0
        isWon = false

        var idx = 0
        for col in 0..<7 {
            for row in 0...col {
                var card = deck[idx]
                if row == col { card.isFaceUp = true }
                tableau[col].append(card)
                idx += 1
            }
        }
        stock = Array(deck[idx...].map { var c = $0; c.isFaceUp = false; return c })
    }

    func tapStock() {
        selectedSource = nil
        if stock.isEmpty {
            stock = waste.reversed().map { var c = $0; c.isFaceUp = false; return c }
            waste = []
        } else {
            var card = stock.removeLast()
            card.isFaceUp = true
            waste.append(card)
        }
    }

    func tapWaste() {
        guard !waste.isEmpty else { return }
        if selectedSource == .waste {
            selectedSource = nil
        } else {
            selectedSource = .waste
        }
    }

    func tapTableau(col: Int) {
        guard !tableau[col].isEmpty else {
            if let src = selectedSource { tryMove(to: col, fromSource: src) }
            return
        }
        if let last = tableau[col].last, !last.isFaceUp {
            tableau[col][tableau[col].count - 1].isFaceUp = true
            moves += 1
            return
        }
        if let src = selectedSource {
            if src == .tableau(col) {
                selectedSource = nil
            } else {
                tryMove(to: col, fromSource: src)
            }
        } else {
            selectedSource = .tableau(col)
        }
    }

    func tapFoundation(foundIdx: Int) {
        guard let src = selectedSource else { return }
        let card: SolitaireV3Card?
        switch src {
        case .waste: card = waste.last
        case .tableau(let col): card = tableau[col].last
        }
        guard let c = card else { return }
        if canPlaceOnFoundation(card: c, foundIdx: foundIdx) {
            switch src {
            case .waste: waste.removeLast()
            case .tableau(let col):
                tableau[col].removeLast()
                flipTopTableau(col: col)
            }
            foundations[foundIdx].append(c)
            selectedSource = nil
            moves += 1
            checkWin()
            autoMoveAces()
        }
    }

    private func tryMove(to destCol: Int, fromSource src: SolitaireV3Source) {
        switch src {
        case .waste:
            guard let card = waste.last else { return }
            if canPlaceOnTableau(card: card, col: destCol) {
                waste.removeLast()
                tableau[destCol].append(card)
                selectedSource = nil
                moves += 1
                autoMoveAces()
            } else {
                selectedSource = .waste
            }
        case .tableau(let srcCol):
            guard srcCol != destCol else { selectedSource = nil; return }
            let faceUpStart = tableau[srcCol].firstIndex(where: { $0.isFaceUp }) ?? (tableau[srcCol].count - 1)
            let stack = Array(tableau[srcCol][faceUpStart...])
            if let topCard = stack.first, canPlaceOnTableau(card: topCard, col: destCol) {
                tableau[srcCol].removeSubrange(faceUpStart...)
                tableau[destCol].append(contentsOf: stack)
                flipTopTableau(col: srcCol)
                selectedSource = nil
                moves += 1
                autoMoveAces()
            } else {
                selectedSource = .tableau(destCol)
            }
        }
    }

    private func canPlaceOnTableau(card: SolitaireV3Card, col: Int) -> Bool {
        if tableau[col].isEmpty { return card.rankValue == 13 }
        guard let top = tableau[col].last, top.isFaceUp else { return false }
        return top.rankValue == card.rankValue + 1 && top.isRed != card.isRed
    }

    private func canPlaceOnFoundation(card: SolitaireV3Card, foundIdx: Int) -> Bool {
        let pile = foundations[foundIdx]
        if pile.isEmpty { return card.rankValue == 1 }
        guard let top = pile.last else { return false }
        return top.suit == card.suit && top.rankValue == card.rankValue - 1
    }

    private func flipTopTableau(col: Int) {
        guard !tableau[col].isEmpty else { return }
        let last = tableau[col].count - 1
        if !tableau[col][last].isFaceUp { tableau[col][last].isFaceUp = true }
    }

    private func autoMoveAces() {
        var moved = true
        while moved {
            moved = false
            for col in 0..<7 {
                if let top = tableau[col].last, top.isFaceUp, top.rankValue == 1 {
                    if let fi = emptyOrMatchingFoundation(for: top) {
                        tableau[col].removeLast()
                        foundations[fi].append(top)
                        flipTopTableau(col: col)
                        moves += 1
                        moved = true
                    }
                }
            }
            if let top = waste.last, top.rankValue == 1 {
                if let fi = emptyOrMatchingFoundation(for: top) {
                    waste.removeLast()
                    foundations[fi].append(top)
                    moves += 1
                    moved = true
                }
            }
        }
        checkWin()
    }

    private func emptyOrMatchingFoundation(for card: SolitaireV3Card) -> Int? {
        for (i, pile) in foundations.enumerated() {
            if pile.isEmpty && card.rankValue == 1 { return i }
            if let top = pile.last, top.suit == card.suit && top.rankValue == card.rankValue - 1 { return i }
        }
        return nil
    }

    private func checkWin() {
        isWon = foundations.allSatisfy { $0.count == 13 }
    }
}

// MARK: - Card View (Neumorphic)

private struct SolitaireV3CardView: View {
    let card: SolitaireV3Card
    let isSelected: Bool

    var body: some View {
        ZStack {
            if card.isFaceUp {
                // Neumorphic raised card
                RoundedRectangle(cornerRadius: 10)
                    .fill(neuBackground)
                    .neuShadow(inset: isSelected, radius: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                isSelected
                                    ? Color(red: 0.3, green: 0.5, blue: 0.9).opacity(0.5)
                                    : Color.white.opacity(0.6),
                                lineWidth: 1
                            )
                    )

                // Inner highlight for raised look
                if !isSelected {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.5), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(1)
                }

                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(card.isRed ? Color(red: 0.85, green: 0.15, blue: 0.25) : Color(red: 0.15, green: 0.15, blue: 0.2))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        Spacer()
                    }
                    Spacer()
                    Text(card.suit)
                        .font(.system(size: 26))
                        .shadow(color: card.isRed ? Color.red.opacity(0.2) : Color.black.opacity(0.1), radius: 2, x: 1, y: 1)
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.suit)
                                .font(.system(size: 11))
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(card.isRed ? Color(red: 0.85, green: 0.15, blue: 0.25) : Color(red: 0.15, green: 0.15, blue: 0.2))
                        }
                        .rotationEffect(.degrees(180))
                    }
                }
                .padding(5)

            } else {
                // Face-down: inset neumorphic look
                RoundedRectangle(cornerRadius: 10)
                    .fill(neuBackground)
                    .neuShadow(inset: true, radius: 5, intensity: 0.7)

                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [neuDark.opacity(0.6), neuLight.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(5)
                    .neuShadow(radius: 3, intensity: 0.5)

                // Pattern dots
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 8) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle()
                                    .fill(Color(red: 0.55, green: 0.55, blue: 0.65).opacity(0.4))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 60, height: 90)
    }
}

private struct SolitaireV3EmptySlot: View {
    var label: String = ""
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(neuBackground)
                .neuShadow(inset: true, radius: 6, intensity: 0.6)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 22))
                    .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.65))
            }
        }
        .frame(width: 60, height: 90)
    }
}

// MARK: - Neumorphic Button Style

private struct NeuButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Main View V3

struct SolitaireViewV3: View {
    @StateObject private var game = SolitaireV3Game()

    var body: some View {
        ZStack {
            neuBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Solitaire")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.28))
                        Text("Moves: \(game.moves)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.58))
                    }
                    Spacer()
                    Button(action: { game.newGame() }) {
                        Text("New Game")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(neuBackground)
                                    .neuShadow(radius: 6)
                            )
                    }
                    .buttonStyle(NeuButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    neuBackground
                        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        topRow
                        tableauRow
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 14)
                }
            }

            if game.isWon {
                winOverlay
            }
        }
        .onAppear { game.newGame() }
    }

    private var topRow: some View {
        HStack(spacing: 8) {
            // Stock
            Button(action: { game.tapStock() }) {
                if game.stock.isEmpty {
                    ZStack {
                        SolitaireV3EmptySlot()
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.65))
                            .font(.system(size: 18))
                    }
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(neuBackground)
                            .neuShadow(radius: 6)
                        RoundedRectangle(cornerRadius: 7)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.35, green: 0.45, blue: 0.75), Color(red: 0.25, green: 0.3, blue: 0.65)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .padding(4)
                            .neuShadow(inset: true, radius: 3, intensity: 0.5)
                        Text("🂠")
                            .font(.system(size: 32))
                    }
                    .frame(width: 60, height: 90)
                }
            }
            .buttonStyle(NeuButtonStyle())

            // Waste
            Button(action: { game.tapWaste() }) {
                if let top = game.waste.last {
                    SolitaireV3CardView(card: top, isSelected: game.selectedSource == .waste)
                } else {
                    SolitaireV3EmptySlot()
                }
            }
            .buttonStyle(NeuButtonStyle())

            Spacer()

            ForEach(0..<4, id: \.self) { fi in
                Button(action: { game.tapFoundation(foundIdx: fi) }) {
                    if let top = game.foundations[fi].last {
                        SolitaireV3CardView(card: top, isSelected: false)
                    } else {
                        SolitaireV3EmptySlot(label: ["♠️","♥️","♣️","♦️"][fi])
                    }
                }
                .buttonStyle(NeuButtonStyle())
            }
        }
    }

    private var tableauRow: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(0..<7, id: \.self) { col in
                tableauColumn(col: col)
            }
        }
    }

    private func tableauColumn(col: Int) -> some View {
        ZStack(alignment: .top) {
            Button(action: { game.tapTableau(col: col) }) {
                SolitaireV3EmptySlot()
            }
            .buttonStyle(NeuButtonStyle())

            if !game.tableau[col].isEmpty {
                ZStack(alignment: .top) {
                    ForEach(Array(game.tableau[col].enumerated()), id: \.element.id) { idx, card in
                        Button(action: { game.tapTableau(col: col) }) {
                            SolitaireV3CardView(
                                card: card,
                                isSelected: isCardSelected(card: card, col: col, idx: idx)
                            )
                        }
                        .buttonStyle(NeuButtonStyle())
                        .offset(y: CGFloat(idx) * 28)
                    }
                }
            }
        }
        .frame(width: 60, height: max(90, 90 + CGFloat(max(0, game.tableau[col].count - 1)) * 28))
    }

    private func isCardSelected(card: SolitaireV3Card, col: Int, idx: Int) -> Bool {
        guard case .tableau(let sc) = game.selectedSource, sc == col else { return false }
        guard let faceUpStart = game.tableau[col].firstIndex(where: { $0.isFaceUp }) else { return false }
        return idx >= faceUpStart
    }

    private var winOverlay: some View {
        ZStack {
            neuBackground.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 28) {
                // Trophy icon neumorphic circle
                ZStack {
                    Circle()
                        .fill(neuBackground)
                        .frame(width: 100, height: 100)
                        .neuShadow(radius: 12)
                    Text("🏆")
                        .font(.system(size: 52))
                }

                VStack(spacing: 8) {
                    Text("YOU WIN! 🎉")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.28))
                    Text("Completed in \(game.moves) moves")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.58))
                }

                Button(action: { game.newGame() }) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.3, green: 0.45, blue: 0.8))
                        .frame(width: 180)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(neuBackground)
                                .neuShadow(radius: 10)
                        )
                }
                .buttonStyle(NeuButtonStyle())
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(neuBackground)
                    .neuShadow(radius: 16)
            )
            .padding(.horizontal, 40)
        }
    }
}

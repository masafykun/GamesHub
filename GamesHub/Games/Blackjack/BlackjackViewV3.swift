import SwiftUI

// MARK: - Models (V3, file-scoped)

private struct BlackjackV3Card: Identifiable {
    let id = UUID()
    let suit: String
    let rank: String
    let value: Int
    var isFaceDown: Bool

    static func deck() -> [BlackjackV3Card] {
        let suits = ["♠︎", "♥︎", "♦︎", "♣︎"]
        let ranks: [(String, Int)] = [
            ("A", 11), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9), ("10", 10),
            ("J", 10), ("Q", 10), ("K", 10)
        ]
        var cards: [BlackjackV3Card] = []
        for suit in suits {
            for (rank, value) in ranks {
                cards.append(BlackjackV3Card(suit: suit, rank: rank, value: value, isFaceDown: false))
            }
        }
        return cards.shuffled()
    }
}

private enum BlackjackV3Phase {
    case betting, playing, dealerTurn, result
}

private enum BlackjackV3Result {
    case playerWin, dealerWin, push, blackjack, playerBust, dealerBust
}

// MARK: - ViewModel

private class BlackjackV3ViewModel: ObservableObject {
    @Published var playerHand: [BlackjackV3Card] = []
    @Published var dealerHand: [BlackjackV3Card] = []
    @Published var chips: Int = 1000
    @Published var bet: Int = 100
    @Published var phase: BlackjackV3Phase = .betting
    @Published var result: BlackjackV3Result? = nil

    private var deck: [BlackjackV3Card] = []

    var playerTotal: Int { calculateTotal(hand: playerHand) }
    var dealerTotal: Int { calculateTotal(hand: dealerHand) }
    var dealerVisibleTotal: Int {
        calculateTotal(hand: dealerHand.filter { !$0.isFaceDown })
    }

    func calculateTotal(hand: [BlackjackV3Card]) -> Int {
        var total = 0
        var aces = 0
        for card in hand where !card.isFaceDown {
            total += card.value
            if card.rank == "A" { aces += 1 }
        }
        while total > 21 && aces > 0 {
            total -= 10
            aces -= 1
        }
        return total
    }

    func deal() {
        guard bet >= 50, bet <= chips else { return }
        deck = BlackjackV3Card.deck()
        playerHand = []
        dealerHand = []
        result = nil

        playerHand.append(draw())
        dealerHand.append(draw())
        playerHand.append(draw())
        var second = draw()
        second.isFaceDown = true
        dealerHand.append(second)
        chips -= bet
        phase = .playing

        if playerTotal == 21 { stand() }
    }

    func hit() {
        guard phase == .playing else { return }
        playerHand.append(draw())
        if playerTotal > 21 { revealAndFinish() }
    }

    func stand() {
        guard phase == .playing || playerTotal == 21 else { return }
        phase = .dealerTurn
        revealAndFinish()
    }

    private func revealAndFinish() {
        for i in dealerHand.indices { dealerHand[i].isFaceDown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.dealerDrawLoop() }
    }

    private func dealerDrawLoop() {
        if dealerTotal < 17 {
            dealerHand.append(draw())
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.dealerDrawLoop() }
        } else {
            determineResult()
        }
    }

    private func determineResult() {
        let pt = playerTotal, dt = dealerTotal
        if pt > 21 {
            result = .playerBust
        } else if dt > 21 {
            result = .dealerBust; chips += bet * 2
        } else if pt == 21 && playerHand.count == 2 && !(dt == 21 && dealerHand.count == 2) {
            result = .blackjack; chips += Int(Double(bet) * 2.5)
        } else if pt > dt {
            result = .playerWin; chips += bet * 2
        } else if dt > pt {
            result = .dealerWin
        } else {
            result = .push; chips += bet
        }
        phase = .result
    }

    private func draw() -> BlackjackV3Card {
        if deck.isEmpty { deck = BlackjackV3Card.deck() }
        return deck.removeFirst()
    }

    func adjustBet(_ amount: Int) {
        let newBet = bet + amount
        if newBet >= 50 && newBet <= chips { bet = newBet }
    }

    func dealAgain() {
        if chips < 50 { chips = 1000; bet = 100 }
        phase = .betting; result = nil
    }
}

// MARK: - Neumorphic Helpers

private let neuBackground = Color(UIColor.systemGray6)

private struct NeumorphicShadow: ViewModifier {
    var isPressed: Bool = false
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .shadow(
                color: isPressed ? Color.clear : Color.black.opacity(0.18),
                radius: 8, x: isPressed ? 0 : 4, y: isPressed ? 0 : 4
            )
            .shadow(
                color: isPressed ? Color.clear : Color.white.opacity(0.7),
                radius: 8, x: isPressed ? 0 : -4, y: isPressed ? 0 : -4
            )
    }
}

private struct InnerShadow: ViewModifier {
    var color: Color = Color.black.opacity(0.08)
    var radius: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    .blur(radius: 1)
                    .offset(x: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.6), lineWidth: 1)
                    .blur(radius: 1)
                    .offset(x: -1, y: -1)
            )
    }
}

private extension View {
    func bjNeuCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(neuBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .modifier(NeumorphicShadow(cornerRadius: cornerRadius))
    }
}

// MARK: - Neumorphic Button

private struct NeuButton: View {
    let title: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                action()
            }
        }) {
            Text(title)
                .font(.headline.bold())
                .foregroundColor(disabled ? Color(.systemGray3) : color)
                .frame(minWidth: 90, minHeight: 44)
                .background(neuBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .modifier(NeumorphicShadow(isPressed: isPressed || disabled))
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Neumorphic Card View

private struct NeuCardView: View {
    let card: BlackjackV3Card
    var isRed: Bool { card.suit == "♥︎" || card.suit == "♦︎" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(card.isFaceDown ? Color(.systemGray5) : neuBackground)
                .modifier(NeumorphicShadow(cornerRadius: 10))

            if card.isFaceDown {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray4))
                        .padding(6)
                    Image(systemName: "questionmark")
                        .font(.title2.bold())
                        .foregroundColor(Color(.systemGray2))
                }
            } else {
                VStack(spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(.label))
                        Spacer()
                    }
                    .padding(.horizontal, 5)
                    .padding(.top, 5)

                    Spacer()

                    Text(card.suit)
                        .font(.system(size: 22))
                        .foregroundColor(isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(.label))

                    Spacer()

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 13, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(isRed ? Color(red: 0.8, green: 0.1, blue: 0.1) : Color(.label))
                        .rotationEffect(.degrees(180))
                    }
                    .padding(.horizontal, 5)
                    .padding(.bottom, 5)
                }
            }
        }
        .frame(width: 62, height: 90)
    }
}

// MARK: - Neumorphic Badge

private struct NeuBadge: View {
    let value: String
    let color: Color

    var body: some View {
        Text(value)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(neuBackground)
                    .modifier(NeumorphicShadow(isPressed: true, cornerRadius: 20))
            )
    }
}

// MARK: - Main V3 View

struct BlackjackViewV3: View {
    @StateObject private var vm = BlackjackV3ViewModel()

    var resultMessage: String {
        switch vm.result {
        case .playerWin:   return "You Win!"
        case .dealerWin:   return "Dealer Wins"
        case .push:        return "Push — Tie!"
        case .blackjack:   return "Blackjack! 1.5x"
        case .playerBust:  return "Bust! You Lose"
        case .dealerBust:  return "Dealer Busts!"
        case .none:        return ""
        }
    }

    var resultColor: Color {
        switch vm.result {
        case .playerWin, .dealerBust, .blackjack: return Color(red: 0.1, green: 0.5, blue: 0.1)
        case .dealerWin, .playerBust:             return Color(red: 0.7, green: 0.1, blue: 0.1)
        case .push:                               return Color(red: 0.7, green: 0.4, blue: 0.0)
        case .none:                               return Color(.label)
        }
    }

    var body: some View {
        ZStack {
            neuBackground.ignoresSafeArea()

            VStack(spacing: 18) {
                // Chip bar
                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundColor(Color(red: 0.7, green: 0.55, blue: 0.0))
                        .font(.title3)
                    Text("Chips: \(vm.chips)")
                        .font(.title3.bold())
                        .foregroundColor(Color(.label))
                    Spacer()
                    if vm.phase != .betting {
                        NeuBadge(value: "Bet: \(vm.bet)", color: Color(red: 0.1, green: 0.4, blue: 0.7))
                    }
                }
                .padding(16)
                .bjNeuCard()
                .padding(.horizontal)

                // Dealer area
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("DEALER")
                            .font(.caption.bold())
                            .foregroundColor(Color(.secondaryLabel))
                            .tracking(2)
                        if !vm.dealerHand.isEmpty {
                            NeuBadge(
                                value: vm.phase == .playing ? "?" : "\(vm.dealerTotal)",
                                color: Color(red: 0.4, green: 0.1, blue: 0.6)
                            )
                        }
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -10) {
                            ForEach(vm.dealerHand) { card in
                                NeuCardView(card: card)
                                    .transition(.move(edge: .trailing).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(16)
                .bjNeuCard()
                .padding(.horizontal)

                Spacer()

                // Player area
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("YOU")
                            .font(.caption.bold())
                            .foregroundColor(Color(.secondaryLabel))
                            .tracking(2)
                        if !vm.playerHand.isEmpty {
                            NeuBadge(
                                value: "\(vm.playerTotal)",
                                color: vm.playerTotal > 21
                                    ? Color(red: 0.7, green: 0.1, blue: 0.1)
                                    : Color(red: 0.1, green: 0.4, blue: 0.7)
                            )
                        }
                        Spacer()
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: -10) {
                            ForEach(vm.playerHand) { card in
                                NeuCardView(card: card)
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                    }
                }
                .padding(16)
                .bjNeuCard()
                .padding(.horizontal)

                // Controls
                Group {
                    if vm.phase == .betting {
                        bettingControls
                    } else if vm.phase == .playing {
                        playingControls
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.top)
            .animation(.easeInOut(duration: 0.35), value: vm.playerHand.count)
            .animation(.easeInOut(duration: 0.35), value: vm.dealerHand.count)

            // Result overlay
            if vm.phase == .result, let _ = vm.result {
                resultOverlay
            }
        }
    }

    private var bettingControls: some View {
        VStack(spacing: 16) {
            Text("PLACE YOUR BET")
                .font(.caption.bold())
                .foregroundColor(Color(.secondaryLabel))
                .tracking(2)

            HStack(spacing: 20) {
                NeuButton(title: "-50", color: Color(red: 0.7, green: 0.1, blue: 0.1),
                          disabled: vm.bet <= 50) { vm.adjustBet(-50) }

                // Inset display for bet amount
                Text("\(vm.bet)")
                    .font(.title.bold())
                    .foregroundColor(Color(.label))
                    .frame(minWidth: 80, minHeight: 44)
                    .background(neuBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .modifier(InnerShadow())

                NeuButton(title: "+50", color: Color(red: 0.1, green: 0.5, blue: 0.1),
                          disabled: vm.bet + 50 > vm.chips) { vm.adjustBet(50) }
            }

            NeuButton(
                title: "DEAL",
                color: Color(red: 0.1, green: 0.4, blue: 0.7),
                disabled: vm.bet > vm.chips || vm.chips < 50
            ) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { vm.deal() }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .bjNeuCard()
    }

    private var playingControls: some View {
        HStack(spacing: 20) {
            NeuButton(title: "HIT", color: Color(red: 0.1, green: 0.5, blue: 0.1)) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { vm.hit() }
            }
            NeuButton(title: "STAND", color: Color(red: 0.7, green: 0.1, blue: 0.1)) {
                withAnimation(.easeInOut) { vm.stand() }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .bjNeuCard()
    }

    private var resultOverlay: some View {
        ZStack {
            neuBackground.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 20) {
                // Icon
                Image(systemName: vm.result == .playerBust || vm.result == .dealerWin
                      ? "xmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(resultColor)

                Text(resultMessage)
                    .font(.largeTitle.bold())
                    .foregroundColor(resultColor)

                // Score box (inset style)
                VStack(spacing: 8) {
                    HStack {
                        Text("Your total")
                            .foregroundColor(Color(.secondaryLabel))
                        Spacer()
                        NeuBadge(value: "\(vm.playerTotal)",
                                 color: Color(red: 0.1, green: 0.4, blue: 0.7))
                    }
                    HStack {
                        Text("Dealer total")
                            .foregroundColor(Color(.secondaryLabel))
                        Spacer()
                        NeuBadge(value: "\(vm.dealerTotal)",
                                 color: Color(red: 0.4, green: 0.1, blue: 0.6))
                    }
                }
                .font(.subheadline)
                .padding(12)
                .background(neuBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .modifier(InnerShadow())
                .frame(maxWidth: 260)

                HStack {
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundColor(Color(red: 0.7, green: 0.55, blue: 0.0))
                    Text("Chips: \(vm.chips)")
                        .font(.headline.bold())
                        .foregroundColor(Color(.label))
                }

                NeuButton(title: "DEAL AGAIN", color: resultColor) {
                    withAnimation(.spring(response: 0.4)) { vm.dealAgain() }
                }
            }
            .padding(32)
            .bjNeuCard(cornerRadius: 24)
            .padding(32)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

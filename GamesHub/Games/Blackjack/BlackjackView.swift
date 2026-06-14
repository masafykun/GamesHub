import SwiftUI

// MARK: - Models (file-scoped)

private struct BlackjackCard: Identifiable {
    let id = UUID()
    let suit: String
    let rank: String
    let value: Int
    var isFaceDown: Bool

    static func deck() -> [BlackjackCard] {
        let suits = ["♠︎", "♥︎", "♦︎", "♣︎"]
        let ranks: [(String, Int)] = [
            ("A", 11), ("2", 2), ("3", 3), ("4", 4), ("5", 5),
            ("6", 6), ("7", 7), ("8", 8), ("9", 9), ("10", 10),
            ("J", 10), ("Q", 10), ("K", 10)
        ]
        var cards: [BlackjackCard] = []
        for suit in suits {
            for (rank, value) in ranks {
                cards.append(BlackjackCard(suit: suit, rank: rank, value: value, isFaceDown: false))
            }
        }
        return cards.shuffled()
    }
}

private enum BlackjackPhase {
    case betting, playing, dealerTurn, result
}

private enum BlackjackResult {
    case playerWin, dealerWin, push, blackjack, playerBust, dealerBust
}

// MARK: - ViewModel

private class BlackjackViewModel: ObservableObject {
    @Published var playerHand: [BlackjackCard] = []
    @Published var dealerHand: [BlackjackCard] = []
    @Published var chips: Int = 1000
    @Published var bet: Int = 100
    @Published var phase: BlackjackPhase = .betting
    @Published var result: BlackjackResult? = nil
    @Published var isDealerRevealing: Bool = false

    private var deck: [BlackjackCard] = []

    var playerTotal: Int { calculateTotal(hand: playerHand) }
    var dealerTotal: Int { calculateTotal(hand: dealerHand) }
    var dealerVisibleTotal: Int {
        let visible = dealerHand.filter { !$0.isFaceDown }
        return calculateTotal(hand: visible)
    }

    func calculateTotal(hand: [BlackjackCard]) -> Int {
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
        deck = BlackjackCard.deck()
        playerHand = []
        dealerHand = []
        result = nil
        isDealerRevealing = false

        playerHand.append(draw())
        dealerHand.append(draw())
        playerHand.append(draw())
        var second = draw()
        second.isFaceDown = true
        dealerHand.append(second)

        chips -= bet
        phase = .playing

        // Check for player blackjack
        if playerTotal == 21 {
            standAction()
        }
    }

    func hit() {
        guard phase == .playing else { return }
        playerHand.append(draw())
        if playerTotal > 21 {
            revealAndFinish()
        }
    }

    func stand() {
        guard phase == .playing else { return }
        standAction()
    }

    private func standAction() {
        phase = .dealerTurn
        revealAndFinish()
    }

    private func revealAndFinish() {
        // Reveal face-down card
        for i in dealerHand.indices {
            dealerHand[i].isFaceDown = false
        }
        isDealerRevealing = true

        // Dealer draws to 17
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.dealerDrawLoop()
        }
    }

    private func dealerDrawLoop() {
        if dealerTotal < 17 {
            dealerHand.append(draw())
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.dealerDrawLoop()
            }
        } else {
            determineResult()
        }
    }

    private func determineResult() {
        let pt = playerTotal
        let dt = dealerTotal

        if pt > 21 {
            result = .playerBust
        } else if dt > 21 {
            result = .dealerBust
            chips += bet * 2
        } else if pt == 21 && playerHand.count == 2 && !(dt == 21 && dealerHand.count == 2) {
            result = .blackjack
            chips += Int(Double(bet) * 2.5)
        } else if pt > dt {
            result = .playerWin
            chips += bet * 2
        } else if dt > pt {
            result = .dealerWin
        } else {
            result = .push
            chips += bet
        }
        phase = .result
    }

    private func draw() -> BlackjackCard {
        if deck.isEmpty { deck = BlackjackCard.deck() }
        return deck.removeFirst()
    }

    func adjustBet(_ amount: Int) {
        let newBet = bet + amount
        if newBet >= 50 && newBet <= chips {
            bet = newBet
        }
    }

    func dealAgain() {
        if chips < 50 {
            chips = 1000
            bet = 100
        }
        phase = .betting
        result = nil
    }
}

// MARK: - Card View

private struct CardView: View {
    let card: BlackjackCard

    var isRed: Bool { card.suit == "♥︎" || card.suit == "♦︎" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(card.isFaceDown ? Color.blue.opacity(0.8) : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .shadow(radius: 3)

            if card.isFaceDown {
                Image(systemName: "rectangle.pattern.checkered")
                    .foregroundColor(.white.opacity(0.3))
                    .font(.system(size: 24))
            } else {
                VStack(spacing: 2) {
                    HStack {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 14, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(isRed ? .red : .black)
                        Spacer()
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                    Spacer()

                    Text(card.suit)
                        .font(.system(size: 22))
                        .foregroundColor(isRed ? .red : .black)

                    Spacer()

                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(card.rank)
                                .font(.system(size: 14, weight: .bold))
                            Text(card.suit)
                                .font(.system(size: 12))
                        }
                        .foregroundColor(isRed ? .red : .black)
                        .rotationEffect(.degrees(180))
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
        }
        .frame(width: 60, height: 88)
    }
}

// MARK: - Hand View

private struct HandView: View {
    let cards: [BlackjackCard]
    let total: Int
    let label: String
    let showTotal: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if showTotal {
                    Text("\(total)")
                        .font(.caption.bold())
                        .foregroundColor(.primary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -12) {
                    ForEach(cards) { card in
                        CardView(card: card)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Main View

struct BlackjackView: View {
    @StateObject private var vm = BlackjackViewModel()

    var resultMessage: String {
        switch vm.result {
        case .playerWin:   return "You Win!"
        case .dealerWin:   return "Dealer Wins"
        case .push:        return "Push — Tie!"
        case .blackjack:   return "Blackjack! 1.5x"
        case .playerBust:  return "Bust! You Lose"
        case .dealerBust:  return "Dealer Busts — You Win!"
        case .none:        return ""
        }
    }

    var resultColor: Color {
        switch vm.result {
        case .playerWin, .dealerBust, .blackjack: return .green
        case .dealerWin, .playerBust:             return .red
        case .push:                               return .orange
        case .none:                               return .primary
        }
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 20) {
                // Chip display
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(.yellow)
                    Text("Chips: \(vm.chips)")
                        .font(.title3.bold())
                    Spacer()
                    if vm.phase != .betting {
                        Text("Bet: \(vm.bet)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Dealer hand
                VStack(alignment: .leading, spacing: 6) {
                    HandView(
                        cards: vm.dealerHand,
                        total: vm.dealerVisibleTotal,
                        label: "Dealer",
                        showTotal: !vm.dealerHand.isEmpty
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

                Spacer()

                // Player hand
                VStack(alignment: .leading, spacing: 6) {
                    HandView(
                        cards: vm.playerHand,
                        total: vm.playerTotal,
                        label: "You",
                        showTotal: !vm.playerHand.isEmpty
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
            .animation(.easeInOut(duration: 0.3), value: vm.playerHand.count)
            .animation(.easeInOut(duration: 0.3), value: vm.dealerHand.count)

            // Result overlay
            if vm.phase == .result, let _ = vm.result {
                resultOverlay
            }
        }
    }

    private var bettingControls: some View {
        VStack(spacing: 12) {
            Text("Place Your Bet")
                .font(.headline)

            HStack(spacing: 20) {
                Button("-50") { vm.adjustBet(-50) }
                    .buttonStyle(.bordered)
                    .disabled(vm.bet <= 50)

                Text("\(vm.bet)")
                    .font(.title2.bold())
                    .frame(minWidth: 80)

                Button("+50") { vm.adjustBet(50) }
                    .buttonStyle(.bordered)
                    .disabled(vm.bet + 50 > vm.chips)
            }

            Button("Deal") {
                withAnimation { vm.deal() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(vm.bet > vm.chips || vm.chips < 50)
        }
    }

    private var playingControls: some View {
        HStack(spacing: 20) {
            Button("Hit") {
                withAnimation { vm.hit() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            Button("Stand") {
                withAnimation { vm.stand() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(resultMessage)
                    .font(.largeTitle.bold())
                    .foregroundColor(resultColor)

                VStack(spacing: 4) {
                    Text("Your total: \(vm.playerTotal)")
                    Text("Dealer total: \(vm.dealerTotal)")
                }
                .font(.subheadline)
                .foregroundColor(.white)

                Text("Chips: \(vm.chips)")
                    .font(.headline)
                    .foregroundColor(.yellow)

                Button("Deal Again") {
                    withAnimation { vm.dealAgain() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(radius: 20)
            )
            .padding(40)
        }
    }
}

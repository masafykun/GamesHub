import SwiftUI

struct GameEntry: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let makeBase: () -> AnyView
    let makeV2: () -> AnyView
    let makeV3: () -> AnyView
}

// MARK: - Game Registry

let allGames: [GameEntry] = [
    // 1-10: Original Games
    GameEntry(name: "Flappy Bird",    icon: "bird.fill",              color: .cyan,
              makeBase: { AnyView(FlappyView()) },      makeV2: { AnyView(FlappyViewV2()) },      makeV3: { AnyView(FlappyViewV3()) }),
    GameEntry(name: "2048",           icon: "square.grid.2x2.fill",   color: .orange,
              makeBase: { AnyView(Puzzle2048View()) },  makeV2: { AnyView(Puzzle2048ViewV2()) },  makeV3: { AnyView(Puzzle2048ViewV3()) }),
    GameEntry(name: "Wordle",         icon: "textformat.abc",          color: .green,
              makeBase: { AnyView(WordleView()) },      makeV2: { AnyView(WordleViewV2()) },      makeV3: { AnyView(WordleViewV3()) }),
    GameEntry(name: "Runner",         icon: "figure.run",              color: .purple,
              makeBase: { AnyView(RunnerView()) },      makeV2: { AnyView(RunnerViewV2()) },      makeV3: { AnyView(RunnerViewV3()) }),
    GameEntry(name: "Match 3",        icon: "star.fill",               color: .yellow,
              makeBase: { AnyView(Match3View()) },      makeV2: { AnyView(Match3ViewV2()) },      makeV3: { AnyView(Match3ViewV3()) }),
    GameEntry(name: "Tower Defense",  icon: "shield.fill",             color: .red,
              makeBase: { AnyView(DefenseView()) },     makeV2: { AnyView(DefenseViewV2()) },     makeV3: { AnyView(DefenseViewV3()) }),
    GameEntry(name: "Stacker",        icon: "square.stack.fill",       color: .indigo,
              makeBase: { AnyView(StackerView()) },     makeV2: { AnyView(StackerViewV2()) },     makeV3: { AnyView(StackerViewV3()) }),
    GameEntry(name: "Jumper",         icon: "arrow.up.circle.fill",    color: .teal,
              makeBase: { AnyView(JumperView()) },      makeV2: { AnyView(JumperViewV2()) },      makeV3: { AnyView(JumperViewV3()) }),
    GameEntry(name: "Dodge",          icon: "bolt.circle.fill",        color: .pink,
              makeBase: { AnyView(DodgeView()) },       makeV2: { AnyView(DodgeViewV2()) },       makeV3: { AnyView(DodgeViewV3()) }),
    GameEntry(name: "Memory",         icon: "brain.fill",              color: .mint,
              makeBase: { AnyView(MemoryView()) },      makeV2: { AnyView(MemoryViewV2()) },      makeV3: { AnyView(MemoryViewV3()) }),
    // 11-20
    GameEntry(name: "Snake",          icon: "point.3.connected.trianglepath.dotted", color: .green,
              makeBase: { AnyView(SnakeView()) },       makeV2: { AnyView(SnakeViewV2()) },       makeV3: { AnyView(SnakeViewV3()) }),
    GameEntry(name: "Breakout",       icon: "rectangle.split.3x1.fill",color: .blue,
              makeBase: { AnyView(BreakoutView()) },    makeV2: { AnyView(BreakoutViewV2()) },    makeV3: { AnyView(BreakoutViewV3()) }),
    GameEntry(name: "Tetris Lite",    icon: "square.grid.3x3.fill",    color: .purple,
              makeBase: { AnyView(TetrisView()) },      makeV2: { AnyView(TetrisViewV2()) },      makeV3: { AnyView(TetrisViewV3()) }),
    GameEntry(name: "Space Shooter",  icon: "airplane",                color: .cyan,
              makeBase: { AnyView(SpaceShooterView()) },makeV2: { AnyView(SpaceShooterViewV2()) },makeV3: { AnyView(SpaceShooterViewV3()) }),
    GameEntry(name: "Minesweeper",    icon: "exclamationmark.octagon.fill", color: .red,
              makeBase: { AnyView(MinesweeperView()) }, makeV2: { AnyView(MinesweeperViewV2()) }, makeV3: { AnyView(MinesweeperViewV3()) }),
    GameEntry(name: "Sudoku",         icon: "grid",                    color: .orange,
              makeBase: { AnyView(SudokuView()) },      makeV2: { AnyView(SudokuViewV2()) },      makeV3: { AnyView(SudokuViewV3()) }),
    GameEntry(name: "Simon Says",     icon: "circle.grid.2x2.fill",   color: .yellow,
              makeBase: { AnyView(SimonView()) },       makeV2: { AnyView(SimonViewV2()) },       makeV3: { AnyView(SimonViewV3()) }),
    GameEntry(name: "Whack-a-Mole",   icon: "hand.tap.fill",          color: .brown,
              makeBase: { AnyView(WhackView()) },       makeV2: { AnyView(WhackViewV2()) },       makeV3: { AnyView(WhackViewV3()) }),
    GameEntry(name: "Bubble Shooter", icon: "circle.fill",             color: .teal,
              makeBase: { AnyView(BubbleShooterView()) },makeV2: { AnyView(BubbleShooterViewV2()) },makeV3: { AnyView(BubbleShooterViewV3()) }),
    GameEntry(name: "Sliding Puzzle", icon: "rectangle.3.group.fill",  color: .indigo,
              makeBase: { AnyView(SlidingPuzzleView()) },makeV2: { AnyView(SlidingPuzzleViewV2()) },makeV3: { AnyView(SlidingPuzzleViewV3()) }),
    // 21-30
    GameEntry(name: "Connect Four",   icon: "circle.grid.3x3.fill",   color: .red,
              makeBase: { AnyView(ConnectFourView()) }, makeV2: { AnyView(ConnectFourViewV2()) }, makeV3: { AnyView(ConnectFourViewV3()) }),
    GameEntry(name: "Tic-Tac-Toe",    icon: "xmark.square.fill",      color: .blue,
              makeBase: { AnyView(TicTacToeView()) },   makeV2: { AnyView(TicTacToeViewV2()) },   makeV3: { AnyView(TicTacToeViewV3()) }),
    GameEntry(name: "Trivia",         icon: "questionmark.circle.fill",color: .purple,
              makeBase: { AnyView(TriviaView()) },      makeV2: { AnyView(TriviaViewV2()) },      makeV3: { AnyView(TriviaViewV3()) }),
    GameEntry(name: "Color Match",    icon: "paintpalette.fill",       color: .pink,
              makeBase: { AnyView(ColorMatchView()) },  makeV2: { AnyView(ColorMatchViewV2()) },  makeV3: { AnyView(ColorMatchViewV3()) }),
    GameEntry(name: "Reaction Timer", icon: "timer",                   color: .orange,
              makeBase: { AnyView(ReactionView()) },    makeV2: { AnyView(ReactionViewV2()) },    makeV3: { AnyView(ReactionViewV3()) }),
    GameEntry(name: "Hangman",        icon: "person.fill.questionmark",color: .gray,
              makeBase: { AnyView(HangmanView()) },     makeV2: { AnyView(HangmanViewV2()) },     makeV3: { AnyView(HangmanViewV3()) }),
    GameEntry(name: "Word Search",    icon: "magnifyingglass",         color: .teal,
              makeBase: { AnyView(WordSearchView()) },  makeV2: { AnyView(WordSearchViewV2()) },  makeV3: { AnyView(WordSearchViewV3()) }),
    GameEntry(name: "Anagram",        icon: "textformat",              color: .green,
              makeBase: { AnyView(AnagramView()) },     makeV2: { AnyView(AnagramViewV2()) },     makeV3: { AnyView(AnagramViewV3()) }),
    GameEntry(name: "Lights Out",     icon: "lightbulb.fill",          color: .yellow,
              makeBase: { AnyView(LightsOutView()) },   makeV2: { AnyView(LightsOutViewV2()) },   makeV3: { AnyView(LightsOutViewV3()) }),
    GameEntry(name: "Pipe Connect",   icon: "arrow.triangle.turn.up.right.diamond.fill", color: .blue,
              makeBase: { AnyView(PipeConnectView()) }, makeV2: { AnyView(PipeConnectViewV2()) }, makeV3: { AnyView(PipeConnectViewV3()) }),
    // 31-40
    GameEntry(name: "Color Flood",    icon: "drop.fill",               color: .cyan,
              makeBase: { AnyView(ColorFloodView()) },  makeV2: { AnyView(ColorFloodViewV2()) },  makeV3: { AnyView(ColorFloodViewV3()) }),
    GameEntry(name: "Code Breaker",   icon: "lock.fill",               color: .indigo,
              makeBase: { AnyView(CodeBreakerView()) }, makeV2: { AnyView(CodeBreakerViewV2()) }, makeV3: { AnyView(CodeBreakerViewV3()) }),
    GameEntry(name: "Asteroid Dodge", icon: "sparkles",                color: .mint,
              makeBase: { AnyView(AsteroidView()) },    makeV2: { AnyView(AsteroidViewV2()) },    makeV3: { AnyView(AsteroidViewV3()) }),
    GameEntry(name: "Gem Catcher",    icon: "diamond.fill",            color: .pink,
              makeBase: { AnyView(GemCatcherView()) },  makeV2: { AnyView(GemCatcherViewV2()) },  makeV3: { AnyView(GemCatcherViewV3()) }),
    GameEntry(name: "Gravity Switch", icon: "arrow.up.arrow.down",     color: .purple,
              makeBase: { AnyView(GravitySwitchView()) },makeV2: { AnyView(GravitySwitchViewV2()) },makeV3: { AnyView(GravitySwitchViewV3()) }),
    GameEntry(name: "Number Flow",    icon: "number",                  color: .orange,
              makeBase: { AnyView(NumberFlowView()) },  makeV2: { AnyView(NumberFlowViewV2()) },  makeV3: { AnyView(NumberFlowViewV3()) }),
    GameEntry(name: "Binary Game",    icon: "01.circle.fill",          color: .green,
              makeBase: { AnyView(BinaryGameView()) },  makeV2: { AnyView(BinaryGameViewV2()) },  makeV3: { AnyView(BinaryGameViewV3()) }),
    GameEntry(name: "High Low",       icon: "arrow.up.arrow.down.circle.fill", color: .red,
              makeBase: { AnyView(HighLowView()) },     makeV2: { AnyView(HighLowViewV2()) },     makeV3: { AnyView(HighLowViewV3()) }),
    GameEntry(name: "Fruit Slice",    icon: "scissors",                color: .red,
              makeBase: { AnyView(FruitSliceView()) },  makeV2: { AnyView(FruitSliceViewV2()) },  makeV3: { AnyView(FruitSliceViewV3()) }),
    GameEntry(name: "Math Blitz",     icon: "plus.forwardslash.minus", color: .blue,
              makeBase: { AnyView(MathBlitzView()) },   makeV2: { AnyView(MathBlitzViewV2()) },   makeV3: { AnyView(MathBlitzViewV3()) }),
    // 41-50
    GameEntry(name: "Flick Hoops",    icon: "basketball.fill",         color: .orange,
              makeBase: { AnyView(FlickHoopsView()) },  makeV2: { AnyView(FlickHoopsViewV2()) },  makeV3: { AnyView(FlickHoopsViewV3()) }),
    GameEntry(name: "Darts",          icon: "target",                  color: .red,
              makeBase: { AnyView(DartsView()) },       makeV2: { AnyView(DartsViewV2()) },       makeV3: { AnyView(DartsViewV3()) }),
    GameEntry(name: "Golf Putt",      icon: "figure.golf",             color: .green,
              makeBase: { AnyView(GolfPuttView()) },    makeV2: { AnyView(GolfPuttViewV2()) },    makeV3: { AnyView(GolfPuttViewV3()) }),
    GameEntry(name: "Archery",        icon: "arrow.right.circle.fill", color: .brown,
              makeBase: { AnyView(ArcheryView()) },     makeV2: { AnyView(ArcheryViewV2()) },     makeV3: { AnyView(ArcheryViewV3()) }),
    GameEntry(name: "Bowling",        icon: "figure.bowling",          color: .purple,
              makeBase: { AnyView(BowlingView()) },     makeV2: { AnyView(BowlingViewV2()) },     makeV3: { AnyView(BowlingViewV3()) }),
    GameEntry(name: "Bubble Pop",     icon: "bubbles.and.sparkles.fill",color: .teal,
              makeBase: { AnyView(BubblePopView()) },   makeV2: { AnyView(BubblePopViewV2()) },   makeV3: { AnyView(BubblePopViewV3()) }),
    GameEntry(name: "Rhythm Tap",     icon: "music.note",              color: .pink,
              makeBase: { AnyView(RhythmTapView()) },   makeV2: { AnyView(RhythmTapViewV2()) },   makeV3: { AnyView(RhythmTapViewV3()) }),
    GameEntry(name: "Type Race",      icon: "keyboard.fill",           color: .indigo,
              makeBase: { AnyView(TypeRaceView()) },    makeV2: { AnyView(TypeRaceViewV2()) },    makeV3: { AnyView(TypeRaceViewV3()) }),
    GameEntry(name: "Color Sort",     icon: "swatchpalette.fill",      color: .cyan,
              makeBase: { AnyView(ColorSortView()) },   makeV2: { AnyView(ColorSortViewV2()) },   makeV3: { AnyView(ColorSortViewV3()) }),
    GameEntry(name: "Maze Runner",    icon: "map.fill",                color: .mint,
              makeBase: { AnyView(MazeView()) },        makeV2: { AnyView(MazeViewV2()) },        makeV3: { AnyView(MazeViewV3()) }),
    // 51-60
    GameEntry(name: "Laser Mirror",   icon: "rays",                    color: .yellow,
              makeBase: { AnyView(LaserMirrorView()) }, makeV2: { AnyView(LaserMirrorViewV2()) }, makeV3: { AnyView(LaserMirrorViewV3()) }),
    GameEntry(name: "Traffic Control",icon: "car.fill",                color: .red,
              makeBase: { AnyView(TrafficView()) },     makeV2: { AnyView(TrafficViewV2()) },     makeV3: { AnyView(TrafficViewV3()) }),
    GameEntry(name: "Parking Puzzle", icon: "parkingsign.circle.fill", color: .blue,
              makeBase: { AnyView(ParkingView()) },     makeV2: { AnyView(ParkingViewV2()) },     makeV3: { AnyView(ParkingViewV3()) }),
    GameEntry(name: "Orbit Game",     icon: "globe",                   color: .purple,
              makeBase: { AnyView(OrbitView()) },       makeV2: { AnyView(OrbitViewV2()) },       makeV3: { AnyView(OrbitViewV3()) }),
    GameEntry(name: "Spin Target",    icon: "scope",                   color: .orange,
              makeBase: { AnyView(SpinTargetView()) },  makeV2: { AnyView(SpinTargetViewV2()) },  makeV3: { AnyView(SpinTargetViewV3()) }),
    GameEntry(name: "Air Hockey",     icon: "circle.hexagongrid.fill", color: .cyan,
              makeBase: { AnyView(AirHockeyView()) },   makeV2: { AnyView(AirHockeyViewV2()) },   makeV3: { AnyView(AirHockeyViewV3()) }),
    GameEntry(name: "Pinball",        icon: "circle.fill",             color: .indigo,
              makeBase: { AnyView(PinballView()) },     makeV2: { AnyView(PinballViewV2()) },     makeV3: { AnyView(PinballViewV3()) }),
    GameEntry(name: "Sokoban",        icon: "shippingbox.fill",        color: .brown,
              makeBase: { AnyView(SokobanView()) },     makeV2: { AnyView(SokobanViewV2()) },     makeV3: { AnyView(SokobanViewV3()) }),
    GameEntry(name: "Nonogram",       icon: "squareshape.split.2x2",   color: .teal,
              makeBase: { AnyView(NonogramView()) },    makeV2: { AnyView(NonogramViewV2()) },    makeV3: { AnyView(NonogramViewV3()) }),
    GameEntry(name: "Sand Fall",      icon: "waveform",                color: .yellow,
              makeBase: { AnyView(SandFallView()) },    makeV2: { AnyView(SandFallViewV2()) },    makeV3: { AnyView(SandFallViewV3()) }),
    // 61-70
    GameEntry(name: "Rope Cut",       icon: "scissors.circle.fill",    color: .green,
              makeBase: { AnyView(RopeCutView()) },     makeV2: { AnyView(RopeCutViewV2()) },     makeV3: { AnyView(RopeCutViewV3()) }),
    GameEntry(name: "Water Flow",     icon: "drop.circle.fill",        color: .blue,
              makeBase: { AnyView(WaterFlowView()) },   makeV2: { AnyView(WaterFlowViewV2()) },   makeV3: { AnyView(WaterFlowViewV3()) }),
    GameEntry(name: "Balance Ball",   icon: "level.fill",              color: .mint,
              makeBase: { AnyView(BalanceBallView()) }, makeV2: { AnyView(BalanceBallViewV2()) }, makeV3: { AnyView(BalanceBallViewV3()) }),
    GameEntry(name: "Tower Climb",    icon: "arrow.up.to.line",        color: .purple,
              makeBase: { AnyView(TowerClimbView()) },  makeV2: { AnyView(TowerClimbViewV2()) },  makeV3: { AnyView(TowerClimbViewV3()) }),
    GameEntry(name: "Emoji Match",    icon: "face.smiling.fill",       color: .yellow,
              makeBase: { AnyView(EmojiMatchView()) },  makeV2: { AnyView(EmojiMatchViewV2()) },  makeV3: { AnyView(EmojiMatchViewV3()) }),
    GameEntry(name: "Shadow Match",   icon: "circle.lefthalf.filled",  color: .gray,
              makeBase: { AnyView(ShadowMatchView()) }, makeV2: { AnyView(ShadowMatchViewV2()) }, makeV3: { AnyView(ShadowMatchViewV3()) }),
    GameEntry(name: "Catch Fish",     icon: "fish.fill",               color: .teal,
              makeBase: { AnyView(CatchFishView()) },   makeV2: { AnyView(CatchFishViewV2()) },   makeV3: { AnyView(CatchFishViewV3()) }),
    GameEntry(name: "Stack Sort",     icon: "list.number",             color: .indigo,
              makeBase: { AnyView(StackSortView()) },   makeV2: { AnyView(StackSortViewV2()) },   makeV3: { AnyView(StackSortViewV3()) }),
    GameEntry(name: "Letter Chain",   icon: "link",                    color: .orange,
              makeBase: { AnyView(LetterChainView()) }, makeV2: { AnyView(LetterChainViewV2()) }, makeV3: { AnyView(LetterChainViewV3()) }),
    GameEntry(name: "Escape Code",    icon: "key.fill",                color: .red,
              makeBase: { AnyView(EscapeCodeView()) },  makeV2: { AnyView(EscapeCodeViewV2()) },  makeV3: { AnyView(EscapeCodeViewV3()) }),
    // 71-80
    GameEntry(name: "Number Merge",   icon: "plus.circle.fill",        color: .blue,
              makeBase: { AnyView(NumberMergeView()) }, makeV2: { AnyView(NumberMergeViewV2()) }, makeV3: { AnyView(NumberMergeViewV3()) }),
    GameEntry(name: "Circuit Board",  icon: "cpu.fill",                color: .green,
              makeBase: { AnyView(CircuitView()) },     makeV2: { AnyView(CircuitViewV2()) },     makeV3: { AnyView(CircuitViewV3()) }),
    GameEntry(name: "Dungeon Crawl",  icon: "sword.fill",              color: .brown,
              makeBase: { AnyView(DungeonView()) },     makeV2: { AnyView(DungeonViewV2()) },     makeV3: { AnyView(DungeonViewV3()) }),
    GameEntry(name: "Beat the Clock", icon: "alarm.fill",              color: .red,
              makeBase: { AnyView(BeatClockView()) },   makeV2: { AnyView(BeatClockViewV2()) },   makeV3: { AnyView(BeatClockViewV3()) }),
    GameEntry(name: "Spot Diff",      icon: "eye.fill",                color: .teal,
              makeBase: { AnyView(SpotDiffView()) },    makeV2: { AnyView(SpotDiffViewV2()) },    makeV3: { AnyView(SpotDiffViewV3()) }),
    GameEntry(name: "Crossy Hop",     icon: "hare.fill",               color: .green,
              makeBase: { AnyView(CrossyHopView()) },   makeV2: { AnyView(CrossyHopViewV2()) },   makeV3: { AnyView(CrossyHopViewV3()) }),
    GameEntry(name: "Magnet Ball",    icon: "magnet.fill",             color: .purple,
              makeBase: { AnyView(MagnetBallView()) },  makeV2: { AnyView(MagnetBallViewV2()) },  makeV3: { AnyView(MagnetBallViewV3()) }),
    GameEntry(name: "Brick Blast",    icon: "square.fill",             color: .orange,
              makeBase: { AnyView(BrickBlastView()) },  makeV2: { AnyView(BrickBlastViewV2()) },  makeV3: { AnyView(BrickBlastViewV3()) }),
    GameEntry(name: "Zen Painter",    icon: "paintbrush.fill",         color: .mint,
              makeBase: { AnyView(ZenPainterView()) },  makeV2: { AnyView(ZenPainterViewV2()) },  makeV3: { AnyView(ZenPainterViewV3()) }),
    GameEntry(name: "Gravity Puzzle", icon: "arrow.down.circle.fill",  color: .cyan,
              makeBase: { AnyView(GravityPuzzleView()) },makeV2: { AnyView(GravityPuzzleViewV2()) },makeV3: { AnyView(GravityPuzzleViewV3()) }),
    // 81-90
    GameEntry(name: "Word Chain",     icon: "arrow.right.doc.on.clipboard", color: .blue,
              makeBase: { AnyView(WordChainView()) },   makeV2: { AnyView(WordChainViewV2()) },   makeV3: { AnyView(WordChainViewV3()) }),
    GameEntry(name: "Memory Seq",     icon: "list.number.rtl",         color: .indigo,
              makeBase: { AnyView(MemorySeqView()) },   makeV2: { AnyView(MemorySeqViewV2()) },   makeV3: { AnyView(MemorySeqViewV3()) }),
    GameEntry(name: "Prime Finder",   icon: "number.circle.fill",      color: .orange,
              makeBase: { AnyView(PrimeFinderView()) }, makeV2: { AnyView(PrimeFinderViewV2()) }, makeV3: { AnyView(PrimeFinderViewV3()) }),
    GameEntry(name: "Color Wave",     icon: "waveform.path",           color: .pink,
              makeBase: { AnyView(ColorWaveView()) },   makeV2: { AnyView(ColorWaveViewV2()) },   makeV3: { AnyView(ColorWaveViewV3()) }),
    GameEntry(name: "Flip Cards",     icon: "rectangle.on.rectangle.fill", color: .red,
              makeBase: { AnyView(FlipCardsView()) },   makeV2: { AnyView(FlipCardsViewV2()) },   makeV3: { AnyView(FlipCardsViewV3()) }),
    GameEntry(name: "Pic Cross",      icon: "squareshape.dotted.squareshape", color: .teal,
              makeBase: { AnyView(PicCrossView()) },    makeV2: { AnyView(PicCrossViewV2()) },    makeV3: { AnyView(PicCrossViewV3()) }),
    GameEntry(name: "Path Finder",    icon: "point.3.filled.connected.trianglepath.dotted", color: .mint,
              makeBase: { AnyView(PathFinderView()) },  makeV2: { AnyView(PathFinderViewV2()) },  makeV3: { AnyView(PathFinderViewV3()) }),
    GameEntry(name: "Infinity Hop",   icon: "infinity.circle.fill",    color: .purple,
              makeBase: { AnyView(InfinityHopView()) }, makeV2: { AnyView(InfinityHopViewV2()) }, makeV3: { AnyView(InfinityHopViewV3()) }),
    GameEntry(name: "Block Push",     icon: "arrow.forward.square.fill",color: .brown,
              makeBase: { AnyView(BlockPushView()) },   makeV2: { AnyView(BlockPushViewV2()) },   makeV3: { AnyView(BlockPushViewV3()) }),
    GameEntry(name: "Final Gauntlet", icon: "flag.checkered.2.crossed", color: .red,
              makeBase: { AnyView(FinalGauntletView()) },makeV2: { AnyView(FinalGauntletViewV2()) },makeV3: { AnyView(FinalGauntletViewV3()) }),
    // 91-100: New Games
    GameEntry(name: "Pong",           icon: "dot.circle.fill",             color: .blue,
              makeBase: { AnyView(PongView()) },         makeV2: { AnyView(PongViewV2()) },         makeV3: { AnyView(PongViewV3()) }),
    GameEntry(name: "Chain Reaction", icon: "burst.fill",                  color: .orange,
              makeBase: { AnyView(ChainReactionView()) },makeV2: { AnyView(ChainReactionViewV2()) },makeV3: { AnyView(ChainReactionViewV3()) }),
    GameEntry(name: "Solitaire",      icon: "suit.spade.fill",             color: .green,
              makeBase: { AnyView(SolitaireView()) },    makeV2: { AnyView(SolitaireViewV2()) },    makeV3: { AnyView(SolitaireViewV3()) }),
    GameEntry(name: "Blackjack",      icon: "suit.heart.fill",             color: .red,
              makeBase: { AnyView(BlackjackView()) },    makeV2: { AnyView(BlackjackViewV2()) },    makeV3: { AnyView(BlackjackViewV3()) }),
    GameEntry(name: "Checkers",       icon: "checkerboard.rectangle",      color: .brown,
              makeBase: { AnyView(CheckersView()) },     makeV2: { AnyView(CheckersViewV2()) },     makeV3: { AnyView(CheckersViewV3()) }),
    GameEntry(name: "Tower of Hanoi", icon: "pyramid.fill",                color: .purple,
              makeBase: { AnyView(TowerHanoiView()) },   makeV2: { AnyView(TowerHanoiViewV2()) },   makeV3: { AnyView(TowerHanoiViewV3()) }),
    GameEntry(name: "Farkle",         icon: "die.face.5.fill",             color: .yellow,
              makeBase: { AnyView(FarkleView()) },       makeV2: { AnyView(FarkleViewV2()) },       makeV3: { AnyView(FarkleViewV3()) }),
    GameEntry(name: "Crossword",      icon: "squareshape.split.3x3",       color: .indigo,
              makeBase: { AnyView(CrosswordView()) },    makeV2: { AnyView(CrosswordViewV2()) },    makeV3: { AnyView(CrosswordViewV3()) }),
    GameEntry(name: "Flag Quiz",      icon: "flag.fill",                   color: .red,
              makeBase: { AnyView(FlagQuizView()) },     makeV2: { AnyView(FlagQuizViewV2()) },     makeV3: { AnyView(FlagQuizViewV3()) }),
    GameEntry(name: "Pixel Art",      icon: "square.grid.3x3.fill",        color: .pink,
              makeBase: { AnyView(PixelArtView()) },     makeV2: { AnyView(PixelArtViewV2()) },     makeV3: { AnyView(PixelArtViewV3()) }),
]

// MARK: - Content View

struct ContentView: View {
    @State private var searchText = ""
    @State private var randomDest: GameEntry? = nil

    static let featured: [GameEntry] = [
        allGames[0],  // Flappy Bird
        allGames[12], // Tetris
        allGames[2],  // Wordle
        allGames[13], // Space Shooter
        allGames[1],  // 2048
        allGames[18], // Bubble Shooter
        allGames[22], // Trivia
        allGames[32], // Asteroid Dodge
    ]

    var filtered: [GameEntry] {
        searchText.isEmpty
            ? allGames
            : allGames.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    if searchText.isEmpty {
                        heroSection
                        statsStrip
                        featuredSection
                    }
                    Section {
                        ForEach(filtered) { game in
                            NavigationLink(destination: GameDetailView(game: game)) {
                                gameRow(game)
                            }
                            .buttonStyle(.plain)
                            if game.id != filtered.last?.id {
                                Divider().padding(.leading, 86)
                            }
                        }
                    } header: {
                        listHeader
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "ゲームを検索…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $randomDest) { game in
            NavigationStack {
                GameDetailView(game: game)
            }
        }
    }

    // MARK: - Hero

    var heroSection: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.08, blue: 0.55),
                    Color(red: 0.06, green: 0.30, blue: 0.80),
                    Color(red: 0.00, green: 0.58, blue: 0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)

            // Decorative blobs
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: 220)
                .blur(radius: 2)
                .offset(x: 100, y: -70)
            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 160)
                .blur(radius: 2)
                .offset(x: -120, y: 30)
            Circle()
                .fill(Color(red: 0.4, green: 0.2, blue: 1.0).opacity(0.25))
                .frame(width: 180)
                .blur(radius: 20)
                .offset(x: -60, y: 80)

            // Content
            VStack(spacing: 20) {
                Spacer().frame(height: 60) // safe area

                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 108, height: 108)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
                        )
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)

                // Title
                VStack(spacing: 6) {
                    Text("Games Hub")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("100のミニゲーム · 3つのデザインスタイル")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }

                // Surprise Me button
                Button {
                    randomDest = allGames[Int.random(in: 0..<allGames.count)]
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14, weight: .bold))
                        Text("サプライズゲーム")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(red: 0.15, green: 0.05, blue: 0.50))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 12, x: 0, y: 5)
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
        .frame(minHeight: 380)
    }

    // MARK: - Stats Strip

    var statsStrip: some View {
        HStack(spacing: 0) {
            statPill(value: "100", label: "ゲーム", icon: "gamecontroller.fill")
            statDivider
            statPill(value: "300", label: "体験", icon: "sparkles")
            statDivider
            statPill(value: "3", label: "スタイル", icon: "paintpalette.fill")
        }
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundStyle(Color(.separator))
        }
    }

    var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 40)
    }

    func statPill(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Featured Section

    var featuredSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("フィーチャー")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                Spacer()
                Text("8ゲーム")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(ContentView.featured) { game in
                        NavigationLink(destination: GameDetailView(game: game)) {
                            featuredCard(game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
        }
        .padding(.bottom, 24)
        .background(Color(.systemBackground))
    }

    func featuredCard(_ game: GameEntry) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [game.color, game.color.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: 162, height: 210)

            // Large decorative icon
            Image(systemName: game.icon)
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.white.opacity(0.18))
                .offset(x: 60, y: -18)
                .clipped()

            // Small icon + text
            VStack(alignment: .leading, spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 36, height: 36)
                    Image(systemName: game.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(game.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Base · V2 · V3")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(14)
        }
        .frame(width: 162, height: 210)
        .shadow(color: game.color.opacity(0.45), radius: 14, x: 0, y: 7)
    }

    // MARK: - All Games List

    var listHeader: some View {
        HStack {
            Text(searchText.isEmpty ? "すべてのゲーム" : "検索結果")
                .font(.system(size: 22, weight: .black, design: .rounded))
            Spacer()
            if searchText.isEmpty {
                Text("\(allGames.count)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().frame(height: 0.5).foregroundStyle(Color(.separator))
        }
    }

    func gameRow(_ game: GameEntry) -> some View {
        HStack(spacing: 14) {
            // App-style icon
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [game.color, game.color.opacity(0.7)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .shadow(color: game.color.opacity(0.3), radius: 6, x: 0, y: 3)
                Image(systemName: game.icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Base · V2 Glass · V3 Neumorphic")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Game Detail

struct GameDetailView: View {
    let game: GameEntry
    @State private var selected = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Version", selection: $selected) {
                Text("Base").tag(0)
                Text("V2 Glass").tag(1)
                Text("V3 Neu").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            switch selected {
            case 1: game.makeV2()
            case 2: game.makeV3()
            default: game.makeBase()
            }
        }
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    ContentView()
}

import SwiftUI

// MARK: - LCG Random Number Generator
struct WdChLCG {
    private var state: UInt64
    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed &* 6364136223846793005 &+ 1442695040888963407))
        if state == 0 { state = 1 }
    }
    mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func nextInt(_ n: Int) -> Int { guard n > 0 else { return 0 }; return Int(next() % UInt64(n)) }
}

// MARK: - Types
enum WdChV3Phase { case start, playing, gameOver }

struct WdChHintLetter: Identifiable {
    let id = UUID()
    let letter: String
    let x: CGFloat
    let y: CGFloat
    let opacity: Double
}

struct WordChainViewV3: View {
    @State private var phase: WdChV3Phase = .start
    @State private var currentWord: String = ""
    @State private var inputText: String = ""
    @State private var usedWords: [String] = []
    @State private var score: Int = 0
    @State private var chainLength: Int = 0
    @State private var timeRemaining: Double = 10.0
    @State private var timer: Timer? = nil
    @State private var errorMessage: String = ""
    @State private var seedInt: Int = 1
    @State private var lcg: WdChLCG = WdChLCG(seed: 1)
    @State private var hintLetters: [WdChHintLetter] = []
    @State private var bonusMultiplier: Int = 1

    private let wordList: [String] = [
        "apple","elephant","tiger","rabbit","bear","rat","top","pen","net","tin","nap","pan",
        "ant","tree","ear","run","nut","tap","pot","ten","nip","pea","ace","egg","gap","get",
        "age","eat","axe","ore","eel","ale","ape","old","owl","oak","odd","oar","inn","ivy",
        "ink","ire","ill","imp","air","aim","aid","ago","add","bad","bag","ban","bar","bat",
        "bay","bed","big","bin","bit","bow","box","bun","bus","but","cab","can","cap","car",
        "cat","cob","cod","cog","cop","cow","cry","cub","cup","cut","dam","day","den","dew",
        "dig","dim","dip","dog","dot","dry","dug","dun","duo","dye","end","era","eve","ewe",
        "eye","fad","fan","far","fat","few","fig","fin","fit","fix","fly","fog","fox","fry",
        "fun","fur","gag","gas","gel","gem","gin","gnu","god","got","gun","gut","guy","gym",
        "had","ham","has","hat","hay","hem","hen","her","hew","hex","hid","him","hip","his",
        "hit","hog","hop","hot","how","hub","hug","hum","hut","jab","jam","jar","jaw","jet",
        "jig","job","jot","joy","jug","jut","keg","key","kid","kin","kit","lab","lag","lap",
        "law","lax","lay","led","leg","let","lid","lip","lit","log","lot","low","lug","mad",
        "man","map","mat","men","mid","mix","mob","mod","mop","mud","mug","nag","nit","nob",
        "nod","nor","not","now","nun","oaf","oat","orb","our","out","own","pad","paw","pay",
        "peg","pet","pie","pig","pin","pit","pox","pro","pub","pun","pup","put","rag","ram",
        "ran","rap","raw","ray","red","ref","rep","rev","rib","rid","rim","rip","rob","rod",
        "rot","row","rub","rug","rum","rut","sad","sag","sat","saw","say","set","sew","shy",
        "sin","sip","sir","sit","six","ski","sky","sly","sob","sod","son","sow","soy","spa",
        "spy","sty","sub","sue","sum","sun","tab","tag","tan","tar","tea","tip","toe","tog",
        "ton","too","toy","try","tub","tug","tun","two","urn","use","van","vat","vet","vow",
        "wag","war","was","wax","web","wed","wet","wig","win","wit","woe","wok","won","woo",
        "wow","yak","yam","yap","yaw","yep","yet","yew","zag","zap","zen","zip","zoo",
        "able","acid","aged","also","area","army","away","baby","back","ball","band","bank",
        "base","bath","been","bell","best","bill","bird","blow","blue","boat","body","bold",
        "bolt","bond","bone","book","boom","boot","bore","both","bulk","bull","burn","busy",
        "buzz","cake","call","calm","came","card","care","case","cash","cast","cave","cell",
        "chat","chip","city","clap","clay","clip","club","clue","coal","coat","code","coil",
        "coin","cold","colt","come","cook","cool","cope","copy","core","corn","cost","cozy",
        "crop","cure","curl","dart","data","date","dawn","dead","deal","dean","dear","deck",
        "deep","deer","desk","dial","dice","diet","dirt","dish","disk","dive","dock","door",
        "dose","down","draw","drip","drop","drum","dual","duel","dull","dump","dusk","dust",
        "duty","each","earn","ease","east","easy","edge","else","emit","even","ever","exam",
        "exit","face","fact","fail","fair","fake","fall","fame","farm","fast","fate","feel",
        "feet","fell","felt","file","fill","film","find","fine","fire","firm","fish","fist",
        "flag","flat","flaw","flea","flew","flip","flit","flow","foam","fold","folk","fond",
        "font","food","fool","foot","ford","fore","fork","form","fort","foul","four","free",
        "from","fuel","full","fund","fuse","fuss","gain","game","gang","gate","gave","gaze",
        "gear","gild","give","glad","glow","glue","goal","gold","golf","gone","good","gown",
        "grab","gray","grew","grid","grin","grip","grow","gulf","gust","guts","hack","hail",
        "hair","half","hall","halt","hand","hang","hard","harm","harp","hash","haul","have",
        "head","heal","heap","hear","heat","heel","held","helm","help","herb","hero","hide",
        "high","hill","hint","hire","hold","hole","holy","home","hood","hook","hope","horn",
        "hose","host","hour","huge","hull","hung","hunt","hurt","hymn","idea","idle","inch",
        "into","iron","isle","item","jail","jean","join","joke","jump","just","keen","keep",
        "kick","kill","kind","king","kiss","knob","knot","know","lack","lake","lamb","lamp",
        "land","lane","lark","last","late","lawn","lead","leaf","lean","leap","left","lend",
        "lens","levy","lick","life","lift","like","limb","lime","line","link","lion","list",
        "live","load","loan","lock","loft","lone","long","look","loop","lore","lose","loss",
        "lost","loud","love","luck","lump","lung","lure","lurk","made","maid","mail","main",
        "make","mall","malt","many","mark","mars","mast","maze","meal","mean","meat","meet",
        "melt","menu","mere","mesh","mild","mile","mill","mind","mine","mint","miss","mist",
        "mode","mole","monk","moon","more","most","moth","move","much","mule","must","myth",
        "nail","name","near","neat","need","nest","news","next","nice","nine","node","none",
        "norm","nose","note","noun","null","obey","once","only","open","oven","over","pace",
        "pack","page","paid","pain","pair","pale","palm","park","part","pass","past","path",
        "peak","peel","peer","perk","pest","pick","pier","pile","pine","pink","pipe","plan",
        "play","plea","plod","plot","plow","plug","plum","plus","poem","poet","pole","poll",
        "pond","pool","poor","pope","pore","pork","port","pose","post","pour","pray","prey",
        "prop","pull","pump","pure","push","race","rack","rage","rain","rake","ramp","rang",
        "rank","rare","rash","rate","rave","read","real","reed","reel","rely","rent","rest",
        "rice","rich","ride","ring","riot","rise","risk","road","roam","roar","role","roll",
        "roof","room","rope","rose","rout","rule","rush","rust","safe","sage","sail","sake",
        "sale","salt","same","sand","sane","sang","sank","seal","seam","seat","seed","seek",
        "seem","seen","self","sell","send","sent","shed","ship","shoe","shop","shot","show",
        "shut","sick","side","sift","sigh","sign","silk","sill","sing","sink","site","size",
        "skin","skip","slam","slap","slim","slip","slot","slow","slug","snap","snob","snow",
        "soak","soap","soar","sock","soft","soil","sole","some","song","sore","sort","soul",
        "sour","span","spar","spin","spit","spot","stab","star","stay","stem","step","stir",
        "stop","stub","stun","such","suit","sure","swap","swam","swan","swat","sway","swim",
        "tack","tale","talk","tall","tame","tank","tape","tart","task","team","tear","tell",
        "tend","tent","term","test","than","that","them","then","they","thin","this","thus",
        "tick","tide","tilt","time","tiny","tire","toad","toll","tomb","tome","tone","took",
        "tool","torn","toss","tour","town","trap","tray","trim","trip","trod","true","tube",
        "tune","turf","turn","twin","type","ugly","unit","unto","upon","urge","used","user",
        "vary","vast","very","view","vine","void","volt","vote","wade","wake","walk","wall",
        "want","ward","warm","wart","wave","weak","wean","wear","weed","week","well","wend",
        "went","were","west","when","whip","wide","wife","wild","will","wind","wine","wing",
        "wire","wise","wish","with","woke","wolf","wood","wool","word","wore","work","worm",
        "worn","wrap","writ","yard","yarn","year","yell","your","zero","zone","zoom"
    ]

    private var wordSet: Set<String> { Set(wordList) }

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            // Floating hint letters in background
            ForEach(hintLetters) { hint in
                Text(hint.letter)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.systemGray4))
                    .opacity(hint.opacity)
                    .position(x: hint.x, y: hint.y)
            }

            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("Word Chain")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(.label))
                Text("Connect words by their last letter.")
                    .foregroundStyle(Color(.secondaryLabel))
                    .font(.subheadline)
            }
            .padding(24)
            .neumorphicCard(radius: 16)

            Button(action: startGame) {
                Text("Start Game")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 52)
                    .padding(.vertical, 16)
            }
            .neumorphicCard(radius: 28)
        }
        .padding()
    }

    // MARK: - Game Screen
    var gameScreen: some View {
        VStack(spacing: 18) {
            // Seed + header info
            HStack {
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
                HStack(spacing: 20) {
                    VStack(spacing: 2) {
                        Text("\(score)").font(.headline.bold())
                        Text("Score").font(.caption2).foregroundStyle(Color(.secondaryLabel))
                    }
                    VStack(spacing: 2) {
                        Text("\(chainLength)").font(.headline.bold())
                        Text("Chain").font(.caption2).foregroundStyle(Color(.secondaryLabel))
                    }
                    if bonusMultiplier > 1 {
                        Text("x\(bonusMultiplier)")
                            .font(.headline.bold())
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.horizontal, 20)

            // Timer bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(timeRemaining > 4 ? Color.green : Color.red)
                        .frame(width: geo.size.width * CGFloat(timeRemaining / 10.0), height: 8)
                        .animation(.linear(duration: 0.1), value: timeRemaining)
                }
            }
            .frame(height: 8)
            .padding(.horizontal)

            // Current word panel
            VStack(spacing: 8) {
                Text("Current Word").font(.caption).foregroundStyle(Color(.tertiaryLabel))
                Text(currentWord.uppercased())
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(.label))
                Text("Next starts with: '\(String(currentWord.last ?? "?").uppercased())'")
                    .font(.caption).foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            // Chain history
            if !usedWords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(usedWords.suffix(6), id: \.self) { w in
                            Text(w)
                                .font(.caption2)
                                .foregroundStyle(Color(.secondaryLabel))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            // Input
            HStack(spacing: 12) {
                TextField("Type word...", text: $inputText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { submitWord() }
                Button(action: submitWord) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .neumorphicCard(radius: 12)
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 24) {
            VStack(spacing: 14) {
                Text("Game Over").font(.largeTitle.bold())
                HStack(spacing: 32) {
                    VStack(spacing: 4) {
                        Text("\(score)").font(.title.bold()).foregroundStyle(.blue)
                        Text("Score").font(.caption).foregroundStyle(Color(.secondaryLabel))
                    }
                    VStack(spacing: 4) {
                        Text("\(chainLength)").font(.title.bold()).foregroundStyle(.green)
                        Text("Chain").font(.caption).foregroundStyle(Color(.secondaryLabel))
                    }
                }
                Text("SEED: #\(seedInt)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .neumorphicCard(radius: 16)
            .padding(.horizontal)

            if !usedWords.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Chain").font(.caption.bold()).foregroundStyle(Color(.secondaryLabel))
                    Text(usedWords.joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(Color(.label))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .neumorphicCard(radius: 16)
                .padding(.horizontal)
            }

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(Color(.label))
                    .padding(.horizontal, 52)
                    .padding(.vertical, 16)
            }
            .neumorphicCard(radius: 28)
        }
        .padding()
    }

    // MARK: - Logic
    func startGame() {
        seedInt += 1
        lcg = WdChLCG(seed: seedInt)
        usedWords = []
        score = 0
        chainLength = 0
        errorMessage = ""
        inputText = ""
        bonusMultiplier = 1
        timeRemaining = 10.0

        let startWords = ["bear","cat","dog","fox","hen","lamp","nail","rain","tree","vine"]
        let idx = lcg.nextInt(startWords.count)
        currentWord = startWords[idx]

        generateHintLetters()
        phase = .playing
        startTimer()
    }

    func generateHintLetters() {
        let letters = "ABCDEFGHIJKLMNOPRSTW"
        let screenWidth: CGFloat = 390
        let screenHeight: CGFloat = 844
        hintLetters = (0..<8).map { _ in
            let letter = String(letters[letters.index(letters.startIndex, offsetBy: lcg.nextInt(letters.count))])
            let x = CGFloat(lcg.nextDouble()) * screenWidth
            let y = CGFloat(lcg.nextDouble()) * screenHeight
            let opacity = lcg.nextDouble() * 0.12 + 0.04
            return WdChHintLetter(letter: letter, x: x, y: y, opacity: opacity)
        }
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 { endGame() }
        }
    }

    func submitWord() {
        let word = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty else { return }

        guard let lastLetter = currentWord.last, word.first == lastLetter else {
            errorMessage = "Must start with '\(String(currentWord.last ?? "?").uppercased())'"
            bonusMultiplier = 1
            return
        }
        guard wordSet.contains(word) else {
            errorMessage = "'\(word)' is not a valid word"
            bonusMultiplier = 1
            return
        }
        guard !usedWords.contains(word) && word != currentWord else {
            errorMessage = "Word already used!"
            return
        }

        // Bonus multiplier: consecutive fast answers
        let timeFraction = timeRemaining / 10.0
        if timeFraction > 0.6 {
            bonusMultiplier = min(bonusMultiplier + 1, 4)
        } else {
            bonusMultiplier = 1
        }
        score += word.count * bonusMultiplier
        chainLength += 1
        usedWords.append(currentWord)
        currentWord = word
        inputText = ""
        errorMessage = ""
        timeRemaining = 10.0

        // Re-seed background hints every few words
        if chainLength % 4 == 0 {
            generateHintLetters()
        }
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        phase = .gameOver
    }
}

#Preview { WordChainViewV3() }

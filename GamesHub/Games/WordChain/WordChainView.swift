import SwiftUI

// MARK: - Types
enum WdChPhase { case start, playing, gameOver }

struct WordChainView: View {
    @State private var phase: WdChPhase = .start
    @State private var currentWord: String = ""
    @State private var inputText: String = ""
    @State private var usedWords: [String] = []
    @State private var score: Int = 0
    @State private var chainLength: Int = 0
    @State private var timeRemaining: Double = 10.0
    @State private var timer: Timer? = nil
    @State private var errorMessage: String = ""
    @State private var isFocused: Bool = false

    private let wordList: Set<String> = [
        "apple","elephant","tiger","rabbit","bear","rat","top","pen","net","tin","nap","pan",
        "ant","tree","ear","run","nut","tap","pot","ten","nip","pea","ace","egg","gap","get",
        "age","eat","axe","ore","eel","ale","ape","eve","ice","eve","old","owl","oak","odd",
        "oar","inn","ivy","ink","ire","ill","imp","air","aim","aid","ago","add","adz","ado",
        "bad","bag","ban","bar","bat","bay","bed","big","bin","bit","bow","box","bun","bus",
        "but","cab","can","cap","car","cat","cob","cod","cog","cop","cow","cry","cub","cup",
        "cut","dam","day","den","dew","dig","dim","dip","dog","dot","dry","dug","dun","duo",
        "dye","ear","end","era","eve","ewe","eye","fad","fan","far","fat","few","fig","fin",
        "fit","fix","fly","fog","for","fox","fry","fun","fur","gag","gas","gel","gem","gin",
        "gnu","god","got","gun","gut","guy","gym","had","ham","has","hat","hay","hem","hen",
        "her","hew","hex","hey","hid","him","hip","his","hit","hog","hop","hot","how","hub",
        "hug","hum","hut","jab","jam","jar","jaw","jet","jig","job","jot","joy","jug","jut",
        "keg","key","kid","kin","kit","lab","lag","lap","law","lax","lay","led","leg","let",
        "lid","lip","lit","log","lot","low","lug","mad","man","map","mat","maw","men","mid",
        "mix","mob","mod","mop","mud","mug","nag","nit","nob","nod","nor","not","now","nun",
        "oaf","oat","orb","our","out","own","pad","paw","pay","peg","pet","pie","pig","pin",
        "pit","pox","pro","pub","pun","pup","pus","put","rag","ram","ran","rap","rat","raw",
        "ray","red","ref","rep","rev","rib","rid","rim","rip","rob","rod","rot","row","rub",
        "rug","rum","rut","sad","sag","sat","saw","say","set","sew","shy","sin","sip","sir",
        "sit","six","ski","sky","sly","sob","sod","son","sow","soy","spa","spy","sty","sub",
        "sue","sum","sun","tab","tag","tan","tar","tea","the","tip","toe","tog","ton","too",
        "toy","try","tub","tug","tun","two","urn","use","van","vat","vet","via","vow","wag",
        "war","was","wax","web","wed","wet","who","why","wig","win","wit","woe","wok","won",
        "woo","wow","yak","yam","yap","yaw","yep","yet","yew","yon","you","yew","zag","zap",
        "zen","zip","zoo","able","acid","aged","also","area","army","away","baby","back","ball",
        "band","bank","base","bath","been","bell","best","bill","bird","blow","blue","boat",
        "body","bold","bolt","bond","bone","book","boom","boot","bore","both","bulk","bull",
        "burn","busy","buzz","cake","call","calm","came","card","care","case","cash","cast",
        "cave","cell","chat","chip","cite","city","clap","clay","clip","club","clue","coal",
        "coat","code","coil","coin","cold","colt","come","cook","cool","cope","copy","core",
        "corn","cost","cozy","crop","cure","curl","dart","data","date","dawn","dead","deal",
        "dean","dear","deck","deep","deer","desk","dial","dice","diet","dirt","dish","disk",
        "dive","dock","door","dose","down","draw","drip","drop","drum","dual","duel","dull",
        "dump","dusk","dust","duty","each","earn","ease","east","easy","edge","else","emit",
        "even","ever","exam","exit","face","fact","fail","fair","fake","fall","fame","farm",
        "fast","fate","feel","feet","fell","felt","file","fill","film","find","fine","fire",
        "firm","fish","fist","flag","flat","flaw","flea","flew","flip","flit","flog","flow",
        "foam","fold","folk","fond","font","food","fool","foot","ford","fore","fork","form",
        "fort","foul","four","free","from","fuel","full","fund","fuse","fuss","gain","game",
        "gang","gate","gave","gaze","gear","gild","give","glad","glow","glue","goal","gold",
        "golf","gone","good","gown","grab","gray","grew","grid","grin","grip","grow","gulf",
        "gust","guts","hack","hail","hair","half","hall","halt","hand","hang","hard","harm",
        "harp","hash","haul","have","head","heal","heap","hear","heat","heel","held","helm",
        "help","herb","hero","hide","high","hill","hint","hire","hold","hole","holy","home",
        "hood","hook","hope","horn","hose","host","hour","huge","hull","hung","hunt","hurt",
        "hymn","idea","idle","inch","into","iron","isle","item","jail","jean","join","joke",
        "jump","just","keen","keep","kick","kill","kind","king","kiss","knob","knot","know",
        "lack","lake","lamb","lamp","land","lane","lark","last","late","lawn","lead","leaf",
        "lean","leap","left","lend","lens","levy","lick","life","lift","like","limb","lime",
        "line","link","lion","list","live","load","loan","lock","loft","lone","long","look",
        "loop","lore","lose","loss","lost","loud","love","luck","lump","lung","lure","lurk",
        "made","maid","mail","main","make","mall","malt","many","mark","mars","mast","maze",
        "meal","mean","meat","meet","melt","menu","mere","mesh","mild","mile","mill","mind",
        "mine","mint","miss","mist","mode","mole","monk","moon","more","most","moth","move",
        "much","mule","must","myth","nail","name","near","neat","need","nest","news","next",
        "nice","nine","node","none","norm","nose","note","noun","null","obey","once","only",
        "open","oven","over","pace","pack","page","paid","pain","pair","pale","palm","park",
        "part","pass","past","path","peak","peel","peer","perk","pest","pick","pier","pile",
        "pine","pink","pipe","plan","play","plea","plod","plot","plow","plug","plum","plus",
        "poem","poet","pole","poll","pond","pool","poor","pope","pore","pork","port","pose",
        "post","pour","pray","prey","prop","pull","pump","pure","push","quad","quit","quiz",
        "race","rack","rage","rain","rake","ramp","rang","rank","rape","rare","rash","rate",
        "rave","reach","read","real","reed","reel","rely","rent","rest","rice","rich","ride",
        "ring","riot","rise","risk","road","roam","roar","role","roll","roof","room","rope",
        "rose","rout","rule","rush","rust","safe","sage","sail","sake","sale","salt","same",
        "sand","sane","sang","sank","seal","seam","seat","seed","seek","seem","seen","self",
        "sell","send","sent","shed","ship","shoe","shop","shot","show","shut","sick","side",
        "sift","sigh","sign","silk","sill","sing","sink","site","size","skin","skip","slam",
        "slap","slim","slip","slot","slow","slug","snap","snob","snow","soak","soap","soar",
        "sock","soft","soil","sole","some","song","sore","sort","soul","sour","span","spar",
        "spin","spit","spot","stab","star","stay","stem","step","stir","stop","stub","stun",
        "such","suit","sure","swap","swam","swan","swat","sway","swim","swum","sync","tack",
        "tale","talk","tall","tame","tank","tape","tart","task","team","tear","tell","tend",
        "tent","term","test","than","that","them","then","they","thin","this","thus","tick",
        "tide","tilt","time","tiny","tire","toad","toll","tomb","tome","tone","took","tool",
        "torn","toss","tour","town","trap","tray","trim","trip","trod","true","tube","tune",
        "turf","turn","twin","type","ugly","unit","unto","upon","urge","used","user","vary",
        "vast","very","view","vine","void","volt","vote","wade","wake","walk","wall","want",
        "ward","warm","wart","wave","weak","wean","wear","weed","week","well","wend","went",
        "were","west","when","whip","wide","wife","wild","will","wind","wine","wing","wire",
        "wise","wish","with","woke","wolf","wood","wool","word","wore","work","worm","worn",
        "wrap","writ","yard","yarn","year","yell","your","zero","zone","zoom"
    ]

    private let startWords = ["bear","cat","dog","fox","hen","lamp","nail","rain","tree","vine"]

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            switch phase {
            case .start: startScreen
            case .playing: gameScreen
            case .gameOver: gameOverScreen
            }
        }
    }

    // MARK: - Start Screen
    var startScreen: some View {
        VStack(spacing: 24) {
            Text("Word Chain")
                .font(.largeTitle.bold())
            Text("Type a word starting with the\nlast letter of the previous word.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("10 seconds per word. Score by length.")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button(action: startGame) {
                Text("Start")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Game Screen
    var gameScreen: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Score: \(score)").font(.headline)
                    Text("Chain: \(chainLength)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 6).frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: timeRemaining / 10.0)
                        .stroke(timeRemaining > 4 ? Color.green : Color.red, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 54, height: 54)
                        .rotationEffect(.degrees(-90))
                    Text(String(format: "%.0f", timeRemaining))
                        .font(.headline.monospacedDigit())
                }
            }
            .padding(.horizontal)

            VStack(spacing: 6) {
                Text("Current word:").font(.caption).foregroundStyle(.secondary)
                Text(currentWord.uppercased())
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                Text("Next word starts with: \(String(currentWord.last ?? "?").uppercased())")
                    .font(.caption).foregroundStyle(.blue)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if !usedWords.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(usedWords.suffix(8), id: \.self) { w in
                            Text(w)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.12))
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

            HStack(spacing: 12) {
                TextField("Type word...", text: $inputText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onSubmit { submitWord() }

                Button(action: submitWord) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - Game Over Screen
    var gameOverScreen: some View {
        VStack(spacing: 24) {
            Text("Game Over").font(.largeTitle.bold())
            VStack(spacing: 8) {
                Text("Score: \(score)").font(.title2)
                Text("Chain Length: \(chainLength)").font(.headline).foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if !usedWords.isEmpty {
                Text("Your chain:").font(.headline)
                Text(usedWords.joined(separator: " → "))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            Button(action: startGame) {
                Text("Play Again")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .padding()
    }

    // MARK: - Logic
    func startGame() {
        usedWords = []
        score = 0
        chainLength = 0
        errorMessage = ""
        inputText = ""
        currentWord = startWords.randomElement()!
        timeRemaining = 10.0
        phase = .playing
        startTimer()
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            timeRemaining -= 0.1
            if timeRemaining <= 0 {
                endGame()
            }
        }
    }

    func submitWord() {
        let word = inputText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !word.isEmpty else { return }

        guard let lastLetter = currentWord.last, word.first == lastLetter else {
            errorMessage = "Must start with '\(String(currentWord.last ?? "?").uppercased())'"
            return
        }
        guard wordList.contains(word) else {
            errorMessage = "'\(word)' is not a valid word"
            return
        }
        guard !usedWords.contains(word) && word != currentWord else {
            errorMessage = "Word already used!"
            return
        }

        score += word.count
        chainLength += 1
        usedWords.append(currentWord)
        currentWord = word
        inputText = ""
        errorMessage = ""
        timeRemaining = 10.0
    }

    func endGame() {
        timer?.invalidate()
        timer = nil
        phase = .gameOver
    }
}

#Preview { WordChainView() }

import SwiftUI
import UIKit

extension Notification.Name {
    static let sessionDidComplete = Notification.Name("sessionDidComplete")
}

// MARK: - Session State

@Observable
final class StudySession {
    let deck: Deck
    let languageCode: String
    let reverseMode: Bool
    let typingMode: Bool
    let isRestudy: Bool
    var shuffledCards: [Flashcard]
    var currentIndex = 0
    var isFlipped = false
    var cardRotation: Double = 0
    var correctCount = 0
    var incorrectCount = 0
    var showingResults = false
    var correctCards: [Flashcard] = []
    var incorrectCards: [Flashcard] = []
    var typedAnswer = ""
    var answerSubmitted = false
    var answerCorrect = false
    var cardResults: [Int: Bool] = [:]  // index → wasCorrect
    var cardTypedAnswers: [Int: String] = [:]  // index → what was typed
    var furthestIndex = 0  // highest index reached

    var isReviewingPastCard: Bool {
        currentIndex < furthestIndex
    }

    init(deck: Deck, specificCards: [Flashcard]?, reverseMode: Bool = false, typingMode: Bool = false, shuffleMode: Bool = true, isRestudy: Bool = false) {
        self.deck = deck
        self.languageCode = deck.languageCode
        self.reverseMode = reverseMode
        self.typingMode = typingMode
        self.isRestudy = isRestudy
        let cards: [Flashcard]
        if let specific = specificCards {
            cards = specific
        } else {
            cards = Array(deck.cards)
        }
        self.shuffledCards = shuffleMode ? cards.shuffled() : cards.sorted { $0.rank < $1.rank }
    }

    var currentCard: Flashcard? {
        guard currentIndex >= 0, currentIndex < shuffledCards.count else { return nil }
        return shuffledCards[currentIndex]
    }

    // In reverse mode, front shows English and back shows the foreign word
    var displayFront: String {
        guard let card = currentCard else { return "" }
        return reverseMode ? card.back : card.front
    }

    var displayBack: String {
        guard let card = currentCard else { return "" }
        return reverseMode ? card.front : card.back
    }

    var canGoBack: Bool { currentIndex > 0 }
    var canGoForward: Bool { currentIndex + 1 < shuffledCards.count }

    func saveProgress() {
        let prefix = "session_\(deck.name)_\(typingMode ? "type" : "flash")"
        UserDefaults.standard.set(currentIndex, forKey: prefix)
        UserDefaults.standard.set(shuffledCards.count, forKey: "sessionCount_\(deck.name)_\(typingMode ? "type" : "flash")")
        // Save the card order so we can restore the exact shuffle on resume
        let order = shuffledCards.map { $0.front }
        UserDefaults.standard.set(order, forKey: "\(prefix)_order")
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: .sessionDidComplete, object: nil)
    }

    static func savedIndex(for deckName: String, typingMode: Bool) -> Int? {
        let key = "session_\(deckName)_\(typingMode ? "type" : "flash")"
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: key)
    }

    static func savedCardCount(for deckName: String, typingMode: Bool) -> Int? {
        let countKey = "sessionCount_\(deckName)_\(typingMode ? "type" : "flash")"
        guard UserDefaults.standard.object(forKey: countKey) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: countKey)
    }

    static func savedCardOrder(for deckName: String, typingMode: Bool) -> [String]? {
        let key = "session_\(deckName)_\(typingMode ? "type" : "flash")_order"
        return UserDefaults.standard.stringArray(forKey: key)
    }

    static func clearSavedSession(for deckName: String, typingMode: Bool) {
        let prefix = "session_\(deckName)_\(typingMode ? "type" : "flash")"
        UserDefaults.standard.removeObject(forKey: prefix)
        UserDefaults.standard.removeObject(forKey: "sessionCount_\(deckName)_\(typingMode ? "type" : "flash")")
        UserDefaults.standard.removeObject(forKey: "\(prefix)_order")
        UserDefaults.standard.synchronize()
    }

    func markCorrect() {
        guard let card = currentCard else { return }

        // If revisiting a card in flashcard mode, undo the previous result first
        if let previousResult = cardResults[currentIndex] {
            if previousResult {
                // Was already correct — no change needed, just advance
                advance()
                return
            } else {
                // Was incorrect, now marking correct — undo incorrect
                if typingMode {
                    card.typingIncorrectCount = max(0, card.typingIncorrectCount - 1)
                } else {
                    card.incorrectCount = max(0, card.incorrectCount - 1)
                }
                incorrectCount = max(0, incorrectCount - 1)
                incorrectCards.removeAll { $0.id == card.id }
            }
        }

        if typingMode {
            card.typingCorrectCount += 1
        } else {
            card.correctCount += 1
        }
        card.lastReviewedAt = Date()
        correctCount += 1
        correctCards.append(card)
        cardResults[currentIndex] = true
        haptic(.success)
        advance()
    }

    func markIncorrect() {
        guard let card = currentCard else { return }

        // If revisiting a card in flashcard mode, undo the previous result first
        if let previousResult = cardResults[currentIndex] {
            if !previousResult {
                // Was already incorrect — no change needed, just advance
                advance()
                return
            } else {
                // Was correct, now marking incorrect — undo correct
                if typingMode {
                    card.typingCorrectCount = max(0, card.typingCorrectCount - 1)
                } else {
                    card.correctCount = max(0, card.correctCount - 1)
                }
                correctCount = max(0, correctCount - 1)
                correctCards.removeAll { $0.id == card.id }
            }
        }

        if typingMode {
            card.typingIncorrectCount += 1
        } else {
            card.incorrectCount += 1
        }
        card.lastReviewedAt = Date()
        incorrectCount += 1
        incorrectCards.append(card)
        cardResults[currentIndex] = false
        haptic(.error)
        advance()
    }

    func advance() {
        if canGoForward {
            currentIndex += 1
            furthestIndex = max(furthestIndex, currentIndex)
            resetCardState()
        } else {
            showingResults = true
            if !isRestudy {
                StudySession.clearSavedSession(for: deck.name, typingMode: typingMode)
            }
        }
    }

    func goForward() {
        guard canGoForward else { return }
        currentIndex += 1
        resetCardState()
    }

    func goBack() {
        guard canGoBack else { return }
        currentIndex -= 1
        resetCardState()
    }

    func flipCard() {
        cardRotation += 180
        isFlipped.toggle()
        haptic(.light)
    }

    func submitTypedAnswer() {
        guard !answerSubmitted else { return }
        answerSubmitted = true
        cardTypedAnswers[currentIndex] = typedAnswer

        let typed = normalize(typedAnswer)
        guard !typed.isEmpty else {
            answerCorrect = false
            guard let card = currentCard else { return }
            card.typingIncorrectCount += 1
            card.lastReviewedAt = Date()
            incorrectCount += 1
            incorrectCards.append(card)
            cardResults[currentIndex] = false
            haptic(.error)
            return
        }

        let correctRaw = displayBack
        var acceptable: Set<String> = []

        let slashParts = correctRaw.components(separatedBy: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in slashParts {
            addVariants(of: part, to: &acceptable)
        }
        addVariants(of: correctRaw, to: &acceptable)

        answerCorrect = acceptable.contains(typed)

        guard let card = currentCard else { return }
        if answerCorrect {
            card.typingCorrectCount += 1
            card.lastReviewedAt = Date()
            correctCount += 1
            correctCards.append(card)
            cardResults[currentIndex] = true
            haptic(.success)
        } else {
            card.typingIncorrectCount += 1
            card.lastReviewedAt = Date()
            incorrectCount += 1
            incorrectCards.append(card)
            cardResults[currentIndex] = false
            haptic(.error)
        }
    }

    // Synonym groups — each array is a group of interchangeable words.
    // Any word in a group is accepted as correct for any other word in the same group.
    private static let synonymGroups: [[String]] = [
        // Greetings & expressions
        ["yes", "ok", "okay", "yeah", "yep", "yea", "sure"],
        ["no", "nope", "nah"],
        ["hello", "hi", "hey", "greetings", "howdy"],
        ["goodbye", "bye", "see you", "farewell", "later"],
        ["thank you", "thanks", "cheers", "ty"],
        ["excuse me", "sorry", "pardon", "apologies"],
        // Adjectives
        ["good", "fine", "well", "great", "nice", "decent"],
        ["bad", "poor", "terrible", "awful", "horrible"],
        ["big", "large", "huge", "enormous", "giant"],
        ["small", "little", "tiny", "mini", "miniature"],
        ["beautiful", "pretty", "lovely", "gorgeous", "attractive", "handsome"],
        ["ugly", "hideous", "unattractive"],
        ["happy", "glad", "joyful", "cheerful", "pleased", "content"],
        ["sad", "unhappy", "miserable", "depressed", "sorrowful"],
        ["angry", "mad", "furious", "annoyed", "irritated"],
        ["afraid", "scared", "frightened", "terrified", "fearful"],
        ["strong", "powerful", "mighty", "tough"],
        ["weak", "feeble", "frail"],
        ["fast", "quick", "rapid", "swift", "speedy"],
        ["slow", "sluggish", "gradual", "unhurried"],
        ["hot", "warm", "boiling", "burning"],
        ["cold", "cool", "chilly", "freezing", "frigid"],
        ["new", "fresh", "modern", "recent"],
        ["old", "ancient", "aged", "elderly"],
        ["young", "youthful", "juvenile"],
        ["rich", "wealthy", "affluent", "prosperous"],
        ["clean", "tidy", "neat", "spotless"],
        ["dirty", "filthy", "messy", "unclean"],
        ["quiet", "silent", "calm", "peaceful", "still", "tranquil", "serene"],
        ["loud", "noisy", "boisterous"],
        ["easy", "simple", "effortless", "straightforward"],
        ["difficult", "hard", "tough", "challenging", "complicated"],
        ["important", "significant", "crucial", "vital", "essential"],
        ["dangerous", "risky", "hazardous", "perilous", "unsafe"],
        ["safe", "secure", "protected"],
        ["correct", "right", "accurate", "proper"],
        ["wrong", "incorrect", "mistaken"],
        ["true", "real", "genuine", "authentic"],
        ["false", "fake", "untrue"],
        ["full", "complete", "filled", "packed"],
        ["empty", "vacant", "bare", "hollow"],
        ["near", "close", "nearby", "adjacent"],
        ["far", "distant", "remote"],
        ["strange", "odd", "weird", "unusual", "peculiar", "bizarre"],
        ["obvious", "clear", "apparent", "evident"],
        ["certain", "sure", "definite", "positive"],
        ["entire", "whole", "complete", "total", "full"],
        ["brief", "short", "quick"],
        ["wide", "broad", "expansive"],
        ["narrow", "thin", "slim"],
        ["thick", "dense", "heavy"],
        ["bright", "brilliant", "vivid", "radiant", "luminous"],
        ["dark", "dim", "gloomy", "murky"],
        ["sharp", "keen", "acute"],
        ["dull", "boring", "tedious", "bland", "monotonous"],
        ["gentle", "soft", "mild", "tender", "delicate"],
        ["rough", "coarse", "harsh", "rugged"],
        ["clever", "smart", "intelligent", "bright", "brilliant", "wise"],
        ["stupid", "dumb", "foolish", "idiotic"],
        ["brave", "courageous", "bold", "fearless", "valiant"],
        ["polite", "courteous", "respectful", "civil"],
        ["rude", "impolite", "disrespectful"],
        ["kind", "nice", "generous", "compassionate", "benevolent"],
        ["cruel", "mean", "harsh", "brutal", "ruthless"],
        ["honest", "truthful", "sincere", "frank"],
        ["lazy", "idle", "sluggish"],
        ["busy", "occupied", "engaged"],
        ["free", "liberated", "independent"],
        ["guilty", "culpable", "at fault"],
        ["innocent", "blameless", "guiltless"],
        ["famous", "well-known", "renowned", "celebrated", "notable"],
        ["rare", "uncommon", "unusual", "scarce"],
        ["common", "ordinary", "typical", "usual", "normal", "regular"],
        ["special", "unique", "distinctive", "exceptional"],
        ["similar", "alike", "comparable", "like"],
        ["different", "distinct", "unlike", "diverse"],
        ["suitable", "appropriate", "fitting", "proper"],
        ["necessary", "essential", "required", "needed"],
        ["possible", "feasible", "achievable"],
        ["impossible", "unachievable", "unfeasible"],
        ["available", "accessible", "obtainable"],
        ["expensive", "costly", "pricey", "dear"],
        ["cheap", "inexpensive", "affordable", "low-cost"],
        // People
        ["man", "guy", "male", "gentleman", "fellow"],
        ["woman", "lady", "female", "gal"],
        ["child", "kid", "youngster"],
        ["baby", "infant", "newborn"],
        ["doctor", "physician", "medic"],
        ["teacher", "instructor", "educator", "professor"],
        ["student", "pupil", "learner"],
        ["friend", "pal", "buddy", "mate", "companion"],
        ["enemy", "foe", "opponent", "rival", "adversary"],
        ["leader", "chief", "head", "boss", "commander"],
        ["wife", "spouse", "partner"],
        ["husband", "spouse", "partner"],
        // Places & things
        ["house", "home", "dwelling", "residence"],
        ["room", "chamber", "space"],
        ["car", "automobile", "vehicle", "auto"],
        ["food", "meal", "cuisine", "nourishment"],
        ["money", "cash", "currency", "funds"],
        ["work", "job", "employment", "occupation", "labor"],
        ["shop", "store", "market"],
        ["road", "street", "path", "way"],
        ["town", "city", "village"],
        ["country", "nation", "land", "state"],
        ["world", "earth", "globe"],
        ["border", "boundary", "frontier", "edge"],
        ["center", "middle", "core", "heart"],
        ["piece", "part", "portion", "fragment", "bit", "section"],
        ["group", "team", "band", "crew"],
        ["picture", "image", "photo", "photograph"],
        ["letter", "message", "note"],
        ["clothes", "clothing", "garments", "attire"],
        ["trash", "garbage", "rubbish", "waste", "junk"],
        ["gift", "present", "offering"],
        ["mistake", "error", "blunder", "fault"],
        ["idea", "thought", "concept", "notion"],
        ["goal", "aim", "objective", "target", "purpose"],
        ["rule", "regulation", "law", "guideline"],
        ["price", "cost", "value", "worth"],
        ["noise", "sound", "racket"],
        ["speech", "address", "talk", "lecture"],
        // Verbs
        ["speak", "talk", "say", "tell", "communicate"],
        ["eat", "consume", "dine", "feed"],
        ["drink", "sip", "gulp"],
        ["walk", "stroll", "wander", "hike", "march"],
        ["run", "sprint", "jog", "dash", "race"],
        ["begin", "start", "commence", "initiate"],
        ["end", "finish", "stop", "complete", "conclude", "terminate"],
        ["buy", "purchase", "acquire"],
        ["sell", "vend", "trade"],
        ["give", "offer", "provide", "donate", "grant"],
        ["take", "grab", "seize", "obtain"],
        ["look", "watch", "see", "observe", "view", "gaze"],
        ["listen", "hear"],
        ["want", "desire", "wish", "crave"],
        ["need", "require"],
        ["like", "enjoy", "appreciate", "fancy"],
        ["love", "adore", "cherish", "treasure"],
        ["hate", "despise", "detest", "loathe"],
        ["think", "believe", "consider", "ponder", "reflect"],
        ["know", "understand", "comprehend", "realize"],
        ["learn", "study", "discover", "master"],
        ["teach", "instruct", "educate", "train"],
        ["help", "assist", "aid", "support"],
        ["try", "attempt", "endeavor"],
        ["make", "create", "build", "construct", "produce"],
        ["break", "smash", "shatter", "crack", "destroy"],
        ["fix", "repair", "mend", "restore"],
        ["send", "deliver", "ship", "dispatch"],
        ["receive", "get", "obtain", "accept"],
        ["open", "unlock", "uncover"],
        ["close", "shut", "seal"],
        ["come", "arrive", "approach"],
        ["go", "leave", "depart"],
        ["return", "come back", "go back"],
        ["wait", "hold on", "remain"],
        ["sleep", "rest", "nap", "doze", "slumber"],
        ["wake", "awaken", "get up", "rise"],
        ["live", "reside", "dwell", "exist"],
        ["die", "perish", "pass away"],
        ["laugh", "chuckle", "giggle"],
        ["cry", "weep", "sob"],
        ["write", "compose", "author", "pen"],
        ["cook", "prepare"],
        ["wash", "clean", "rinse", "scrub"],
        ["wear", "put on", "dress in"],
        ["carry", "hold", "bear", "transport"],
        ["throw", "toss", "hurl", "fling"],
        ["catch", "grab", "seize", "capture"],
        ["cut", "slice", "chop", "trim"],
        ["pull", "drag", "tug", "yank"],
        ["push", "shove", "press"],
        ["choose", "select", "pick", "opt"],
        ["decide", "determine", "resolve"],
        ["change", "alter", "modify", "adjust"],
        ["grow", "expand", "develop", "increase"],
        ["fall", "drop", "tumble", "collapse"],
        ["fly", "soar", "glide"],
        ["swim", "float", "paddle"],
        ["drive", "operate", "steer"],
        ["travel", "journey", "voyage", "tour"],
        ["search", "look for", "seek", "hunt"],
        ["find", "discover", "locate", "uncover"],
        ["lose", "misplace"],
        ["win", "triumph", "succeed", "prevail"],
        ["fight", "battle", "combat", "struggle"],
        ["cure", "heal", "treat", "remedy"],
        ["ill", "sick", "unwell", "diseased"],
        ["pain", "ache", "hurt", "suffering"],
        ["answer", "reply", "respond"],
        ["ask", "inquire", "request"],
        ["explain", "describe", "clarify"],
        ["show", "display", "demonstrate", "present", "reveal"],
        ["hide", "conceal", "cover"],
        ["call", "phone", "ring", "contact"],
        ["meet", "encounter", "greet"],
        ["stay", "remain", "linger"],
        ["forget", "overlook"],
        ["remember", "recall", "recollect"],
        ["allow", "permit", "let", "authorize"],
        ["forbid", "prohibit", "ban", "prevent"],
        ["increase", "raise", "boost", "elevate"],
        ["decrease", "reduce", "lower", "diminish", "lessen"],
        ["improve", "enhance", "better", "upgrade"],
        ["damage", "harm", "injure", "hurt"],
        ["protect", "defend", "guard", "shield", "shelter"],
        ["attack", "assault", "strike"],
        ["accept", "agree", "approve", "consent"],
        ["refuse", "decline", "reject", "deny"],
        ["gather", "collect", "assemble", "accumulate"],
        ["scatter", "spread", "disperse"],
        ["connect", "join", "link", "unite", "attach"],
        ["separate", "divide", "split", "detach"],
        ["mix", "blend", "combine", "merge"],
        ["fill", "load", "stuff", "pack"],
        ["pour", "flow", "stream"],
        ["grab", "snatch", "clutch", "grip"],
        ["release", "let go", "free", "drop"],
        ["lift", "raise", "hoist", "elevate"],
        ["support", "sustain", "uphold", "maintain"],
        ["achieve", "accomplish", "attain", "reach"],
        ["fail", "flunk", "miss"],
        ["announce", "declare", "proclaim", "state"],
        ["whisper", "murmur", "mutter"],
        ["shout", "yell", "scream", "cry out"],
        ["wish", "hope", "desire", "long for"],
        ["fear", "dread"],
        ["trust", "rely on", "count on", "depend on"],
        ["doubt", "question", "suspect"],
        ["suffer", "endure", "bear", "undergo"],
        ["celebrate", "commemorate", "honor"],
        ["punish", "penalize", "discipline"],
        ["reward", "compensate"],
        ["own", "possess", "have"],
        ["belong", "pertain"],
        ["exist", "be", "live"],
        ["disappear", "vanish", "fade"],
        ["appear", "emerge", "surface", "show up"],
        ["happen", "occur", "take place"],
        ["cause", "create", "trigger", "produce"],
        ["contain", "hold", "include"],
        ["surround", "encircle", "enclose"],
        // Adverbs & misc
        ["also", "too", "as well", "additionally"],
        ["very", "really", "extremely", "incredibly", "highly"],
        ["always", "forever", "constantly", "perpetually"],
        ["never", "not ever", "at no time"],
        ["often", "frequently", "regularly"],
        ["sometimes", "occasionally", "at times"],
        ["maybe", "perhaps", "possibly", "potentially"],
        ["now", "currently", "at the moment", "presently"],
        ["already", "previously"],
        ["soon", "shortly", "before long"],
        ["quickly", "rapidly", "swiftly", "fast", "speedily"],
        ["slowly", "gradually", "unhurriedly"],
        ["enough", "sufficient", "adequate"],
        ["together", "jointly", "collectively"],
        ["alone", "by oneself", "solo"],
        ["however", "but", "nevertheless", "nonetheless", "yet"],
        ["therefore", "thus", "consequently", "hence", "so"],
        ["although", "though", "even though", "despite"],
        ["about", "approximately", "roughly", "around", "nearly"],
        // Emotions & states
        ["upset", "distressed", "troubled", "bothered"],
        ["excited", "thrilled", "enthusiastic", "eager"],
        ["surprised", "astonished", "amazed", "shocked", "startled"],
        ["proud", "dignified"],
        ["ashamed", "embarrassed", "humiliated"],
        ["jealous", "envious"],
        ["grateful", "thankful", "appreciative"],
        ["anxious", "nervous", "worried", "uneasy", "apprehensive"],
        ["bored", "uninterested", "indifferent"],
        ["confused", "puzzled", "bewildered", "perplexed"],
        ["satisfied", "fulfilled", "contented"],
        ["disappointed", "let down", "disheartened"],
        ["lonely", "alone", "isolated", "solitary"],
        // More adjectives from actual card data
        ["wonderful", "marvelous", "fantastic", "terrific", "magnificent", "splendid", "superb"],
        ["excellent", "outstanding", "exceptional", "first-rate"],
        ["awful", "dreadful", "atrocious", "ghastly"],
        ["tiny", "minuscule", "minute"],
        ["enormous", "immense", "massive", "colossal", "gigantic", "vast"],
        ["ancient", "antique", "archaic"],
        ["modern", "contemporary", "current", "up-to-date"],
        ["wet", "damp", "moist", "soaked", "soggy"],
        ["dry", "arid", "parched", "dehydrated"],
        ["tall", "high", "lofty", "towering"],
        ["deep", "profound"],
        ["shallow", "superficial"],
        ["heavy", "weighty", "hefty"],
        ["pure", "clean", "pristine", "untainted"],
        ["smooth", "sleek", "even", "flat"],
        ["straight", "direct", "undeviating"],
        ["crooked", "bent", "curved", "twisted"],
        ["firm", "solid", "steady", "stable", "sturdy"],
        ["loose", "slack", "relaxed"],
        ["tight", "taut", "snug"],
        ["exact", "precise", "accurate", "specific"],
        ["vague", "unclear", "ambiguous", "indefinite"],
        ["complete", "total", "utter", "thorough", "absolute"],
        ["partial", "incomplete", "limited"],
        ["permanent", "lasting", "enduring", "eternal", "perpetual"],
        ["temporary", "brief", "short-lived", "transient"],
        ["constant", "continuous", "steady", "persistent"],
        ["frequent", "regular", "repeated", "recurrent"],
        ["sudden", "abrupt", "unexpected"],
        ["gradual", "slow", "progressive", "steady"],
        ["main", "primary", "chief", "principal", "major"],
        ["minor", "secondary", "lesser", "trivial"],
        ["huge", "immense", "vast", "massive", "enormous"],
        ["sufficient", "enough", "adequate", "ample"],
        ["abundant", "plentiful", "copious", "ample"],
        ["scarce", "rare", "sparse", "limited"],
        ["eager", "keen", "enthusiastic", "avid"],
        ["reluctant", "unwilling", "hesitant"],
        ["severe", "harsh", "strict", "stern"],
        ["mild", "gentle", "moderate", "temperate"],
        ["fierce", "ferocious", "savage", "intense"],
        ["genuine", "authentic", "real", "true", "sincere"],
        ["fake", "false", "counterfeit", "phony"],
        ["loyal", "faithful", "devoted", "dedicated"],
        ["humble", "modest", "unassuming"],
        ["arrogant", "proud", "conceited", "haughty"],
        ["generous", "giving", "charitable", "liberal"],
        ["selfish", "greedy", "self-centered"],
        ["stubborn", "obstinate", "persistent", "determined"],
        ["flexible", "adaptable", "versatile", "pliable"],
        ["rigid", "stiff", "inflexible"],
        ["fragile", "delicate", "breakable", "frail"],
        ["solid", "firm", "hard", "sturdy", "robust"],
        ["hollow", "empty", "vacant"],
        ["dense", "thick", "compact", "concentrated"],
        ["elegant", "graceful", "refined", "sophisticated"],
        ["clumsy", "awkward", "ungainly"],
        ["graceful", "elegant", "fluid", "smooth"],
        ["lively", "energetic", "vibrant", "dynamic", "spirited"],
        ["dull", "boring", "tedious", "monotonous", "dreary"],
        ["plain", "simple", "ordinary", "basic"],
        ["fancy", "elaborate", "ornate", "decorative"],
        ["obvious", "clear", "apparent", "evident", "plain"],
        ["hidden", "concealed", "secret", "covert"],
        ["visible", "apparent", "noticeable", "conspicuous"],
        ["mysterious", "enigmatic", "puzzling", "cryptic"],
        ["familiar", "well-known", "recognized"],
        ["foreign", "alien", "exotic", "strange"],
        ["native", "indigenous", "local", "domestic"],
        ["contemporary", "modern", "current", "present-day"],
        ["traditional", "conventional", "classic", "customary"],
        ["reliable", "dependable", "trustworthy"],
        ["suspicious", "doubtful", "questionable", "dubious"],
        ["marvelous", "wonderful", "magnificent", "splendid", "superb"],
        ["pleasant", "agreeable", "enjoyable", "delightful", "lovely", "nice"],
        ["unpleasant", "disagreeable", "nasty"],
        ["useful", "helpful", "practical", "handy", "beneficial"],
        ["useless", "worthless", "pointless", "futile"],
        ["precious", "valuable", "priceless", "treasured"],
        // More verbs from card data
        ["understand", "comprehend", "grasp", "get"],
        ["notice", "observe", "spot", "detect", "perceive"],
        ["recognize", "identify", "distinguish"],
        ["imagine", "envision", "picture", "visualize"],
        ["guess", "estimate", "speculate", "suppose"],
        ["suggest", "propose", "recommend", "advise"],
        ["demand", "insist", "require"],
        ["promise", "pledge", "vow", "swear"],
        ["warn", "caution", "alert"],
        ["convince", "persuade"],
        ["complain", "grumble", "protest"],
        ["praise", "compliment", "commend", "applaud"],
        ["criticize", "blame", "condemn", "denounce"],
        ["admit", "confess", "acknowledge", "concede"],
        ["deny", "refuse", "reject", "decline"],
        ["agree", "concur", "consent", "approve"],
        ["disagree", "differ", "object", "oppose"],
        ["argue", "debate", "dispute", "quarrel"],
        ["discuss", "talk about", "converse"],
        ["mention", "refer to", "note", "remark"],
        ["insist", "persist", "demand"],
        ["suppose", "assume", "presume", "guess"],
        ["expect", "anticipate", "await"],
        ["hope", "wish", "long for"],
        ["wonder", "ponder", "question", "speculate"],
        ["prefer", "favor", "choose"],
        ["ignore", "disregard", "overlook", "neglect"],
        ["obey", "follow", "comply"],
        ["resist", "oppose", "withstand", "defy"],
        ["avoid", "evade", "dodge", "shun"],
        ["escape", "flee", "run away"],
        ["chase", "pursue", "follow", "hunt"],
        ["invite", "summon", "call"],
        ["welcome", "greet", "receive"],
        ["introduce", "present"],
        ["accompany", "escort", "join"],
        ["abandon", "desert", "forsake", "leave"],
        ["rescue", "save", "recover", "retrieve"],
        ["steal", "rob", "take", "swipe"],
        ["borrow", "lend"],
        ["share", "distribute", "divide"],
        ["collect", "gather", "accumulate", "assemble"],
        ["arrange", "organize", "sort", "order"],
        ["prepare", "get ready", "set up"],
        ["manage", "handle", "deal with", "cope"],
        ["control", "direct", "govern", "regulate"],
        ["lead", "guide", "direct", "conduct"],
        ["follow", "pursue", "trail", "track"],
        ["move", "shift", "transfer", "relocate"],
        ["place", "put", "set", "position"],
        ["remove", "take away", "eliminate", "extract"],
        ["add", "include", "insert", "attach"],
        ["replace", "substitute", "swap", "exchange"],
        ["hang", "suspend", "dangle"],
        ["lean", "tilt", "incline"],
        ["climb", "ascend", "scale", "mount"],
        ["descend", "go down", "drop"],
        ["cross", "traverse", "pass"],
        ["enter", "go in", "come in"],
        ["exit", "go out", "leave", "depart"],
        ["pass", "go by", "proceed"],
        ["reach", "arrive at", "get to", "attain"],
        ["approach", "near", "come close"],
        ["touch", "feel", "handle", "contact"],
        ["hold", "grip", "grasp", "clutch"],
        ["drop", "release", "let go"],
        ["shake", "tremble", "shiver", "quake", "vibrate"],
        ["turn", "rotate", "spin", "revolve"],
        ["bend", "curve", "flex"],
        ["stretch", "extend", "expand"],
        ["squeeze", "compress", "press", "crush"],
        ["wrap", "cover", "envelop"],
        ["fold", "crease", "bend"],
        ["tie", "bind", "fasten", "secure"],
        ["untie", "loosen", "unfasten", "undo"],
        ["mark", "label", "tag", "stamp"],
        ["measure", "gauge", "assess", "evaluate"],
        ["weigh", "measure", "balance"],
        ["count", "tally", "enumerate"],
        ["calculate", "compute", "figure out", "work out"],
        ["solve", "resolve", "figure out", "work out"],
        ["check", "verify", "inspect", "examine"],
        ["test", "try", "examine", "assess"],
        ["prove", "demonstrate", "confirm", "verify"],
        ["earn", "make", "gain", "acquire"],
        ["spend", "use", "expend"],
        ["save", "preserve", "conserve", "keep"],
        ["waste", "squander"],
        ["owe", "be indebted"],
        ["pay", "compensate", "reimburse"],
        ["lend", "loan"],
        ["invest", "put in", "contribute"],
        ["succeed", "prosper", "thrive", "flourish"],
        ["struggle", "strive", "fight", "labor"],
        ["compete", "contend", "rival"],
        ["participate", "take part", "join in", "engage"],
        ["practice", "train", "rehearse", "drill"],
        ["perform", "execute", "carry out", "do"],
        ["finish", "complete", "conclude", "end", "wrap up"],
        ["continue", "proceed", "carry on", "go on", "keep going"],
        ["pause", "halt", "stop", "cease"],
        ["rest", "relax", "unwind"],
        ["hurry", "rush", "hasten", "speed up"],
        ["delay", "postpone", "defer", "put off"],
        ["plan", "design", "devise", "scheme"],
        ["develop", "evolve", "progress", "advance"],
        ["establish", "found", "set up", "create"],
        ["maintain", "preserve", "sustain", "uphold"],
        ["destroy", "demolish", "ruin", "wreck", "devastate"],
        ["harm", "damage", "injure", "hurt", "wound"],
        ["suffer", "endure", "bear", "undergo", "withstand"],
        ["recover", "heal", "improve", "get better"],
        ["survive", "endure", "outlast"],
        ["flourish", "thrive", "prosper", "bloom"],
        ["decline", "deteriorate", "worsen", "fade"],
        ["vanish", "disappear", "fade", "evaporate"],
        ["emerge", "appear", "arise", "surface"],
        ["spread", "extend", "expand", "stretch"],
        ["shrink", "contract", "reduce", "diminish"],
        ["fit", "suit", "match"],
        ["belong", "pertain", "relate"],
        ["depend", "rely", "count on"],
        ["influence", "affect", "impact", "sway"],
        ["inspire", "motivate", "encourage", "stimulate"],
        ["frighten", "scare", "terrify", "alarm", "startle"],
        ["calm", "soothe", "reassure", "comfort"],
        ["annoy", "irritate", "bother", "disturb"],
        ["bore", "tire", "weary"],
        ["amuse", "entertain", "delight"],
        ["satisfy", "please", "content", "gratify"],
        ["disappoint", "let down", "dishearten"],
        ["confuse", "puzzle", "bewilder", "perplex", "baffle"],
        ["convince", "persuade", "sway"],
        ["deceive", "trick", "fool", "mislead"],
        ["betray", "double-cross"],
        ["forgive", "pardon", "excuse", "absolve"],
        ["respect", "admire", "esteem", "honor"],
        ["envy", "covet", "begrudge"],
        // More nouns from card data
        ["trash", "garbage", "rubbish", "waste", "junk", "litter"],
        ["mistake", "error", "blunder", "fault", "slip"],
        ["idea", "thought", "concept", "notion"],
        ["goal", "aim", "objective", "target", "purpose"],
        ["rule", "regulation", "law", "guideline"],
        ["price", "cost", "value", "worth", "charge", "fee"],
        ["noise", "sound", "racket", "din"],
        ["speech", "address", "talk", "lecture", "presentation"],
        ["gift", "present", "offering"],
        ["border", "boundary", "frontier", "edge", "limit"],
        ["center", "middle", "core", "heart"],
        ["piece", "part", "portion", "fragment", "bit", "section"],
        ["group", "team", "band", "crew", "squad"],
        ["picture", "image", "photo", "photograph"],
        ["clothes", "clothing", "garments", "attire", "outfit"],
        ["trip", "journey", "voyage", "excursion", "expedition"],
        ["luck", "fortune", "chance", "fate"],
        ["danger", "threat", "hazard", "risk", "peril"],
        ["victory", "triumph", "win", "success"],
        ["defeat", "loss", "failure"],
        ["strength", "power", "force", "might", "energy"],
        ["weakness", "flaw", "frailty", "vulnerability"],
        ["freedom", "liberty", "independence"],
        ["peace", "harmony", "tranquility", "serenity"],
        ["war", "conflict", "battle", "warfare", "combat"],
        ["fear", "dread", "terror", "fright", "anxiety"],
        ["joy", "happiness", "delight", "bliss", "pleasure", "elation"],
        ["anger", "rage", "fury", "wrath"],
        ["sorrow", "grief", "sadness", "mourning"],
        ["love", "affection", "devotion", "fondness"],
        ["hatred", "hate", "loathing", "hostility"],
        ["trust", "faith", "confidence", "belief"],
        ["doubt", "uncertainty", "suspicion", "skepticism"],
        ["knowledge", "wisdom", "understanding", "insight"],
        ["ignorance", "unawareness"],
        ["truth", "fact", "reality", "actuality"],
        ["lie", "falsehood", "untruth", "deception"],
        ["opinion", "view", "perspective", "standpoint", "belief"],
        ["skill", "ability", "talent", "aptitude", "competence"],
        ["effort", "attempt", "endeavor", "exertion"],
        ["result", "outcome", "consequence", "effect"],
        ["reason", "cause", "motive", "rationale", "grounds"],
        ["problem", "issue", "difficulty", "trouble", "challenge"],
        ["solution", "answer", "remedy", "resolution", "fix"],
        ["method", "way", "approach", "technique", "procedure"],
        ["example", "instance", "sample", "illustration", "case"],
        ["difference", "distinction", "contrast", "variation"],
        ["similarity", "resemblance", "likeness"],
        ["advantage", "benefit", "asset", "merit"],
        ["disadvantage", "drawback", "downside", "shortcoming"],
        ["opportunity", "chance", "opening", "prospect"],
        ["obstacle", "barrier", "hurdle", "hindrance"],
        ["permission", "consent", "approval", "authorization"],
        ["habit", "routine", "custom", "practice"],
        ["choice", "option", "alternative", "selection"],
        ["behavior", "conduct", "manner", "attitude"],
        ["duty", "obligation", "responsibility", "task"],
        ["desire", "wish", "longing", "craving", "yearning"],
        ["memory", "recollection", "remembrance"],
        ["dream", "vision", "fantasy", "aspiration"],
        ["secret", "mystery", "enigma"],
        ["wealth", "riches", "fortune", "prosperity"],
        ["poverty", "destitution", "hardship"],
        ["disease", "illness", "sickness", "ailment", "malady"],
        ["health", "wellness", "well-being", "fitness"],
        ["pain", "ache", "hurt", "suffering", "agony", "discomfort"],
        ["pleasure", "enjoyment", "delight", "satisfaction"],
        ["comfort", "ease", "relief", "solace"],
        ["silence", "quiet", "stillness", "hush"],
        ["crowd", "mob", "throng", "multitude"],
        ["edge", "rim", "brink", "verge", "margin"],
        ["surface", "exterior", "outside", "face"],
        ["bottom", "base", "foundation", "floor"],
        ["top", "summit", "peak", "apex", "pinnacle"],
        ["beginning", "start", "onset", "commencement", "origin"],
        ["ending", "conclusion", "finish", "finale", "termination"],
        // Numbers
        ["0", "zero"],
        ["1", "one"],
        ["2", "two"],
        ["3", "three"],
        ["4", "four"],
        ["5", "five"],
        ["6", "six"],
        ["7", "seven"],
        ["8", "eight"],
        ["9", "nine"],
        ["10", "ten"],
        ["11", "eleven"],
        ["12", "twelve"],
        ["13", "thirteen"],
        ["14", "fourteen"],
        ["15", "fifteen"],
        ["16", "sixteen"],
        ["17", "seventeen"],
        ["18", "eighteen"],
        ["19", "nineteen"],
        ["20", "twenty"],
        ["30", "thirty"],
        ["40", "forty"],
        ["50", "fifty"],
        ["60", "sixty"],
        ["70", "seventy"],
        ["80", "eighty"],
        ["90", "ninety"],
        ["100", "hundred", "one hundred", "a hundred"],
        ["1000", "thousand", "one thousand", "a thousand"],
        ["1000000", "million", "one million", "a million"],
    ]

    // Build a lookup from any word to its full synonym group (computed once)
    private static let synonymLookup: [String: Set<String>] = {
        var lookup: [String: Set<String>] = [:]
        for group in synonymGroups {
            let groupSet = Set(group)
            for word in group {
                lookup[word] = groupSet
            }
        }
        return lookup
    }()

    private func addVariants(of text: String, to set: inout Set<String>) {
        let n = normalize(text)
        set.insert(n)

        // Strip "to " prefix for verbs
        if n.hasPrefix("to ") {
            set.insert(String(n.dropFirst(3)))
        }
        // Strip "a/an/the " prefix
        for prefix in ["a ", "an ", "the "] {
            if n.hasPrefix(prefix) { set.insert(String(n.dropFirst(prefix.count))) }
        }

        // Strip parenthetical like "(informal)", "(m.)", "(wa)"
        let stripped = normalize(text.replacingOccurrences(of: "\\s*\\(.*?\\)", with: "", options: .regularExpression))
        set.insert(stripped)
        if stripped.hasPrefix("to ") { set.insert(String(stripped.dropFirst(3))) }
        for prefix in ["a ", "an ", "the "] {
            if stripped.hasPrefix(prefix) { set.insert(String(stripped.dropFirst(prefix.count))) }
        }

        // Add all synonyms from the same group
        let snapshot = set
        for word in snapshot {
            if let group = Self.synonymLookup[word] {
                set.formUnion(group)
            }
        }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    func revealAnswer() {
        guard !answerSubmitted else { return }
        answerSubmitted = true
        answerCorrect = false
        guard let card = currentCard else { return }
        if typingMode {
            card.typingIncorrectCount += 1
        } else {
            card.incorrectCount += 1
        }
        card.lastReviewedAt = Date()
        incorrectCount += 1
        incorrectCards.append(card)
        cardResults[currentIndex] = false
        haptic(.error)
    }

    func typingNextCard() {
        advance()
    }

    private func resetCardState() {
        isFlipped = false
        cardRotation = 0

        if let previousResult = cardResults[currentIndex], typingMode {
            // Typing mode: show the previous result, don't allow re-answering
            answerSubmitted = true
            answerCorrect = previousResult
            typedAnswer = cardTypedAnswers[currentIndex] ?? ""
        } else {
            // Flashcard mode or unanswered card: allow answering
            typedAnswer = ""
            answerSubmitted = false
            answerCorrect = false
        }
    }

    private func haptic(_ type: HapticType) {
        switch type {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    enum HapticType { case success, error, light }

    var percentage: Int {
        guard !shuffledCards.isEmpty else { return 0 }
        return Int(Double(correctCount) / Double(shuffledCards.count) * 100)
    }
}

// MARK: - Study Session View

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var session: StudySession
    @State private var showingReStudy = false
    @State private var dragOffset: CGFloat = 0
    @State private var typedText = ""
    let isRestudy: Bool
    @Binding var isPresented: Bool

    init(deck: Deck, specificCards: [Flashcard]? = nil, reverseMode: Bool = false, typingMode: Bool = false, shuffleMode: Bool = true, isRestudy: Bool = false, isPresented: Binding<Bool> = .constant(true)) {
        self.isRestudy = isRestudy
        self._isPresented = isPresented
        let session = StudySession(deck: deck, specificCards: specificCards, reverseMode: reverseMode, typingMode: typingMode, shuffleMode: shuffleMode, isRestudy: isRestudy)
        // Resume from saved position if available (not for re-study)
        if !isRestudy,
           let savedIdx = StudySession.savedIndex(for: deck.name, typingMode: typingMode),
           savedIdx < session.shuffledCards.count {
            // Restore the saved card order so we resume with the same shuffle
            if let savedOrder = StudySession.savedCardOrder(for: deck.name, typingMode: typingMode) {
                let cardLookup = Dictionary(uniqueKeysWithValues: session.shuffledCards.map { ($0.front, $0) })
                let restored = savedOrder.compactMap { cardLookup[$0] }
                if restored.count == session.shuffledCards.count {
                    session.shuffledCards = restored
                }
            }
            session.currentIndex = savedIdx
            session.furthestIndex = savedIdx
        }
        _session = State(initialValue: session)
    }

    var body: some View {
        NavigationStack {
            if session.showingResults {
                resultsView
            } else if session.shuffledCards.isEmpty {
                ContentUnavailableView("No Cards", systemImage: "rectangle.slash")
            } else {
                studyView
            }
        }
    }

    // MARK: - Study View

    private var studyView: some View {
        VStack(spacing: 0) {
            studyHeader
                .padding(.bottom, 8)

            if session.typingMode {
                typingArea
                    .frame(maxHeight: .infinity)
            } else {
                cardArea
                    .frame(maxHeight: .infinity)

                Text("Tap to flip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                actionButtons
            }
        }
        .navigationTitle(session.deck.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Quit") {
                    if !isRestudy { session.saveProgress() }
                    dismiss()
                }
            }
        }
    }

    private var studyHeader: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(session.currentIndex + 1) / \(session.shuffledCards.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Label("\(session.correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Label("\(session.incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
            .padding(.horizontal)

            ProgressView(value: Double(session.currentIndex), total: Double(session.shuffledCards.count))
                .tint(.indigo)
                .padding(.horizontal)
        }
    }

    private var cardArea: some View {
        ZStack {
            cardBack
            cardFront
        }
        .offset(x: dragOffset)
        .rotationEffect(.degrees(dragOffset / 30))
        .gesture(dragGesture)
    }

    private var cardFront: some View {
        let card = session.currentCard
        let subtitle = session.reverseMode ? "English" : (card?.rank ?? 0 > 0 ? "#\(card?.rank ?? 0)" : "Word")
        return StudyCardFace(
            text: session.displayFront,
            subtitle: subtitle,
            color: session.reverseMode ? .blue : .indigo,
            speakLanguage: session.reverseMode ? "en-US" : session.languageCode
        )
        .rotation3DEffect(.degrees(session.cardRotation), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(session.cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 0 : 1)
    }

    private var cardBack: some View {
        StudyCardFace(
            text: session.displayBack,
            subtitle: session.reverseMode ? "#\(session.currentCard?.rank ?? 0)" : "Answer",
            color: session.reverseMode ? .indigo : .blue,
            speakLanguage: session.reverseMode ? session.languageCode : "en-US",
            example: session.currentCard?.example ?? ""
        )
        .rotation3DEffect(.degrees(session.cardRotation + 180), axis: (x: 0, y: 1, z: 0))
        .opacity(abs(session.cardRotation.truncatingRemainder(dividingBy: 360)) > 90 ? 1 : 0)
    }

    // MARK: - Typing Mode

    @FocusState private var typingFocused: Bool

    private var typingArea: some View {
        VStack(spacing: 0) {
            // Card prompt
            VStack(spacing: 10) {
                Text(session.reverseMode ? "TRANSLATE TO" : "#\(session.currentCard?.rank ?? 0)")
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.7))
                    .tracking(1)

                Text(session.displayFront)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .padding(.horizontal, 20)

                Button {
                    let lang = session.reverseMode ? "en-US" : session.languageCode
                    SpeechHelper.shared.speak(session.displayFront, languageCode: lang)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(8)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill((session.reverseMode ? Color.blue : Color.indigo).gradient)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer().frame(height: 20)

            // Answer area
            if session.answerSubmitted {
                typingResultFeedback
            } else {
                typingInputField
            }

            Spacer()

            // Bottom actions
            if !session.answerSubmitted {
                HStack(spacing: 28) {
                    if session.canGoBack {
                        Button {
                            session.goBack()
                            typingFocused = true
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    Button {
                        session.revealAnswer()
                    } label: {
                        Label("Reveal", systemImage: "eye")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    Button {
                        session.typingNextCard()
                        typedText = ""
                        typingFocused = true
                    } label: {
                        Label("Skip", systemImage: "forward.fill")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.bottom, 20)
            } else if session.isReviewingPastCard && session.canGoBack {
                HStack(spacing: 28) {
                    Button {
                        session.goBack()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.bottom, 20)
            } else {
                Color.clear.frame(height: 48)
            }
        }
        .onAppear { typingFocused = true }
    }

    private var typingInputField: some View {
        VStack(spacing: 14) {
            TextField("Your answer...", text: $typedText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($typingFocused)
                .onSubmit {
                    if !typedText.isEmpty {
                        session.typedAnswer = typedText
                        session.submitTypedAnswer()
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 24)

            Button {
                session.typedAnswer = typedText
                session.submitTypedAnswer()
            } label: {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(typedText.isEmpty ? Color(.systemGray4) : .indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(typedText.isEmpty)
            .padding(.horizontal, 24)
        }
    }

    private var typingResultFeedback: some View {
        VStack(spacing: 16) {
            // Result badge
            VStack(spacing: 8) {
                Image(systemName: session.answerCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(session.answerCorrect ? .green : .orange)

                if session.answerCorrect {
                    Text("Correct!")
                        .font(.headline)
                        .foregroundStyle(.green)
                    Text(session.displayBack)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    if !session.typedAnswer.isEmpty {
                        Text(session.typedAnswer)
                            .font(.body)
                            .strikethrough()
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    Text(session.displayBack)
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                }

                if let example = session.currentCard?.example, !example.isEmpty {
                    Text(example)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(session.answerCorrect ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
            )
            .padding(.horizontal, 24)

            Button {
                session.typingNextCard()
                typedText = ""
                typingFocused = true
            } label: {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(session.answerCorrect ? .green : .indigo)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Gesture

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let dx = value.translation.width
                if abs(dx) > 10 {
                    dragOffset = dx
                }
            }
            .onEnded { value in
                let dx = value.translation.width

                if abs(dx) <= 10 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        session.flipCard()
                    }
                } else if dx > 80 && session.canGoBack {
                    session.goBack()
                } else if dx < -80 && session.canGoForward {
                    session.goForward()
                }

                withAnimation(.spring()) {
                    dragOffset = 0
                }
            }
    }

    // MARK: - Buttons

    private var actionButtons: some View {
        HStack {
            Button { session.markIncorrect() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 52))
                    Text("Don't Know")
                        .font(.caption2)
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
            }

            Button { session.markCorrect() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                    Text("Know It")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 16)
    }

    // MARK: - Results View

    private var resultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                resultsSummaryHeader
                resultsStatsCard

                if !session.incorrectCards.isEmpty && !isRestudy {
                    reStudyButton
                }

                if !session.incorrectCards.isEmpty {
                    resultsSection(title: session.typingMode ? "Incorrect" : "Weak", icon: "xmark.circle.fill", color: .red, cards: session.incorrectCards)
                }

                if !session.correctCards.isEmpty {
                    resultsSection(title: session.typingMode ? "Correct" : "Mastered", icon: "checkmark.circle.fill", color: .green, cards: session.correctCards)
                }

                doneButton
            }
            .padding()
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingReStudy, onDismiss: mergeRestudyResults) {
            StudySessionView(deck: session.deck, specificCards: session.incorrectCards, reverseMode: session.reverseMode, isRestudy: true)
        }
        .onAppear {
            guard !isRestudy else { return }
            UserDefaults.standard.set(Date(), forKey: "lastStudyDate")
            updateStreak()
            saveLastSessionResults()
        }
    }

    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastStreak = UserDefaults.standard.integer(forKey: "currentStreak")
        let lastDateRaw = UserDefaults.standard.object(forKey: "streakDate") as? Date
        let lastDate = lastDateRaw.map { calendar.startOfDay(for: $0) }

        if let last = lastDate {
            let diff = calendar.dateComponents([.day], from: last, to: today).day ?? 0
            if diff == 0 {
                // Already studied today
            } else if diff == 1 {
                UserDefaults.standard.set(lastStreak + 1, forKey: "currentStreak")
            } else {
                UserDefaults.standard.set(1, forKey: "currentStreak")
            }
        } else {
            UserDefaults.standard.set(1, forKey: "currentStreak")
        }
        UserDefaults.standard.set(today, forKey: "streakDate")
    }

    private func saveLastSessionResults() {
        let key = "lastSession_\(session.deck.name)_\(session.typingMode ? "type" : "flash")"
        let data: [String: Any] = [
            "date": Date(),
            "correct": session.correctCount,
            "incorrect": session.incorrectCount,
            "total": session.shuffledCards.count,
            "typingMode": session.typingMode
        ]
        UserDefaults.standard.set(data, forKey: key)

        // Archive session history
        SessionHistory.save(
            deckName: session.deck.name,
            typingMode: session.typingMode,
            correct: session.correctCount,
            incorrect: session.incorrectCount,
            total: session.shuffledCards.count,
            correctWords: session.correctCards.map { WordResult(front: $0.front, back: $0.back) },
            incorrectWords: session.incorrectCards.map { WordResult(front: $0.front, back: $0.back) }
        )
    }

    private func mergeRestudyResults() {
        // Cards that were in incorrectCards but now have higher correct counts were answered correctly in re-study
        let stillIncorrect = session.incorrectCards.filter { card in
            if session.typingMode {
                return card.typingIncorrectCount > card.typingCorrectCount
            } else {
                return card.incorrectCount > card.correctCount
            }
        }
        let nowCorrect = session.incorrectCards.filter { card in
            !stillIncorrect.contains(where: { $0.id == card.id })
        }

        // Move corrected cards
        session.correctCards.append(contentsOf: nowCorrect)
        session.correctCount += nowCorrect.count
        session.incorrectCards = stillIncorrect
        session.incorrectCount = stillIncorrect.count

        // Re-save history with merged results (delete old, save new)
        if !isRestudy {
            // Find and delete the most recent history entry for this deck+mode
            let records = SessionHistory.records(for: session.deck.name)
            if let latest = records.first {
                SessionHistory.delete(id: latest.id)
            }
            saveLastSessionResults()
        }
    }

    private var resultsSummaryHeader: some View {
        let p = session.percentage
        let icon = p >= 80 ? "star.fill" : p >= 50 ? "hand.thumbsup.fill" : "arrow.clockwise"
        let iconColor: Color = p >= 80 ? .yellow : p >= 50 ? .blue : .orange
        let message = p >= 80 ? "Great Job!" : p >= 50 ? "Good Effort!" : "Keep Practicing!"

        return VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(iconColor)
            Text(message)
                .font(.title.bold())
            Text(session.deck.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var resultsStatsCard: some View {
        VStack(spacing: 12) {
            ResultRow(label: "Total", value: "\(session.shuffledCards.count) cards", color: .primary)
            ResultRow(label: session.typingMode ? "Correct" : "Mastered", value: "\(session.correctCount)", color: .green)
            ResultRow(label: session.typingMode ? "Incorrect" : "Weak", value: "\(session.incorrectCount)", color: .red)
            ResultRow(label: "Accuracy", value: "\(session.percentage)%", color: .indigo)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var reStudyButton: some View {
        Button { showingReStudy = true } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                Text("Re-study \(session.incorrectCards.count) \(session.typingMode ? "Mistakes" : "Weak Cards")")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.red.opacity(0.12))
            .foregroundStyle(.red)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func resultsSection(title: String, icon: String, color: Color, cards: [Flashcard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title) (\(cards.count))", systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.offset) { _, card in
                    ResultCardRow(card: card, languageCode: session.languageCode)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var doneButton: some View {
        Button {
            if !isRestudy {
                StudySession.clearSavedSession(for: session.deck.name, typingMode: session.typingMode)
                for card in session.deck.cards {
                    if session.typingMode {
                        card.typingCorrectCount = 0
                        card.typingIncorrectCount = 0
                    } else {
                        card.correctCount = 0
                        card.incorrectCount = 0
                    }
                }
            }
            if isRestudy {
                dismiss()
            } else {
                isPresented = false
            }
        } label: {
            Text("Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.indigo)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.top, 8)
    }
}

// MARK: - Supporting Views

struct StudyCardFace: View {
    let text: String
    let subtitle: String
    let color: Color
    let speakLanguage: String?
    var example: String = ""

    var body: some View {
        VStack(spacing: 10) {
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1)

            Text(text)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 20)

            if !example.isEmpty {
                Text(example)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }

            if let lang = speakLanguage {
                Button {
                    SpeechHelper.shared.speak(text, languageCode: lang)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(10)
                        .background(.white.opacity(0.15), in: Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 320)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(color.gradient)
                .shadow(color: color.opacity(0.3), radius: 12, y: 6)
        )
        .padding(.horizontal)
    }
}

struct ResultCardRow: View {
    let card: Flashcard
    let languageCode: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.front)
                    .font(.body.bold())
                Text(card.back)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                SpeechHelper.shared.speak(card.front, languageCode: languageCode)
            } label: {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundStyle(.tint)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct ResultRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
    }
}

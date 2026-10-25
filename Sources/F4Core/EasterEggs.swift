import Foundation

/// Something special typed in the search field: a line from Boris, The Office
/// or millennial internet culture, with a banner and an effect on the grid.
///
/// F4 is named after the *F4, basito* face from Boris, so it should know
/// a few lines.
public struct EasterEgg: Equatable, Sendable {
    /// What happens to the grid while the egg is active.
    public enum Effect: Equatable, Sendable {
        /// Only the banner.
        case none
        /// The basito face above the results.
        case basito
        /// René: "Dai dai dai!". Select a random meme.
        case randomPick
        /// René: "Apri tutto, smarmella!". Overexpose every thumbnail.
        case smarmella
        /// Show only the favourites.
        case favouritesOnly
        /// Shuffle the whole grid.
        case shuffle
        /// Spin the panel once.
        case barrelRoll
        /// Make the thumbnails hop.
        case parkour
        /// Konami code: rainbow thumbnails.
        case rainbow
    }

    public let banner: String
    public let effect: Effect
    /// When true the grid shows every meme instead of the (empty) fuzzy results.
    public let showsAllMemes: Bool

    public init(banner: String, effect: Effect = .none, showsAllMemes: Bool = true) {
        self.banner = banner
        self.effect = effect
        self.showsAllMemes = showsAllMemes
    }
}

public enum EasterEggs {
    /// The egg for a search query, if it is one. Case, accents, punctuation
    /// and extra spaces are ignored, so "Dai, dai, DAI!" works.
    public static func match(_ query: String) -> EasterEgg? {
        let key = normalized(query)
        guard !key.isEmpty else { return nil }
        return table[key]
    }

    /// The Konami code: ↑ ↑ ↓ ↓ ← → ← → B A.
    public static let konami = EasterEgg(banner: "↑↑↓↓←→←→BA · +30 vite", effect: .rainbow)

    static func normalized(_ string: String) -> String {
        let folded = string.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(words).split(separator: " ").joined(separator: " ")
    }

    private static let table: [String: EasterEgg] = {
        var table: [String: EasterEgg] = [:]
        func add(_ keys: [String], _ egg: EasterEgg) {
            for key in keys { table[normalized(key)] = egg }
        }
        // Boris
        add(["f4", "basito", "f4 basito"], EasterEgg(banner: "F4. Basito.", effect: .basito, showsAllMemes: false))
        add(["dai dai dai", "daidaidai"], EasterEgg(banner: "Dai dai dai!", effect: .randomPick))
        add(["smarmella", "smarmellare", "apri tutto"], EasterEgg(banner: "Apri tutto! Smarmella!", effect: .smarmella))
        add(["occhi del cuore", "gli occhi del cuore"], EasterEgg(banner: "Gli occhi del cuore ❤️", effect: .favouritesOnly))
        add(["a cazzo di cane"], EasterEgg(banner: "Facciamola a cazzo di cane, tanto la gente non capisce.", effect: .shuffle))
        add(["cagna maledetta"], EasterEgg(banner: "Cagna maledetta! 🐕"))
        add(["qualita", "la qualita"], EasterEgg(banner: "La qualità? Ci ha rotto il ca**o, la qualità."))
        add(["duccio", "occhiali"], EasterEgg(banner: "Duccio, apri tutto. E ridammi gli occhiali."))
        add(["locura", "la locura"], EasterEgg(banner: "¡Qué locura! 🎬"))
        // The Office
        add(["thats what she said", "that s what she said", "twss"], EasterEgg(banner: "That's what she said! 😏"))
        add(["bears beets battlestar galactica", "bears beets"], EasterEgg(banner: "Bears. Beets. Battlestar Galactica. 🐻"))
        add(["identity theft"], EasterEgg(banner: "Identity theft is not a joke, Jim! Millions of families suffer every year."))
        add(["parkour"], EasterEgg(banner: "PARKOUR! 🤸", effect: .parkour))
        add(["no god no", "no god please no"], EasterEgg(banner: "No, God! No, God, please, no! No! Nooooooo!"))
        add(["dunder mifflin"], EasterEgg(banner: "Dunder Mifflin, this is Pam."))
        // Millennial internet
        add(["do a barrel roll", "barrel roll"], EasterEgg(banner: "Do a barrel roll! 🛩️", effect: .barrelRoll))
        add(["hello there"], EasterEgg(banner: "General Kenobi! 🗡️"))
        add(["over 9000", "its over 9000", "9000"], EasterEgg(banner: "It's over 9000!!! 💥"))
        add(["never gonna give you up", "rickroll", "rick roll"], EasterEgg(banner: "Never gonna give you up, never gonna let you down 🎶"))
        add(["all your base", "all your base are belong to us"], EasterEgg(banner: "All your base are belong to us."))
        add(["this is fine"], EasterEgg(banner: "This is fine. 🔥☕", showsAllMemes: false))
        add(["42"], EasterEgg(banner: "42. Ma qual era la domanda? 🐬", showsAllMemes: false))
        return table
    }()
}

/// Recognises the Konami code in a stream of key presses.
public struct KonamiCode: Sendable {
    public enum Key: Equatable, Sendable {
        case up, down, left, right, b, a, other
    }

    private static let sequence: [Key] = [.up, .up, .down, .down, .left, .right, .left, .right, .b, .a]
    private var recent: [Key] = []

    public init() {}

    /// Feeds one key press. Returns true when it completes the code. Extra or
    /// wrong keys before it do not matter: only the last ten presses count.
    public mutating func feed(_ key: Key) -> Bool {
        recent.append(key)
        if recent.count > Self.sequence.count { recent.removeFirst() }
        guard recent == Self.sequence else { return false }
        recent.removeAll()
        return true
    }
}

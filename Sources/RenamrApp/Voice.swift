import Foundation

/// Renamr's voice.
///
/// Character: a calm, sharp-eyed pattern-spotter with dry wit. It has seen every
/// cursed Downloads folder and is unfazed. Speaks in the first person ("I"),
/// briefly, and is quietly reassuring about safety — because renaming files is
/// scary and trust is the whole product. A little character, never a clown.
///
/// Split of responsibility: event strings (status messages, set once per action
/// and stored) may use variety via `pick`; persistent on-screen labels are fixed
/// constants so the UI doesn't reshuffle words on every redraw.
enum Voice {
    private static func pick(_ options: [String]) -> String { options.randomElement() ?? options[0] }

    // Fixed labels (stable across redraws)
    static let tagline = "rename by example"
    static let emptyTitle = "Show me one. I'll do the rest."
    static let emptySubtitle = "Fix a single filename — I'll spot the pattern and rename the whole folder."
    static let teachHeaderFirst = "Rename one — I'll learn the pattern"
    static let teachHeaderMore = "Fix another, if I got one wrong"
    static let pickPrompt = "Pick a file on the left, then type what it should be called."
    static let ambiguityTitle = "Two ways to read that."
    static let finderTip = "Tip: right-click files in Finder ▸ Rename by Example"
    static let safety = "I only rename the ones I'm sure about."

    // Event strings (set once, stored — variety is fine here)
    static func loaded(_ n: Int) -> String {
        guard n > 0 else { return "Empty folder. Nothing for me here." }
        return pick([
            "\(n) files. Rename one — I'll spot the pattern.",
            "\(n) files. Fix one name; I'll take the rest.",
            "\(n) files. Show me how one should look.",
        ])
    }

    static func applied(_ n: Int, skipped: Int) -> String {
        let tail = skipped > 0 ? " Skipped \(skipped) — name clash, I won't clobber." : ""
        switch n {
        case 0: return "Nothing changed." + tail
        case 1: return "Renamed one. Tidy." + tail
        default: return pick(["Renamed \(n). Tidy.", "\(n) sorted. Look at that.", "Done — \(n) renamed."]) + tail
        }
    }

    static func undone(_ n: Int) -> String {
        guard n > 0 else { return "Nothing to undo." }
        return pick(["Put \(n) back. No harm done.", "Reverted \(n). As you were."])
    }

    static let startedOver = "Clean slate. Rename one to begin."
}

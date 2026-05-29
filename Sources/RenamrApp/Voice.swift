import Foundation

/// Sprig's voice — Renamr's mascot. Warm, friendly, and a little eager, but
/// never noisy or cutesy-to-a-fault. The character carries the charm; the copy
/// stays clean and confident, and quietly reassuring about safety.
///
/// Event strings (status, set once) may vary via `pick`; on-screen labels are
/// fixed constants so the UI never reshuffles words on redraw.
enum Voice {
    static let mascotName = "Sprig"

    private static func pick(_ options: [String]) -> String { options.randomElement() ?? options[0] }

    static let tagline = "rename by example"
    static let emptyTitle = "Show me one, I'll do the rest."
    static let emptySubtitle = "Rename a single file the way you want it — I'll spot the pattern and tidy the whole folder."
    static let teachHeaderFirst = "Rename one — I'll learn the pattern"
    static let teachHeaderMore = "Fix another, if I got one wrong"
    static let pickPrompt = "Pick a file, then type its new name."
    static let ambiguityTitle = "Hmm, two ways to read that."
    static let finderTip = "Tip: right-click files in Finder ▸ Rename by Example"
    static let safety = "I only rename the ones I'm sure about."

    static func loaded(files: Int, folders: Int) -> String {
        if files == 0 && folders > 0 { return folders == 1 ? "One folder inside — pop in." : "\(folders) folders inside — pick one." }
        if files == 0 { return "Nothing here. Try another folder." }
        return pick([
            "\(files) files. Rename one — I'll do the rest.",
            "\(files) files. Show me how one should look.",
            "\(files) files. Fix one, I'll take care of the rest.",
        ])
    }

    static func applied(_ n: Int, skipped: Int) -> String {
        let tail = skipped > 0 ? " (skipped \(skipped) — name clash, I won't clobber)" : ""
        switch n {
        case 0: return "Nothing changed." + tail
        case 1: return "Renamed one. All tidy!" + tail
        default: return pick(["Renamed \(n). All tidy!", "There — \(n) sorted.", "Done! \(n) renamed."]) + tail
        }
    }

    static func undone(_ n: Int) -> String {
        n > 0 ? pick(["Popped \(n) back. No harm done.", "Reverted \(n). As you were."]) : "Nothing to undo."
    }

    static let startedOver = "Fresh start. Rename one to begin."
}

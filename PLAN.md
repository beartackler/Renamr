# Renamr — build plan

Goal: a free, open-source, **native macOS** app that renames a folder by one example, with a genuinely hard programming-by-example (PBE) engine as the moat and a painfully simple surface. Local-only, `.dmg` download, one-page landing site.

The moat is **execution quality**, not idea novelty (StringSolver proves the interaction exists but is a GPL Scala CLI; Microsoft PROSE/FlashFill is non-commercial/.NET). So depth and reliability of the synthesizer are the bet.

## Milestone 1 — Engine core ✅ (in progress, foundation done)
- [x] Typed tokenizer (date / number / word / separator) with multi-format date recognition
- [x] Program model (copy + re-case, date-reformat, number-repad, literal) with structural `(kind, ordinal)` references
- [x] Single-example synthesizer with a simplicity-prior cost model
- [x] Apply across a folder; flag (never mangle) files missing referenced fields
- [x] Test suite covering the headline cases (algorithm validated)

## Milestone 2 — Engine reliability (the hard 20%, ~3–4 mo)
- [ ] **Version-space algebra** search (replace the greedy per-token pick) so multiple candidate programs are represented compactly and ranked
- [ ] **Disambiguation-by-disagreement loop** — run top candidate programs across the folder, surface the maximally-disagreeing file, ask for a *second* example there (highest-information query)
- [ ] **Multi-example synthesis** — intersect version spaces across examples instead of verify-only
- [ ] Date ambiguity resolution (01/02 = Jan-2 vs Feb-1) via locale prior + cross-file agreement
- [ ] Counter **resequencing** (1..N) in addition to repad/strip; alpha-prefix counters
- [ ] Broaden token coverage: RAW sidecars, episode/season numbering, invoice IDs, camelCase/snake/kebab boundaries
- [ ] Reliability corpus: a large set of real messy folders to push "it just knew" from ~80% → ~98%

## Milestone 3 — The app (AppKit + SwiftUI, ~3–4 wk)
- [ ] Drag-files / drop-folder window; SwiftUI chrome
- [ ] Live **preview table** with per-row diff highlighting and uncertainty flags
- [ ] Edit-one-cell-to-add-an-example interaction; show "needs a 2nd example" rows
- [ ] Atomic rename with collision detection + **undo**
- [ ] Folder bookmarks / security-scoped access (non-sandboxed direct build)

## Milestone 4 — Ship for $0 (no Apple Developer Program)
Decision (2026-05-29): ship free. The $99/yr only deletes a *one-time* first-launch
dialog, so defer it until a trigger fires (below). Verified against current macOS 15
Sequoia / 26 Tahoe.
- [x] Ad-hoc sign the bundle (`codesign --force --sign - Renamr.app`) — REQUIRED so Apple Silicon launches it at all (kernel SIGKILLs zero-signature arm64). `package-app.sh` does this.
- [ ] `.dmg` via create-dmg, hosted free on **GitHub Releases** (primary).
- [ ] README **"First launch"** section, current flow: open once → System Settings ▸ Privacy & Security ▸ **Open Anyway** ▸ authenticate (move to /Applications first; entry expires ~1h; right-click→Open is DEAD since Sequoia — do NOT document it). Plus power-user one-liner: `xattr -dr com.apple.quarantine /Applications/Renamr.app`.
- [ ] **Homebrew FORMULA (build-from-source)**, NOT a cask — locally compiled = ad-hoc signed, no quarantine ⇒ zero Gatekeeper friction. (Cask is off the table: quarantined by default, `--no-quarantine` deprecated in Homebrew 5.0.0, official tap disables un-notarized casks 2026-09-01.)
- [ ] One-page landing site (demo GIF hero) on the cheap VPS; download → GitHub Releases.
- [ ] Auto-update: **hold on Sparkle** — each update re-quarantines (re-triggers the dialog), which only notarization fixes; rely on `brew upgrade` / manual re-download until/unless we notarize.

### Pay the $99 only when a trigger fires
Non-technical users repeatedly report "damaged / can't open"; OR ~1k+ downloads / an HN-front-page moment where the next, less-technical wave should convert; OR you add Sparkle auto-update; OR donations/sponsors exceed $99/yr (the OBS/HandBrake graduation path). Until then, $0.

## Milestone 5 — Distribution
- [ ] Launch: Show HN + r/macapps + Product Hunt, same day, leading with the demo GIF
- [ ] PRs to awesome-mac / awesome-macos
- [ ] The CLI companion (`renamr`) for power users / scriptability

## Known environment note
The dev machine's Command Line Tools are currently in a broken state (duplicate `SwiftBridging` module map + SDK/compiler version skew), so `swift build`/`swift test` fail locally on *any* package. Fix by installing full **Xcode** (also needed for the app target + notarization) or reinstalling CLT:
```sh
sudo rm -rf /Library/Developer/CommandLineTools && sudo xcode-select --install
```
The engine algorithm was validated independently in the meantime; the Swift sources are written against Swift 6 / tools-version 6.0.

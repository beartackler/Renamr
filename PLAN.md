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
- [x] **Disambiguation-by-disagreement loop** — keep competing candidate programs (primary + one single-flip variant per ambiguous field), find the file where they disagree most, ask for a second example there (`SynthesisResult.needsMoreInfo`). Tested.
- [x] **Multi-example synthesis (v1)** — synthesize candidates from the first example, keep only those consistent with all examples; a second example collapses the ambiguity. Tested.
- [ ] **Full version-space algebra** — currently single-flip variants, not a compact full VSA; upgrade for deeper/compound ambiguities and combinatorial fields
- [ ] Date ambiguity resolution (01/02 = Jan-2 vs Feb-1) via locale prior + cross-file agreement
- [ ] Counter **resequencing** (1..N) in addition to repad/strip; alpha-prefix counters
- [ ] Broaden token coverage: RAW sidecars, episode/season numbering, invoice IDs, camelCase/snake/kebab boundaries
- [ ] Reliability corpus: a large set of real messy folders to push "it just knew" from ~80% → ~98%

## Milestone 3 — The app (AppKit + SwiftUI)
- [x] Drop-folder / Open-folder window; SwiftUI chrome with **personality** (friendly empty state, witty status, warm disagreement prompt)
- [x] Live **preview table** with confident/change/uncertain markers
- [x] Teach-by-example: pick a file, type the corrected name; **multiple examples** accumulate; the disagreement banner jumps you to the file Renamr is unsure about
- [x] Rename with collision-skip (never clobber) + **undo** + start-over
- [x] **Inline edit in the file row** — one unified list; click a file, type its new name in place, the rest preview live with "→ newname"
- [x] **Visual redesign** — violet "magic" brand, livelier empty state (animated hero), prominent gradient actions, cohesive tint
- [x] **App icon** — `Scripts/make-icon.swift` renders a brand-gradient squircle + wand → `Resources/AppIcon.icns`, bundled by `package-app.sh`
- [x] Unconfident rows show the original name, not a partial string
- [ ] Folder bookmarks / security-scoped access (for a sandboxed future build)

## Engine reliability additions
- [x] Extension-case normalization (PHOTO.JPG → photo.jpg, per-file)
- [x] Prefix/abbreviation extraction (January → Jan, generalizes to Feb/Mar)
- [x] **Realistic-filename test coverage** — screenshots, Pixel, DSLR strip+counter, trip-label+counter (14 tests). Proven on names people actually have.
- [x] **Variable-length fields** — `copyRest` collapses a trailing run of word-copies that reaches the last word into "keep the rest", so song/movie/episode titles of any length generalize. Tested (15/15).
- [x] Flexible-width date parts (2024-1-5 → 2024-01-05)
- [x] **Sequential renumbering** — when the output number isn't in the filename, renumber 1,2,3… by file position (camera dumps: DSC0931.JPG → Beach 1.jpg). Keeping the original counter still uses copy.
- [x] **Global separator/case normalize** (`a_b_c → a-b-c`, slug → Title Case) — generalizes across any structure
- [x] **Sequence fail-safe** — no longer invents a 1,2,3 sequence from a chunk extracted out of a longer number (was corrupting); flags instead
- [x] **More date output layouts** (dotted/slashed day-first/month-first; validity disambiguates)
- [x] **Corpus benchmark** — `Tests/Fixtures/corpus-benchmark.json` (160 realistic + adversarial scenarios) run by `swift run renamr-corpus <file>`; currently **87/160** pass (don't let it regress).

### Honest engine ceiling (a one-example PBE engine can't do "everything")
The corpus is deliberately adversarial. The realistic, inferable cases mostly pass; the long tail that remains is either **fundamentally un-inferable from a single example** (arithmetic offsets like +100, Roman→Arabic, accent-stripping, true 12h↔24h clock math, CamelCase splitting, thousands-commas) or **needs 2 examples** (locale-ambiguous dates). The safety principle holds: when unsure, **flag — never silently corrupt**.
- [x] **Month-name dates** (Jan / January, MDY & DMY) → corpus 87→94
- [x] **Clock-time tokens** (recognize as a unit; reformat layout/separators/seconds, strip AM/PM, compact; NO 12↔24 math) → corpus 94→96
Still worth adding by demand: **2-digit years**, duplicate `(1)` / `vN` marker stripping. (Out of scope for a one-example engine: arithmetic, Roman numerals, accents, true clock math.)

## SHIPPED v0.1.0
- [x] `Scripts/build-dmg.sh` → ad-hoc-signed drag-to-Applications `.dmg` ($0, hdiutil, no deps)
- [x] README install + one-time Gatekeeper "Open Anyway" first-launch flow
- [x] GitHub Release **v0.1.0** with the `.dmg` (private repo; flip repo + release public at launch)
- [ ] At launch: make repo public, one-page landing site (domain + VPS), Show HN / r/macapps, awesome-mac PR, Homebrew formula

## Brand & navigation
- [x] **Sprig** — Renamr's mascot, a cheerful sprout drawn in vectors (`Mascot.swift`), with idle/happy/thinking moods; present in the header (reacts to state) + empty state + disagreement prompt.
- [x] **Green-floral rebrand** (`Theme.swift` Brand: leaf green + blossom-pink accent); icon is a leaf emblem.
- [x] **Folder navigation** — folders are listed and stepped into (not treated as rename targets); path bar with Up; files-only get inline rename.
- [x] **Production layout** — compact centered empty state that teaches via before→after example chips; sectioned folder/file list; hover states; consistent spacing.

## Milestone 3.5 — Meet users IN Finder (reduce the "open an app and drag" friction)
The real workflow is files in Finder, not dragging into a window.
- [x] **macOS Service** "Rename by Example with Renamr" — select files in Finder ▸ right-click ▸ Services ▸ Renamr opens pre-scoped to them (`NSServices` in Info.plist + `ServiceProvider`). *Note: appears after the app is in /Applications and LaunchServices/`pbs` refreshes (re-login or `/System/Library/CoreServices/pbs -update`).*
- [x] **"Use Frontmost Finder Folder"** command (⇧⌘F) — reads the front Finder window via AppleScript so you skip dragging (one-time Automation permission for Finder).
- [removed] **Finder Sync extension** — prototyped (XcodeGen + `.appex`, ad-hoc) and then **deleted**: an un-notarized extension won't reliably load for end users, so it can't ship $0 — it would force the $99 Developer ID. The **macOS Service** ("right-click ▸ Rename by Example") + **"Use Frontmost Finder Folder"** cover the in-Finder workflow with no extension and no signing. Back to a pure SwiftPM build (no Xcode project). Revisit the extension only if we ever take Developer ID.

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

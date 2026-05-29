# Renamr

**Rename a whole folder by example.** Correct *one* filename, hit enter, and every other file transforms by the same inferred logic — date reformatting, field reordering, dropped tokens, re-casing, renumbering, and all. No regex, no field chips, no template language.

It's [FlashFill](https://en.wikipedia.org/wiki/Programming_by_example)'s interaction applied to filenames — a domain spreadsheets can't reach, and one no native Mac app currently does.

```
IMG_20240115_vacation_beach_DSC0931.jpg   →   2024-01-15 Beach 0931.jpg
IMG_20240116_trip_sunset_DSC0942.jpg      →   2024-01-16 Sunset 0942.jpg   ← you typed nothing here
IMG_20240117_party_night_DSC1003.jpg      →   2024-01-17 Night 1003.jpg    ← or here
```

You demonstrate the result once. Renamr infers the rule and previews it across the folder.

- **Free & open source** (MIT)
- **100% local** — your files never leave your Mac, no account, no network
- **Native macOS** (Swift) — small, fast, no Electron

## How it works

The moat is a **path-aware programming-by-example synthesizer** (`RenamrCore`), not a rule builder:

1. **Tokenizer** — each filename is parsed into *typed* segments (dates, counters, words, separators) instead of raw characters. Dates are recognized across formats and carved out as single tokens; `DSC0931` splits into word `DSC` + number `0931`. Generalization happens over "the 1st date" / "the 3rd word", which is what lets one example teach the whole folder.
2. **Synthesizer** — for each token of your corrected name, it enumerates every way an input token could explain it (copy / re-case / date-reformat / number-repad) plus a literal fallback, then picks the cheapest under a **simplicity prior**: copying real data beats hard-coding a literal, while separators fall through to literals. That bias is the "it just knew" behaviour.
3. **Apply** — the learned program runs over every file by *re-parsing and re-emitting* (so `20240115 → 2024-01-15` generalizes to `20240116 → 2024-01-16`). Files missing a referenced field are **flagged, never silently mangled**.

See [`PLAN.md`](PLAN.md) for the roadmap (version-space search, disagreement loop, the AppKit/SwiftUI app, signing & distribution).

## Status

Working v0.1 — native SwiftUI app (`Renamr.app`), a CLI (`renamr`), and the engine, with a 24-case test suite plus a 160-scenario benchmark (`swift run renamr-corpus Tests/Fixtures/corpus-benchmark.json`). Handles dates (many layouts incl. month names), times, counters (pad/strip/renumber), reordering, dropping, re-casing, variable-length titles, separator/case normalization, and per-file extensions. When it isn't sure, it **flags — it never silently mangles a file**.

## Install

1. Download `Renamr.dmg` from the [Releases](https://github.com/beartackler/Renamr/releases) page.
2. Open it and drag **Renamr** to **Applications**.

### First launch (one time)
Renamr is free and open source but not notarized by Apple, so the first launch needs one extra step (this is normal for indie/OSS Mac apps):

- Double-click Renamr. macOS says it "could not verify" the app — click **Done** (not Move to Trash).
- Open **System Settings ▸ Privacy & Security**, scroll to **Security**, and click **Open Anyway** next to Renamr, then confirm.
- It opens normally from then on.

Power-user shortcut instead of the above:
```sh
xattr -dr com.apple.quarantine /Applications/Renamr.app
```

## Build from source

Requires Xcode (or Swift 6 Command Line Tools).

```sh
swift test                       # run the engine test suite
swift run renamr "DSC0931.JPG" "Beach 1.jpg" *.JPG   # CLI preview (✓ confident, ? flagged)
./Scripts/package-app.sh         # build Renamr.app (ad-hoc signed, local use)
./Scripts/build-dmg.sh           # build a distributable Renamr-<version>.dmg
```

## Project layout

```
Sources/RenamrCore/   the synthesizer engine (pure Swift + Foundation, no UI)
Sources/renamr/       a thin CLI that exercises the engine
Tests/                XCTest suite
```

## License

MIT — see [`LICENSE`](LICENSE).

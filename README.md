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

Early. The engine (`RenamrCore`) and a CLI exist with a passing test suite; the GUI app is next. The engine's algorithm is validated on the cases in `Tests/` (date reformat + reorder + drop + re-case + counter, on a single example).

## Build & test

Requires a working Swift 6 toolchain (Xcode or Command Line Tools).

```sh
swift test          # run the engine test suite
swift run renamr "IMG_20240115_beach_DSC0931.jpg" "2024-01-15 Beach 0931.jpg" *.jpg
```

The CLI prints a preview (`✓` confident, `?` flagged); it does not rename files yet.

## Project layout

```
Sources/RenamrCore/   the synthesizer engine (pure Swift + Foundation, no UI)
Sources/renamr/       a thin CLI that exercises the engine
Tests/                XCTest suite
```

## License

MIT — see [`LICENSE`](LICENSE).

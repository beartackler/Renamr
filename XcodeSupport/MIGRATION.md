# Xcode migration — Finder Sync extension

The engine + app + CLI build with SwiftPM. The one thing SwiftPM **cannot** build
is an app-extension (`.appex`), which the Finder Sync extension (a Renamr button
in the Finder toolbar) requires. This folder + `project.yml` set that up via an
Xcode project layered on top of the same sources.

## What's done (authored + verified where possible)
- `FinderExtension/FinderSync.swift` — the `FIFinderSync` subclass (`RenamrFinderSync`).
  **Typechecked against the real `FinderSync` framework** (0 diagnostics). It adds the
  contextual + toolbar item and hands the selection to the app via `NSWorkspace.open`.
- `Sources/RenamrApp/RenamrApp.swift` — `application(_:open:)` receives that selection.
- `project.yml` (XcodeGen) — app target + extension target (embedded), both on the
  `RenamrCore` SwiftPM package.
- `XcodeSupport/RenamrApp-Info.plist`, `RenamrFinder-Info.plist` — bundle + NSExtension config.

## Finish it (one command set) — BLOCKED on two things right now
```sh
brew install xcodegen          # ← currently fails: ghcr.io (GitHub) is unreachable on this network
xcodegen generate              # produces Renamr.xcodeproj (gitignored)
xcodebuild -project Renamr.xcodeproj -scheme Renamr -configuration Release build
```

### Blocker 1 — network
`xcodegen`'s Homebrew bottle is on `ghcr.io` (GitHub-owned), which is blocked by the
same VPN/firewall that's blocking `github.com` (every port times out; the rest of the
internet is fine). Fix the network block, then the commands above work. The `project.yml`
spec itself has not been run through `xcodegen` yet, so treat it as unverified until then.

### Blocker 2 — signing (the $99 question)
A Finder Sync extension realistically needs **Developer ID signing + notarization** to
load for *end users* on current macOS; an ad-hoc/un-notarized extension won't reliably
enable. That's the $99/yr Apple Developer Program we deliberately deferred. For local
*developer* testing, ad-hoc (`CODE_SIGN_IDENTITY: "-"`) + enabling it in
System Settings ▸ General ▸ Login Items & Extensions can work, but it's finicky.

## The $0 alternative that already ships
The main app already registers a **macOS Service** ("Rename by Example with Renamr")
— right-click selected files in Finder ▸ Services ▸ Renamr — plus a **"Use Frontmost
Finder Folder"** command. These need **no extension and no signing**, and cover the
core "rename from Finder" workflow for free. The Finder Sync toolbar extension is a
polish upgrade to graduate to alongside Developer ID.

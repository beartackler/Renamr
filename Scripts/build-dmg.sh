#!/usr/bin/env bash
# Build a distributable Renamr .dmg (drag-to-Applications), $0, no dependencies
# beyond the OS. Ad-hoc signed (see package-app.sh); not notarized — see the
# "First launch" note in the README for the one-time Gatekeeper step.
#
#   ./Scripts/build-dmg.sh    →  build/Renamr-<version>.dmg
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="Renamr"
VERSION="0.1.1"
DMG="build/${APP_NAME}-${VERSION}.dmg"

echo "==> building app bundle"
./Scripts/package-app.sh >/dev/null

echo "==> staging disk image"
STAGE="build/dmg-stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp -R "build/${APP_NAME}.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

echo "==> creating ${DMG}"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> done: ${DMG}  ($(du -h "$DMG" | cut -f1))"

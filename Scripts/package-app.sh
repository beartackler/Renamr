#!/usr/bin/env bash
# Build Renamr.app from the SwiftPM RenamrApp target.
#
#   ./Scripts/package-app.sh           # release build -> build/Renamr.app (ad-hoc signed, for local use)
#
# This produces an UNSIGNED-for-distribution bundle (ad-hoc signed so it runs
# locally on this Mac). Real distribution adds Developer ID signing + notarization
# + a .dmg (see PLAN.md, Milestone 4).
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Renamr"
EXECUTABLE="RenamrApp"
BUNDLE_ID="app.renamr.Renamr"
VERSION="0.1.0"
BUILD_NUMBER="1"
MIN_MACOS="13.0"

OUT_DIR="build"
APP="${OUT_DIR}/${APP_NAME}.app"
CONTENTS="${APP}/Contents"

echo "==> swift build -c release"
swift build -c release --product "${EXECUTABLE}"
BIN="$(swift build -c release --product "${EXECUTABLE}" --show-bin-path)/${EXECUTABLE}"

echo "==> assembling ${APP}"
rm -rf "${APP}"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources"
cp "${BIN}" "${CONTENTS}/MacOS/${APP_NAME}"
chmod +x "${CONTENTS}/MacOS/${APP_NAME}"

cat > "${CONTENTS}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleExecutable</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>${MIN_MACOS}</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT licensed.</string>
</dict>
</plist>
PLIST

echo "==> ad-hoc codesign (local use)"
codesign --force --sign - "${APP}" >/dev/null 2>&1 || codesign --force --sign - "${APP}"

echo "==> done: ${APP}"
echo "    open ${APP}     # or double-click it in Finder"

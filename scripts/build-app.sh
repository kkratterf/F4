#!/usr/bin/env bash
# Builds ReactionDeck.app (and a zip of it) from the Swift package.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
# Environment: SIGN_IDENTITY  codesign identity (default "-", ad-hoc)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/ReactionDeck.app"

cd "$ROOT"
# Universal when the toolchain can; otherwise the host architecture only. The bin path
# must come from the same kind of build, or cp below looks in the wrong folder.
ARCH_FLAGS=(--arch arm64 --arch x86_64)
if ! swift build -c "$CONFIG" "${ARCH_FLAGS[@]}"; then
  echo "warning: universal build failed, building for the host architecture only" >&2
  ARCH_FLAGS=()
  swift build -c "$CONFIG"
fi
# The ${a[@]+...} form keeps bash 3.2 (macOS) happy with an empty array under set -u.
BIN_DIR="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ReactionDeck" "$APP/Contents/MacOS/ReactionDeck"
if [ "$CONFIG" = "release" ]; then
  # Debug info and local symbols are only for crash symbolication; must run before codesign.
  strip -S -x "$APP/Contents/MacOS/ReactionDeck"
fi
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/ReactionDeck" 2>/dev/null || echo unknown)"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc by default: enough to run locally, not notarized.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$APP"
else
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --strict --verbose=1 "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
(cd "$DIST" && rm -f "ReactionDeck-$VERSION.zip" && ditto -c -k --keepParent ReactionDeck.app "ReactionDeck-$VERSION.zip")

echo "Built $APP"
echo "Zipped $DIST/ReactionDeck-$VERSION.zip"

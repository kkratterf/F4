#!/usr/bin/env bash
# Builds F4.app (and a zip of it) from the Swift package.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
# Environment: SIGN_IDENTITY  codesign identity (default "-", ad-hoc)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/F4.app"

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
cp "$BIN_DIR/F4" "$APP/Contents/MacOS/F4"
if [ "$CONFIG" = "release" ]; then
  # Debug info and local symbols are only for crash symbolication; must run before codesign.
  strip -S -x "$APP/Contents/MacOS/F4"
fi
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/F4" 2>/dev/null || echo unknown)"

# Sparkle (auto-update): embed the framework and let the executable find it in
# Contents/Frameworks. SwiftPM copies it next to the binary; the artifacts
# folder is the fallback. Must happen before codesign.
SPARKLE_FW="$BIN_DIR/Sparkle.framework"
if [ ! -d "$SPARKLE_FW" ]; then
  SPARKLE_FW="$(find "$ROOT/.build/artifacts" -type d -path '*macos-arm64_x86_64/Sparkle.framework' -print 2>/dev/null | head -n 1)"
fi
if [ -z "$SPARKLE_FW" ] || [ ! -d "$SPARKLE_FW" ]; then
  echo "error: Sparkle.framework not found in $BIN_DIR or .build/artifacts" >&2
  exit 1
fi
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/F4" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/F4"
fi
echo "Embedded Sparkle.framework ($(du -sk "$APP/Contents/Frameworks/Sparkle.framework" | cut -f1) KB)"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Sparkle compares CFBundleVersion to decide what is newer, so it follows the
# marketing version (0.2.0 > 0.1.9) instead of a hand-maintained counter.
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $SHORT_VERSION" "$APP/Contents/Info.plist"

# Localizations: English is the source language, Italian comes from the String
# Catalog. SwiftPM compiles it into the target's resource bundle; the .lproj
# folders go into Contents/Resources so Bundle.main (SwiftUI Text,
# String(localized:)) finds them. Falls back to xcstringstool if SwiftPM did not.
CATALOG="$ROOT/Sources/F4/Resources/Localizable.xcstrings"
RES="$APP/Contents/Resources"
while IFS= read -r lproj; do
  [ -n "$lproj" ] || continue
  ditto "$lproj" "$RES/$(basename "$lproj")"
done < <(find "$BIN_DIR" -path '*F4_F4.bundle*' -type d -name '*.lproj' 2>/dev/null)
if [ ! -f "$RES/it.lproj/Localizable.strings" ]; then
  echo "No compiled it.lproj in the SwiftPM bundle, compiling $CATALOG with xcstringstool"
  xcrun xcstringstool compile "$CATALOG" --output-directory "$RES"
fi
# English strings are the keys themselves; the folder tells macOS the app speaks English.
mkdir -p "$RES/en.lproj"
if [ ! -f "$RES/it.lproj/Localizable.strings" ]; then
  echo "error: it.lproj/Localizable.strings missing from $APP" >&2
  exit 1
fi
echo "Localizations: $(find "$RES" -maxdepth 1 -name '*.lproj' -exec basename {} \; | sort | tr '\n' ' ')"

# App icon: drawn in code by scripts/make-icon.swift, so no binary is
# committed. A failure here only costs the icon, never the build.
ICON_DIR="$ROOT/.build/icon"
rm -rf "$ICON_DIR"
mkdir -p "$ICON_DIR"
if swift "$ROOT/scripts/make-icon.swift" "$ICON_DIR/AppIcon.iconset" \
  && iconutil -c icns "$ICON_DIR/AppIcon.iconset" -o "$ICON_DIR/AppIcon.icns"; then
  cp "$ICON_DIR/AppIcon.icns" "$RES/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
  echo "Added the app icon ($(wc -c < "$RES/AppIcon.icns" | tr -d ' ') bytes)"
else
  echo "warning: could not draw the app icon, building without it" >&2
fi

# Starter pack (issue #92): what a new user sees before adding their own.
# The GIFs are Google's Noto Animated Emoji (CC BY 4.0, credited in the app
# and the README); the stickers are drawn in code like the icon. They stay in
# the bundle and are never copied into the user's meme folder.
STARTER="$RES/Starter"
rm -rf "$STARTER"
mkdir -p "$STARTER/GIFs"
ditto "$ROOT/Resources/Starter/GIFs" "$STARTER/GIFs"
if ! swift "$ROOT/scripts/make-stickers.swift" "$STARTER/Stickers"; then
  echo "warning: could not draw the starter stickers, building without them" >&2
fi
echo "Starter pack: $(find "$STARTER/GIFs" -name '*.gif' | wc -l | tr -d ' ') GIFs, $(find "$STARTER" -path '*/Stickers/*.png' | wc -l | tr -d ' ') stickers"

# Ad-hoc by default: enough to run locally, not notarized.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  # Inside out, as Sparkle documents it: its helpers first, then the framework,
  # then the app. --deep would drop the Downloader's entitlements.
  FW="$APP/Contents/Frameworks/Sparkle.framework"
  sign() { codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"; }
  sign "$FW/Versions/B/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
  sign "$FW/Versions/B/Autoupdate"
  sign "$FW/Versions/B/Updater.app"
  sign "$FW"
  sign "$APP"
fi
codesign --verify --deep --strict --verbose=1 "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
(cd "$DIST" && rm -f "F4-$VERSION.zip" && ditto -c -k --keepParent F4.app "F4-$VERSION.zip")

echo "Built $APP"
echo "Zipped $DIST/F4-$VERSION.zip"

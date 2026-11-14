#!/usr/bin/env bash
# Records the website's hero clip on a Mac: the real F4.app over a made-up chat
# (scripts/hero/chat.html in Google Chrome or Safari), driven by synthetic key presses.
# fn F4 opens the panel, a search is typed, Enter copies, ⌘V pastes into the
# chat; twice, the second time an animated sticker. The stickers are the
# maintainer's own (STICKERS=folder, copied into F4's library in place of the
# starter pack). The raw take lands in
# $OUT/raw.mov; scripts/make-hero-video.sh turns it into site/media/hero.mp4,
# its poster and the README preview.
#
# On a CI runner (.github/workflows/hero-video.yml) it changes the Mac for
# good (wallpaper, Dock, dark mode, F4's library and defaults) and records
# dist/F4.app. With LOCAL=1 it records the F4 installed on a real Mac instead,
# pointed for the take at LIBRARY (a folder of stickers, the user's library
# untouched), and puts the wallpaper, the Dock, the appearance and F4's
# settings back when it ends. Needs Google Chrome, and Accessibility and
# Screen Recording for the app that runs it (GitHub's runners grant both).
# Usage: STICKERS=path/to/stickers scripts/record-hero.sh       (CI)
#        LOCAL=1 LIBRARY=path/to/stickers scripts/record-hero.sh (a real Mac)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCAL="${LOCAL:-}"
if [ -n "$LOCAL" ]; then APP="${APP:-/Applications/F4.app}"; else APP="${APP:-$ROOT/dist/F4.app}"; fi
OUT="${OUT:-$ROOT/dist/hero}"
QUERY="${QUERY:-}"            # "?it" records the Italian chat, "?debug" shows what a paste carried
BROWSER="${BROWSER:-chrome}"  # chrome or safari
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
LIB="$HOME/Library/Application Support/F4/Memes"
SECONDS_TO_RECORD="${SECONDS_TO_RECORD:-30}"

[ -d "$APP" ] || { echo "error: $APP not found, run scripts/build-app.sh release first" >&2; exit 1; }
mkdir -p "$OUT"

se() { osascript -e "tell application \"System Events\" to $1"; }
press() { se "key code $1"; }
typed() {
  local text="$1" i
  for ((i = 0; i < ${#text}; i++)); do
    se "keystroke \"${text:i:1}\""
    sleep 0.09
  done
}
pasteboard_types() {
  osascript -l JavaScript -e 'ObjC.import("AppKit"); ObjC.deepUnwrap($.NSPasteboard.generalPasteboard.types).join(", ")' >&2 || true
}
panel_windows() { se 'count (windows of process "F4")' 2>/dev/null || echo 0; }
# fn F4 as the user presses it; f4://open if the synthetic key did not reach
# the Carbon hotkey.
open_panel() {
  press 118
  sleep 0.5
  if [ "$(panel_windows)" = 0 ]; then
    echo "F4 key did not open the panel, using f4://open"
    open "f4://open"
  fi
}

screen=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; f.size.width + "x" + f.size.height')
echo "screen: $screen"
width=${screen%x*}
height=${screen#*x}

f4_defaults="com.kkratterf.f4"
if [ -n "$LOCAL" ]; then
  # Remember what the take changes, and put it back however the script ends.
  old_wallpaper=$(se 'get picture of desktop 1' 2>/dev/null || true)
  old_dark=$(se 'get dark mode of appearance preferences' 2>/dev/null || echo false)
  old_autohide=$(defaults read com.apple.dock autohide 2>/dev/null || echo 0)
  old_delay=$(defaults read com.apple.dock autohide-delay 2>/dev/null || true)
  old_folder=$(defaults read "$f4_defaults" memeFolderPath 2>/dev/null || true)
  restore() {
    pkill -x F4 || true
    if [ -n "$old_folder" ]; then defaults write "$f4_defaults" memeFolderPath "$old_folder"
    else defaults delete "$f4_defaults" memeFolderPath 2>/dev/null || true; fi
    [ -n "$old_wallpaper" ] && se "tell every desktop to set picture to POSIX file \"$old_wallpaper\"" || true
    se "tell appearance preferences to set dark mode to $old_dark" || true
    defaults write com.apple.dock autohide -bool "$([ "$old_autohide" = 1 ] && echo true || echo false)"
    if [ -n "$old_delay" ]; then defaults write com.apple.dock autohide-delay -float "$old_delay"
    else defaults delete com.apple.dock autohide-delay 2>/dev/null || true; fi
    killall Dock || true
    sleep 1
    open "$APP"
  }
  trap restore EXIT
fi

# A clean desk: dark mode, the website's gradient as wallpaper, no Dock.
se 'tell appearance preferences to set dark mode to true' || echo "warning: could not turn on dark mode"
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
killall Dock || true
wallpaper="$ROOT/site/media/try-bg.jpg"
se "tell every desktop to set picture to POSIX file \"$wallpaper\"" ||
  osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"$wallpaper\"" ||
  echo "warning: could not set the wallpaper"

if [ -n "$LOCAL" ]; then
  # The installed F4, reading LIBRARY for the take.
  [ -d "${LIBRARY:-}" ] || { echo "error: set LIBRARY to a folder of stickers" >&2; exit 1; }
  pkill -x F4 || true
  sleep 1
  defaults write "$f4_defaults" memeFolderPath "$(cd "$LIBRARY" && pwd)/"
else
# F4 as an existing user has it: welcome window seen, no update prompt.
defaults write com.kkratterf.f4 didShowWelcome -bool true
defaults write com.kkratterf.f4 SUEnableAutomaticChecks -bool false
defaults write com.kkratterf.f4 SUHasLaunchedBefore -bool true
mkdir -p "$LIB"
fi
if [ -z "$LOCAL" ] && [ -n "${STICKERS:-}" ]; then
  cp -R "$STICKERS"/. "$LIB/"
  # The library as the maintainer has it: no starter pack copied in.
  defaults write com.kkratterf.f4 seededStarterFolders -array Maramao
  defaults write com.kkratterf.f4 didSeedLibrary -bool true
  defaults write com.kkratterf.f4 didRemoveRetiredStarter -bool true
  defaults write com.kkratterf.f4 didRenameStarterFolders -bool true
fi
open "$APP"
sleep 8   # the library is scanned, and the login item notice comes and goes

# The chat, a window in the middle of the screen with the gradient around it.
win_w=$((width * 82 / 100))
win_h=$(((height * 625 / 768) * 84 / 100))
win_x=$(((width - win_w) / 2))
win_y=$((25 + ((height * 625 / 768) - 25 - win_h) / 2))
page="file://$ROOT/scripts/hero/chat.html$QUERY"
if [ "$BROWSER" = safari ]; then
  proc=Safari
  open -a Safari "$page"
  sleep 6
  se 'tell process "Safari" to click menu item "Hide Toolbar" of menu "View" of menu bar 1' ||
    echo "warning: could not hide Safari's toolbar"
  se "tell process \"Safari\" to set position of window 1 to {$win_x, $win_y}"
  se "tell process \"Safari\" to set size of window 1 to {$win_w, $win_h}"
else
  proc="Google Chrome"
  [ -x "$CHROME" ] || { echo "error: Google Chrome not found" >&2; exit 1; }
  profile=$(mktemp -d)
  "$CHROME" --user-data-dir="$profile" --no-first-run --no-default-browser-check \
    --use-mock-keychain --password-store=basic --disable-features=Translate \
    --window-position="$win_x,$win_y" --window-size="$win_w,$win_h" \
    --app="$page" >/dev/null 2>&1 &
  sleep 6
fi
se "set frontmost of process \"$proc\" to true" || true
osascript -l JavaScript -e 'ObjC.import("CoreGraphics"); $.CGWarpMouseCursorPosition({x: 5000, y: 5000})' || true
sleep 1
screencapture -x "$OUT/setup.png"

screencapture -v -x -V "$SECONDS_TO_RECORD" "$OUT/raw.mov" &
recorder=$!
sleep 2.5

# 1. A still sticker: fn F4, "cazzo di", Enter, ⌘V.
open_panel
sleep 1.4
typed "cazzo di"
sleep 1.1
press 36            # Enter: copies, the panel hides, the toast shows
sleep 1.6
pasteboard_types
se 'keystroke "v" using command down'
sleep 2.4

# 2. The animated one: fn F4, walk the grid with the arrows, then search.
open_panel
sleep 1.0
press 124; sleep 0.45; press 124; sleep 0.45; press 125; sleep 0.8
typed "happ"
sleep 1.8           # the selected sticker plays in the panel
press 36
sleep 1.6
pasteboard_types
se 'keystroke "v" using command down'
sleep 4

wait "$recorder" || true
screencapture -x "$OUT/end.png"
if [ "$BROWSER" = safari ]; then osascript -e 'tell application "Safari" to quit' || true
else pkill -f -- "--user-data-dir=$profile" || true; fi
[ -n "$LOCAL" ] || pkill -x F4 || true
ls -la "$OUT"

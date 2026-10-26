#!/bin/sh
# Installs F4.app from the latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/kkratterf/f4/main/install.sh | sh
#
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/kkratterf/f4/main/install.sh | sh -s -- --uninstall
#
# Environment:
#   F4_VERSION      release to install, e.g. v0.2.0 (default: latest)
#   F4_INSTALL_DIR  where to put F4.app (default: /Applications, or
#                   ~/Applications if /Applications is not writable)
#   F4_NO_OPEN=1    do not offer to open F4 after installing

set -eu

REPO="kkratterf/f4"
APP_NAME="F4.app"
BUNDLE_ID="com.kkratterf.f4"

say() { printf '%s\n' "$*"; }
warn() { printf 'f4: %s\n' "$*" >&2; }
fail() { printf 'f4: %s\n' "$*" >&2; exit 1; }

usage() {
  say "Usage: install.sh [--uninstall]"
  say ""
  say "  (no option)   install or update F4.app"
  say "  --uninstall   remove F4.app and its settings"
  say ""
  say "Variables: F4_VERSION, F4_INSTALL_DIR, F4_NO_OPEN=1"
}

mode="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode="uninstall" ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; fail "unknown option: $arg" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || fail "F4 is a macOS app, it cannot be installed here"

macos="$(sw_vers -productVersion 2>/dev/null || echo 0)"
major="${macos%%.*}"
case "$major" in
  '' | *[!0-9]*) major=0 ;;
esac
[ "$major" -ge 14 ] || fail "F4 needs macOS 14 Sonoma or later, this is macOS $macos"

# Picks the folder for F4.app.
install_dir() {
  if [ -n "${F4_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$F4_INSTALL_DIR"
  elif [ -w /Applications ]; then
    printf '%s\n' /Applications
  else
    printf '%s\n' "$HOME/Applications"
  fi
}

# Quits a running F4: politely first, then for real.
quit_f4() {
  pgrep -x F4 >/dev/null 2>&1 || return 0
  say "Quitting F4..."
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  i=0
  while [ "$i" -lt 10 ] && pgrep -x F4 >/dev/null 2>&1; do
    sleep 0.5
    i=$((i + 1))
  done
  pkill -x F4 >/dev/null 2>&1 || true
}

# True when we can ask the user a question, even under `curl | sh`.
can_ask() {
  [ -t 1 ] && (: </dev/tty) 2>/dev/null
}

uninstall() {
  quit_f4
  removed=0
  for dir in "${F4_INSTALL_DIR:-/Applications}" /Applications "$HOME/Applications"; do
    if [ -d "$dir/$APP_NAME" ]; then
      rm -rf "${dir:?}/$APP_NAME" || fail "cannot remove $dir/$APP_NAME (try with sudo)"
      say "Removed $dir/$APP_NAME"
      removed=1
    fi
  done
  if defaults read "$BUNDLE_ID" >/dev/null 2>&1; then
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    say "Removed the settings ($BUNDLE_ID)"
  fi
  [ "$removed" = 1 ] || say "F4.app was not installed."
  say "Your meme folder was left exactly where it is."
  say "If you had turned on \"Open F4 at login\", macOS removes the login item with the app;"
  say "check System Settings > General > Login Items."
}

if [ "$mode" = "uninstall" ]; then
  uninstall
  exit 0
fi

command -v curl >/dev/null 2>&1 || fail "curl is required to download F4"
command -v ditto >/dev/null 2>&1 || fail "ditto is required"

api="https://api.github.com/repos/$REPO"

version="${F4_VERSION:-}"
if [ -z "$version" ]; then
  # /releases/latest skips pre-releases, so fall back to the newest release.
  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/releases/latest" 2>/dev/null)" \
    || json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/releases?per_page=1" 2>/dev/null)" \
    || fail "cannot reach the GitHub API to find the latest release"
  version="$(printf '%s\n' "$json" | grep -m 1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [ -n "$version" ] || fail "no release found at github.com/$REPO/releases"
fi
case "$version" in
  v*) ;;
  *) version="v$version" ;;
esac

name="F4-${version#v}.zip"
base="https://github.com/$REPO/releases/download/$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "Downloading F4 $version..."
curl -fsSL "$base/$name" -o "$tmp/$name" || fail "download failed: $base/$name"

if curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt" 2>/dev/null; then
  expected="$(grep " \*\{0,1\}$name\$" "$tmp/SHA256SUMS.txt" | cut -d' ' -f1)"
  actual="$(shasum -a 256 "$tmp/$name" | cut -d' ' -f1)"
  [ -n "$expected" ] || fail "$name is not listed in SHA256SUMS.txt"
  [ "$expected" = "$actual" ] || fail "wrong checksum for $name: the download is corrupted, try again"
  say "SHA-256 checksum verified."
else
  warn "this release has no SHA256SUMS.txt, skipping the checksum check"
fi

ditto -x -k "$tmp/$name" "$tmp/unzipped" || fail "cannot extract $name"
[ -d "$tmp/unzipped/$APP_NAME" ] || fail "$name does not contain $APP_NAME"

dir="$(install_dir)"
mkdir -p "$dir" || fail "cannot create $dir"
[ -w "$dir" ] || fail "cannot write to $dir (try F4_INSTALL_DIR=\$HOME/Applications)"
dest="$dir/$APP_NAME"

quit_f4
if [ -e "$dest" ]; then
  rm -rf "$dest" || fail "cannot replace $dest"
fi
ditto "$tmp/unzipped/$APP_NAME" "$dest" || fail "cannot copy the app into $dir"
# Not notarized yet: clear the quarantine flag so Gatekeeper lets it start.
xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true

say "Done. F4 $version is installed in $dest"
say "Press Command-Shift-M anywhere to open it, and put your memes in ~/Pictures/Memes"
say "(or pick another folder in Settings, from the menu bar icon)."

if [ "${F4_NO_OPEN:-0}" = 1 ] || ! can_ask; then
  say "To open it: open \"$dest\""
  exit 0
fi
printf 'Open F4 now? [Y/n] '
answer=""
read -r answer </dev/tty || answer="n"
case "$answer" in
  '' | [SsYy]*) open "$dest" ;;
  *) say "To open it: open \"$dest\"" ;;
esac

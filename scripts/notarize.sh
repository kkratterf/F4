#!/usr/bin/env bash
# Notarizes F4.app or a DMG with Apple's notary service and staples the ticket,
# so Gatekeeper opens the download without "Open Anyway", even offline.
#
# Usage: scripts/notarize.sh dist/F4.app
#        scripts/notarize.sh dist/F4-x.y.z.dmg
#
# The file must already be signed with a Developer ID Application identity,
# with the hardened runtime and a secure timestamp (scripts/build-app.sh and
# scripts/build-dmg.sh do that when SIGN_IDENTITY is set).
#
# Environment (GitHub secrets in release.yml):
#   APPLE_ID                     the Apple Account of the developer team
#   APPLE_APP_SPECIFIC_PASSWORD  an app-specific password of that account
#   APPLE_TEAM_ID                the 10-character team ID
set -euo pipefail

TARGET="${1:?usage: scripts/notarize.sh <F4.app|F4.dmg>}"
: "${APPLE_ID:?APPLE_ID is not set}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is not set}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is not set}"

if [ ! -e "$TARGET" ]; then
  echo "error: $TARGET does not exist" >&2
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The notary service takes a zip, a pkg or a dmg: an app goes up as a zip.
case "$TARGET" in
  *.app)
    UPLOAD="$WORK/$(basename "$TARGET" .app).zip"
    ditto -c -k --keepParent "$TARGET" "$UPLOAD"
    ;;
  *.dmg)
    UPLOAD="$TARGET"
    ;;
  *)
    echo "error: $TARGET is neither an .app nor a .dmg" >&2
    exit 1
    ;;
esac

auth=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")

echo "Submitting $(basename "$TARGET") for notarization..."
# notarytool can exit 0 for a rejected submission, so read the status itself.
xcrun notarytool submit "$UPLOAD" "${auth[@]}" --wait --timeout 30m \
  --output-format json > "$WORK/result.json"
cat "$WORK/result.json"
echo
read_field() {
  /usr/bin/python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$WORK/result.json" "$1"
}
STATUS="$(read_field status)"
ID="$(read_field id)"

if [ "$STATUS" != "Accepted" ]; then
  echo "error: notarization of $(basename "$TARGET") ended with status '$STATUS'" >&2
  if [ -n "$ID" ]; then
    # The log says which file and which signature check failed.
    xcrun notarytool log "$ID" "${auth[@]}" || true
  fi
  exit 1
fi

echo "Notarized ($ID), stapling the ticket"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

# What Gatekeeper will say on a user's Mac.
case "$TARGET" in
  *.app) spctl --assess --type execute --verbose=2 "$TARGET" ;;
  *.dmg) spctl --assess --type open --context context:primary-signature --verbose=2 "$TARGET" ;;
esac
echo "Notarized and stapled $TARGET"

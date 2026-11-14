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
# Environment (GitHub secrets in release.yml), an App Store Connect API key:
#   APPLE_NOTARY_KEY_ID          the key's ID
#   APPLE_NOTARY_ISSUER_ID       the issuer ID shown above the keys list
#   APPLE_NOTARY_KEY_P8_BASE64   the AuthKey_<id>.p8 file, in base64
# or, without a key, an Apple Account:
#   APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID
set -euo pipefail

TARGET="${1:?usage: scripts/notarize.sh <F4.app|F4.dmg>}"
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

if [ -n "${APPLE_NOTARY_KEY_P8_BASE64:-}" ]; then
  : "${APPLE_NOTARY_KEY_ID:?APPLE_NOTARY_KEY_ID is not set}"
  : "${APPLE_NOTARY_ISSUER_ID:?APPLE_NOTARY_ISSUER_ID is not set}"
  KEY_FILE="$WORK/AuthKey_$APPLE_NOTARY_KEY_ID.p8"
  printf '%s' "$APPLE_NOTARY_KEY_P8_BASE64" | base64 --decode > "$KEY_FILE"
  auth=(--key "$KEY_FILE" --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID")
else
  : "${APPLE_ID:?set APPLE_NOTARY_KEY_P8_BASE64 (with its key and issuer IDs) or APPLE_ID}"
  : "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is not set}"
  : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is not set}"
  auth=(--apple-id "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --team-id "$APPLE_TEAM_ID")
fi

read_field() {
  /usr/bin/python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], ""))' "$WORK/result.json" "$1"
}

echo "Submitting $(basename "$TARGET") for notarization..."
xcrun notarytool submit "$UPLOAD" "${auth[@]}" --output-format json > "$WORK/result.json"
cat "$WORK/result.json"
echo
ID="$(read_field id)"
if [ -z "$ID" ]; then
  echo "error: the notary service returned no submission ID" >&2
  exit 1
fi
# A team's first submissions can stay "In Progress" for hours while Apple
# looks at them; later ones take minutes. NOTARY_TIMEOUT sets how long to wait.
echo "Submission $ID, waiting up to ${NOTARY_TIMEOUT:-3h}"
xcrun notarytool wait "$ID" "${auth[@]}" --timeout "${NOTARY_TIMEOUT:-3h}" \
  --output-format json > "$WORK/result.json" || true
cat "$WORK/result.json"
echo
# notarytool can exit 0 for a rejected submission, so read the status itself.
STATUS="$(read_field status)"

if [ "$STATUS" = "In Progress" ] || [ -z "$STATUS" ]; then
  echo "error: submission $ID is still in progress after ${NOTARY_TIMEOUT:-3h}; Apple may still accept it" >&2
  exit 1
fi
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

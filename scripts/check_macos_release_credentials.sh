#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNING_FINGERPRINT="${RANTLIST_SIGNING_FINGERPRINT:-B97863CA4E17170FCD5FBFA4C76A8DF3D91D5F6B}"
NOTARY_PROFILE="${RANTLIST_NOTARY_PROFILE:-workwork-caption-notary}"
source "$ROOT/scripts/release_profile.sh"

fail=0
log(){ printf '\033[1;36m==>\033[0m %s\n' "$*"; }
[[ "$(uname -s)" == Darwin ]] || { echo "ERROR: Run this on macOS." >&2; exit 1; }

log "WORKWORK.FUN Developer ID"
line="$(security find-identity -v -p codesigning 2>/dev/null | grep -F "$SIGNING_FINGERPRINT" | head -n1 || true)"
if [[ -n "$line" ]]; then printf '%s\n' "$line"; else echo "ERROR: signing fingerprint not found." >&2; fail=1; fi

log "Apple notarization profile"
if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" --output-format json >/dev/null 2>&1; then
  echo "Usable: $NOTARY_PROFILE"
else
  echo "ERROR: $NOTARY_PROFILE is not usable." >&2; fail=1
fi

log "GitHub CLI"
if command -v gh >/dev/null 2>&1 && gh auth status -h github.com >/dev/null 2>&1; then
  gh auth status -h github.com
else
  echo "ERROR: gh is missing or not authenticated." >&2; fail=1
fi

log "Rantlist homepage SSH profile"
if rantlist_load_release_profile; then
  if ssh -o BatchMode=yes -o ConnectTimeout=12 -p "$RANTLIST_REMOTE_PORT" "$RANTLIST_REMOTE_USER@$RANTLIST_REMOTE_HOST" true; then
    echo "SSH deployment access works."
  else
    echo "ERROR: homepage SSH access failed." >&2; fail=1
  fi
else
  fail=1
fi

exit "$fail"

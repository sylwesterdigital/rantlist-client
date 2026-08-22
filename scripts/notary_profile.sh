#!/usr/bin/env bash
# Compatibility helper. Rantlist uses the existing WORKWORK.FUN notarization profile from the Cut release setup.
set -Eeuo pipefail
resolve_notary_profile(){
  local requested="${1:-${RANTLIST_NOTARY_PROFILE:-workwork-caption-notary}}"
  [[ -n "$requested" ]] || requested="workwork-caption-notary"
  xcrun notarytool history --keychain-profile "$requested" --output-format json >/dev/null 2>&1 || return 1
  printf '%s\n' "$requested"
}

#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=android_sdk.sh
source "$ROOT/scripts/android_sdk.sh"
KEYSTORE_PATH="${RANTLIST_ANDROID_KEYSTORE:-$HOME/.config/workwork/rantlist-android-release.keystore}"
KEY_ALIAS="${RANTLIST_ANDROID_KEY_ALIAS:-rantlist}"
KEYCHAIN_SERVICE="${RANTLIST_ANDROID_KEYCHAIN_SERVICE:-workwork.rantlist.android.keystore}"
KEYCHAIN_ACCOUNT="${RANTLIST_ANDROID_KEYCHAIN_ACCOUNT:-rantlist}"
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || die "Android signed release currently expects macOS Keychain."
for t in keytool security curl unzip; do command -v "$t" >/dev/null 2>&1 || die "Required Android release tool missing: $t"; done
ensure_android_java
[[ -f "$KEYSTORE_PATH" ]] || die "Android release keystore is missing. Run ./scripts/setup_android_release.sh once."
PASSWORD="$(security find-generic-password -w -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" 2>/dev/null || true)"
[[ -n "$PASSWORD" ]] || die "Android keystore password is missing from macOS Keychain. Run ./scripts/setup_android_release.sh after backing up/removing the incomplete keystore."
keytool -list -keystore "$KEYSTORE_PATH" -storepass "$PASSWORD" -alias "$KEY_ALIAS" >/dev/null 2>&1 || die "Android release keystore or alias is not usable."
ensure_android_sdk
printf 'Android release signing and SDK are usable (API %s, Build Tools %s).\n' "$ANDROID_API_LEVEL" "$ANDROID_BUILD_TOOLS_VERSION"

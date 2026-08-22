#!/usr/bin/env bash
# One-time Android release signing setup. Keystore stays outside the repository; password is stored in macOS Keychain.
set -Eeuo pipefail
IFS=$'\n\t'
KEYSTORE_PATH="${RANTLIST_ANDROID_KEYSTORE:-$HOME/.config/workwork/rantlist-android-release.keystore}"
KEY_ALIAS="${RANTLIST_ANDROID_KEY_ALIAS:-rantlist}"
KEYCHAIN_SERVICE="${RANTLIST_ANDROID_KEYCHAIN_SERVICE:-workwork.rantlist.android.keystore}"
KEYCHAIN_ACCOUNT="${RANTLIST_ANDROID_KEYCHAIN_ACCOUNT:-rantlist}"

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$(uname -s)" == Darwin ]] || die "Android release signing setup currently expects macOS Keychain."
for t in keytool security openssl; do command -v "$t" >/dev/null 2>&1 || die "Required tool missing: $t"; done
if [[ -f "$KEYSTORE_PATH" ]]; then
  printf 'Android release keystore already exists: %s\n' "$KEYSTORE_PATH"
  exit 0
fi
mkdir -p "$(dirname "$KEYSTORE_PATH")"
umask 077
PASSWORD="$(openssl rand -hex 24)"
keytool -genkeypair -v \
  -keystore "$KEYSTORE_PATH" \
  -storepass "$PASSWORD" \
  -keypass "$PASSWORD" \
  -alias "$KEY_ALIAS" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Rantlist, OU=WORKWORK.FUN, O=WORKWORK.FUN"
security add-generic-password -U -a "$KEYCHAIN_ACCOUNT" -s "$KEYCHAIN_SERVICE" -w "$PASSWORD" >/dev/null
chmod 600 "$KEYSTORE_PATH"
printf 'Android release signing created.\nKeystore: %s\nAlias: %s\nPassword: stored in macOS Keychain service %s\n' "$KEYSTORE_PATH" "$KEY_ALIAS" "$KEYCHAIN_SERVICE"
printf 'Back up the keystore securely. The same key must be retained for future Android upgrades.\n'

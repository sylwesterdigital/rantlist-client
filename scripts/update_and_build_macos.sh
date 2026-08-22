#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/scripts/sync_from_stage.sh"
"$ROOT/scripts/verify_client_repo.sh"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION.txt")"
printf 'Building macOS client with Rantlist source version %s\n' "$VERSION"
"$ROOT/scripts/build_macos_release.sh"

#!/usr/bin/env bash
# Compatibility entry point. The real workflow also deploys the Rantlist homepage.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/scripts/release_and_deploy_homepage.sh" "$@"

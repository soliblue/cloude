#!/usr/bin/env bash
set -euo pipefail

UDID="${SIMULATOR_UDID:-booted}"
ROOT_PATH="${1:-$(pwd -P)}"
ENCODED_PATH="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$ROOT_PATH")"

xcrun simctl openurl "$UDID" "cloude://conversation/new?path=${ENCODED_PATH}"

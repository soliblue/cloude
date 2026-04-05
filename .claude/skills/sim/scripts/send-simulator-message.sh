#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <message text>"
  exit 1
fi

UDID="${SIMULATOR_UDID:-booted}"
TEXT="$*"
ENCODED_TEXT="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$TEXT")"

xcrun simctl openurl "$UDID" "cloude://send?text=${ENCODED_TEXT}"

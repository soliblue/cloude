#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <message text>" >&2
  exit 1
fi

UDID="${SIMULATOR_UDID:-booted}"
TEXT="$*"
ENCODED="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$TEXT")"

xcrun simctl openurl "$UDID" "cloude://chat/send?text=${ENCODED}"

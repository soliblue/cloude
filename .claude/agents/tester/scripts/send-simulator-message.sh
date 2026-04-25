#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <message text>" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DISMISSER="$SCRIPT_DIR/../../launcher/dismiss-sim-alerts.sh"
UDID="${SIMULATOR_UDID:-booted}"
TEXT="$*"
ENCODED="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$TEXT")"

if [[ -x "$DISMISSER" ]]; then
  "$DISMISSER" 8 >/dev/null 2>&1 &
fi
xcrun simctl openurl "$UDID" "cloude://chat/send?text=${ENCODED}"
sleep 2

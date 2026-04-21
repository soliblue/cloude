#!/usr/bin/env bash
set -euo pipefail

UDID="${1:-${SIMULATOR_UDID:-booted}}"
BUNDLE="${2:-soli.Cloude}"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
LOG="$CONTAINER/Documents/app-debug.log"

if [[ ! -f "$LOG" ]]; then
  echo "log not found yet: $LOG" >&2
  exit 1
fi

echo "tailing $LOG"
tail -f "$LOG"

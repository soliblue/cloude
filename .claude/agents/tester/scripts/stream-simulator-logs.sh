#!/bin/bash
set -euo pipefail

DEVICE_ID="${1:-booted}"
BUNDLE_ID="${2:-soli.Cloude}"
CONTAINER_PATH="$(xcrun simctl get_app_container "$DEVICE_ID" "$BUNDLE_ID" data)"
LOG_PATH="$CONTAINER_PATH/Documents/app-debug.log"

if [[ ! -f "$LOG_PATH" ]]; then
    echo "App log file not found yet: $LOG_PATH"
    echo "Launch the app and trigger a flow first."
    exit 1
fi

echo "Tailing $LOG_PATH"
tail -f "$LOG_PATH"

#!/bin/zsh
set -euo pipefail

UDID="${SIMULATOR_UDID:-booted}"
APP_CONTAINER="$(xcrun simctl get_app_container "$UDID" soli.Cloude data)"
DEBUG_LOG="$APP_CONTAINER/Documents/debug-metrics.log"
APP_LOG="$APP_CONTAINER/Documents/app-debug.log"

if [[ ! -f "$DEBUG_LOG" ]]; then
  echo "Missing debug log: $DEBUG_LOG" >&2
  exit 1
fi

for source in LiveBubble ConvView MainChat WindowTabBar PageIndicator InputBar; do
  count=$(grep -c "\[$source\]" "$DEBUG_LOG" || true)
  echo "$source: $count renders"
done

echo ""
echo "Recent FPS samples:"

if [[ -f "$APP_LOG" ]]; then
  grep "debug sample" "$APP_LOG" | tail -20 || true
else
  echo "Missing app log: $APP_LOG"
fi

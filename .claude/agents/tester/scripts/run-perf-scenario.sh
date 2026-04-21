#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
UDID="${SIMULATOR_UDID:-booted}"
BUNDLE="soli.Cloude"
SCENARIO_NAME="smoke-hello.txt"
WAIT_SECONDS=60
SKIP_RELAUNCH=1
ENDPOINT_ID="${CLOUDE_DEV_ENV_ID:-c10de51d-5151-4551-8551-0000000c10de}"
SESSION_PATH="${CLOUDE_SESSION_PATH:-$REPO_ROOT}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario) SCENARIO_NAME="$2"; shift 2 ;;
    --wait)     WAIT_SECONDS="$2"; shift 2 ;;
    --path)     SESSION_PATH="$2"; shift 2 ;;
    --no-relaunch) SKIP_RELAUNCH=1; shift ;;
    --relaunch)    SKIP_RELAUNCH=0; shift ;;
    *) echo "unknown: $1" >&2; exit 1 ;;
  esac
done

SCENARIO_PATH="$ROOT/prompts/$SCENARIO_NAME"
if [[ ! -f "$SCENARIO_PATH" ]]; then
  echo "missing prompt: $SCENARIO_PATH" >&2
  exit 1
fi

if [[ "$SKIP_RELAUNCH" -eq 0 ]]; then
  xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl launch "$UDID" "$BUNDLE" >/dev/null
  sleep 2
fi

CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
APP_LOG="$CONTAINER/Documents/app-debug.log"
mkdir -p "$CONTAINER/Documents"
: > "$APP_LOG"

ENCODED_PATH="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$SESSION_PATH")"
xcrun simctl openurl "$UDID" "cloude://session/endpoint?id=$ENDPOINT_ID"
sleep 0.3
xcrun simctl openurl "$UDID" "cloude://session/path?value=$ENCODED_PATH"
sleep 0.3

PROMPT="$(cat "$SCENARIO_PATH")"
"$ROOT/scripts/send-simulator-message.sh" "$PROMPT"

echo "scenario=$SCENARIO_NAME path=$SESSION_PATH timeout=${WAIT_SECONDS}s log=$APP_LOG"

START=$(date +%s)
while true; do
  if grep -q "finish name=chat.complete" "$APP_LOG" 2>/dev/null; then
    echo "completed after $(( $(date +%s) - START ))s"
    break
  fi
  if (( $(date +%s) - START >= WAIT_SECONDS )); then
    echo "timeout after ${WAIT_SECONDS}s"
    break
  fi
  sleep 1
done

echo "--- perf summary ---"
grep -E "name=(chat\.(send|firstToken|complete))" "$APP_LOG" || true

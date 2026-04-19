#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
UDID="${SIMULATOR_UDID:-booted}"
SCENARIO_NAME="mixed-markdown-multi-tool.txt"
WAIT_SECONDS=30
MODEL="haiku"
START_SIMULATOR=1
SKIP_RELAUNCH=0
PRINT_SUMMARY=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SCENARIO_NAME="$2"
      shift 2
      ;;
    --wait)
      WAIT_SECONDS="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    --no-start)
      START_SIMULATOR=0
      shift
      ;;
    --no-relaunch)
      SKIP_RELAUNCH=1
      shift
      ;;
    --no-summary)
      PRINT_SUMMARY=0
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

SCENARIO_PATH="$ROOT/prompts/$SCENARIO_NAME"

if [[ ! -f "$SCENARIO_PATH" ]]; then
  echo "Missing prompt: $SCENARIO_PATH" >&2
  exit 1
fi

if [[ "$START_SIMULATOR" -eq 1 ]]; then
  "$REPO_ROOT/.claude/agents/launcher/start-local-simulator.sh"
fi

if [[ "$SKIP_RELAUNCH" -eq 0 ]]; then
  xcrun simctl spawn "$UDID" defaults write soli.Cloude debugOverlayEnabled -bool true
  xcrun simctl terminate "$UDID" soli.Cloude >/dev/null 2>&1 || true
  sleep 1
  SIMCTL_CHILD_CLOUDE_SKIP_PROMPTS=1 xcrun simctl launch "$UDID" soli.Cloude >/dev/null
  sleep 2
fi

DISMISS_SCRIPT="$REPO_ROOT/.claude/agents/launcher/dismiss-sim-alerts.sh"

APP_CONTAINER="$(xcrun simctl get_app_container "$UDID" soli.Cloude data)"
ENVIRONMENTS_FILE="$APP_CONTAINER/Documents/environments.json"

if [[ ! -f "$ENVIRONMENTS_FILE" ]]; then
  echo "Missing environments file: $ENVIRONMENTS_FILE" >&2
  exit 1
fi

ENVIRONMENT_ID="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[0]["id"])' "$ENVIRONMENTS_FILE")"

"$ROOT/scripts/open-repo-conversation.sh" "$REPO_ROOT"
sleep 2
xcrun simctl openurl "$UDID" "cloude://conversation/environment?id=$ENVIRONMENT_ID"
sleep 1
xcrun simctl openurl "$UDID" "cloude://conversation/model?value=$MODEL"
sleep 2
if [[ -x "$DISMISS_SCRIPT" ]]; then
  "$DISMISS_SCRIPT" 5 >/dev/null 2>&1 || true
fi

DEBUG_LOG="$APP_CONTAINER/Documents/debug-metrics.log"
APP_LOG="$APP_CONTAINER/Documents/app-debug.log"

: > "$DEBUG_LOG"
: > "$APP_LOG"

SCENARIO_TEXT="$(cat "$SCENARIO_PATH")"
"$ROOT/scripts/send-simulator-message.sh" "$SCENARIO_TEXT"

echo "Prompt: $SCENARIO_NAME"
echo "Model: $MODEL"
echo "Timeout: ${WAIT_SECONDS}s"
echo "Logs: $DEBUG_LOG"

WAIT_START=$(date +%s)
while true; do
  if grep -q "finish name=chat.complete" "$APP_LOG" 2>/dev/null; then
    echo "Completed after $(( $(date +%s) - WAIT_START ))s"
    break
  fi
  if (( $(date +%s) - WAIT_START >= WAIT_SECONDS )); then
    echo "Timeout after ${WAIT_SECONDS}s without chat.complete"
    break
  fi
  sleep 1
done

if [[ "$PRINT_SUMMARY" -eq 1 ]]; then
  "$ROOT/scripts/summarize-render-logs.sh"
fi

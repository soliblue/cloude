#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT/../../.." && pwd)"
UDID="${SIMULATOR_UDID:-booted}"
SCENARIO_NAME="mixed-markdown-multi-tool.txt"
WAIT_SECONDS=30
MODEL="haiku"
START_SIMULATOR=1
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

SCENARIO_PATH="$ROOT/scenarios/$SCENARIO_NAME"

if [[ ! -f "$SCENARIO_PATH" ]]; then
  echo "Missing scenario: $SCENARIO_PATH" >&2
  exit 1
fi

if [[ "$START_SIMULATOR" -eq 1 ]]; then
  "$REPO_ROOT/.claude/skills/agentic-testing/start-local-simulator.sh"
fi

xcrun simctl spawn "$UDID" defaults write soli.Cloude debugOverlayEnabled -bool true
xcrun simctl terminate "$UDID" soli.Cloude >/dev/null 2>&1 || true
sleep 1
xcrun simctl launch "$UDID" soli.Cloude >/dev/null
sleep 2

APP_CONTAINER="$(xcrun simctl get_app_container "$UDID" soli.Cloude data)"
ENVIRONMENTS_FILE="$APP_CONTAINER/Documents/environments.json"

if [[ ! -f "$ENVIRONMENTS_FILE" ]]; then
  echo "Missing environments file: $ENVIRONMENTS_FILE" >&2
  exit 1
fi

ENVIRONMENT_ID="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))[0]["id"])' "$ENVIRONMENTS_FILE")"

xcrun simctl openurl "$UDID" "cloude://environment/select?id=$ENVIRONMENT_ID"
sleep 1
xcrun simctl openurl "$UDID" "cloude://environment/connect?id=$ENVIRONMENT_ID"
sleep 2

"$REPO_ROOT/.claude/skills/agentic-testing/open-repo-conversation.sh" "$REPO_ROOT"
sleep 2
xcrun simctl openurl "$UDID" "cloude://conversation/environment?id=$ENVIRONMENT_ID"
sleep 1
xcrun simctl openurl "$UDID" "cloude://conversation/model?value=$MODEL"
sleep 1

DEBUG_LOG="$APP_CONTAINER/Documents/debug-metrics.log"
APP_LOG="$APP_CONTAINER/Documents/app-debug.log"

: > "$DEBUG_LOG"
: > "$APP_LOG"

SCENARIO_TEXT="$(cat "$SCENARIO_PATH")"
"$REPO_ROOT/.claude/skills/agentic-testing/send-simulator-message.sh" "$SCENARIO_TEXT"

echo "Scenario: $SCENARIO_NAME"
echo "Model: $MODEL"
echo "Wait: ${WAIT_SECONDS}s"
echo "Logs: $DEBUG_LOG"

sleep "$WAIT_SECONDS"

if [[ "$PRINT_SUMMARY" -eq 1 ]]; then
  "$ROOT/scripts/summarize-render-logs.sh"
fi

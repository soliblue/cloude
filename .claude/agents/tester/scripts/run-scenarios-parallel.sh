#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$ROOT/output"
mkdir -p "$OUTPUT_DIR"

if [[ $# -eq 0 ]]; then
  cat <<USAGE >&2
Usage: $0 <udid>:<scenario-file> [<udid>:<scenario-file>...]

Env:
  MODEL         model to use for each run (default: haiku)
  WAIT_SECONDS  timeout per scenario (default: 30)

Each <udid>:<scenario> pair runs in parallel via run-perf-scenario.sh
with --no-start --no-relaunch (trusts launcher-prepared app state).
USAGE
  exit 1
fi

MODEL="${MODEL:-haiku}"
WAIT_SECONDS="${WAIT_SECONDS:-30}"
STAMP="$(date +%Y%m%d-%H%M%S)"

UDIDS=()
SCENARIOS=()
PIDS=()
LOGS=()

for pair in "$@"; do
  UDID="${pair%%:*}"
  SCENARIO="${pair#*:}"
  SAFE="${SCENARIO//\//-}"
  SAFE="${SAFE%.txt}"
  LOG_FILE="$OUTPUT_DIR/parallel-$STAMP-$UDID-$SAFE.log"

  echo "Dispatching: udid=$UDID scenario=$SCENARIO -> $LOG_FILE"
  SIMULATOR_UDID="$UDID" "$ROOT/scripts/run-perf-scenario.sh" \
    --scenario "$SCENARIO" \
    --wait "$WAIT_SECONDS" \
    --model "$MODEL" \
    --no-start \
    --no-relaunch \
    --no-summary \
    > "$LOG_FILE" 2>&1 &
  PIDS+=($!)
  UDIDS+=("$UDID")
  SCENARIOS+=("$SCENARIO")
  LOGS+=("$LOG_FILE")
done

echo ""
echo "Waiting for ${#PIDS[@]} parallel scenario(s)..."

FAILURES=()
for i in {1..${#PIDS[@]}}; do
  if ! wait "${PIDS[$i]}"; then
    FAILURES+=("udid=${UDIDS[$i]} scenario=${SCENARIOS[$i]}")
  fi
done

for i in {1..${#LOGS[@]}}; do
  echo ""
  echo "=== udid=${UDIDS[$i]} scenario=${SCENARIOS[$i]} ==="
  cat "${LOGS[$i]}"
  echo ""
  echo "--- render summary ---"
  SIMULATOR_UDID="${UDIDS[$i]}" "$ROOT/scripts/summarize-render-logs.sh" || echo "(summary failed)"
done

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo ""
  echo "Failures:"
  for f in "${FAILURES[@]}"; do
    echo "  $f"
  done
  exit 1
fi

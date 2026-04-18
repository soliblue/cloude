#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SECONDARY_SCENARIO=""
WAIT_SECONDS=45
MODEL="haiku"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)
      SECONDARY_SCENARIO="$2"
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
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$SECONDARY_SCENARIO" ]]; then
  cat <<MSG >&2
Usage: $0 --scenario <scenario-file> [--wait 45] [--model haiku]

This runner always executes:
1. mixed-markdown-multi-tool.txt
2. the explicit secondary scenario you pass in

It is a triage aid, not a pass/fail verdict.
MSG
  exit 1
fi

run_scenario() {
  local scenario_name="$1"
  echo ""
  echo "=== Scenario: $scenario_name ==="
  "$ROOT/scripts/run-perf-scenario.sh" --scenario "$scenario_name" --wait "$WAIT_SECONDS" --model "$MODEL"
}

echo "Performance regression suite"
echo "Model: $MODEL"
echo "Wait per scenario: ${WAIT_SECONDS}s"
echo "Summary: triage aid only, not pass/fail"

run_scenario mixed-markdown-multi-tool.txt

if [[ "$SECONDARY_SCENARIO" != "mixed-markdown-multi-tool.txt" ]]; then
  run_scenario "$SECONDARY_SCENARIO"
fi

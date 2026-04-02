#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cat <<MSG
Performance regression suite

Run at least these scenarios during review:
- mixed-markdown-multi-tool.txt
- any scenario named in the active perf plan
- any scenario added by the current round

Suggested order:
1. $ROOT/scripts/run-perf-scenario.sh --scenario mixed-markdown-multi-tool.txt --wait 45
2. Replay the exact investigation scenario from the plan
3. If the fix touched tracing-sensitive code, also read:
   $ROOT/scenarios/deep-trace-checklist.md
4. Summarize logs with:
   $ROOT/scripts/summarize-render-logs.sh

This script is intentionally lightweight. Expand it when a real round proves a better automated sequence.
MSG

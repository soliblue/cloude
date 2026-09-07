#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-attention.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
chmod +x "$ROOT/tests/fake-codex-attention.py"
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexClient.swift" "$ROOT/tests/CodexAttentionTests.swift" -o "$TEMP/attention-tests"
"$TEMP/attention-tests" "$ROOT/tests/fake-codex-attention.py"

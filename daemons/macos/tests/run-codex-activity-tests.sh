#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-activity.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexTerminalRequest.swift" "$ROOT/tests/CodexActivityTests.swift" -o "$TEMP/activity-tests"
env -u CODEX_HOME "$TEMP/activity-tests" "$ROOT/tests/fake-codex-app-server.py"

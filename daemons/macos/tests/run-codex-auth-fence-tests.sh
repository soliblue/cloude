#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-auth-fence.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexTerminalRequest.swift" "$ROOT/tests/CodexAuthFenceTests.swift" -o "$TEMP/auth-fence-tests"
env -u CODEX_HOME "$TEMP/auth-fence-tests" "$ROOT/tests/fake-codex-app-server.py"

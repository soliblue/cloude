#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-daemon-lifecycle.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/tests/DaemonLifecycleTests.swift" -o "$TEMP/lifecycle-tests"
"$TEMP/lifecycle-tests"

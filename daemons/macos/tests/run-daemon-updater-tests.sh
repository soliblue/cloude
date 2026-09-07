#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-daemon-updater.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/Version.swift" "$ROOT/src/Updater/DaemonVersionCompare.swift" "$ROOT/src/Updater/DaemonUpdater.swift" "$ROOT/tests/updater/RunnerManager.swift" "$ROOT/tests/DaemonUpdaterTests.swift" -o "$TEMP/updater-tests"
"$TEMP/updater-tests"

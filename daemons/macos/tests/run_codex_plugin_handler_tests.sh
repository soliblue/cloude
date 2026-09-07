#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-plugins.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/Handlers/CodexPluginHandler.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPResponse.swift" "$ROOT/src/DaemonCapabilities.swift" "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/Version.swift" "$ROOT/tests/CodexPluginHandlerTests.swift" -o "$TEMP/plugin-tests"
"$TEMP/plugin-tests"

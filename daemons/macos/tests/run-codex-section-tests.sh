#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-sections.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/Version.swift" "$ROOT/src/DaemonCapabilities.swift" "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPRequestCancellation.swift" "$ROOT/src/Networking/HTTPResponse.swift" "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/Handlers/CodexSectionHandler.swift" "$ROOT/tests/CodexSectionHandlerTests.swift" -o "$TEMP/sections"
"$TEMP/sections"

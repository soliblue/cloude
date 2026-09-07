#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-codex-handlers.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexLoginService.swift" "$ROOT/src/Handlers/CodexHandler.swift" "$ROOT/src/CodexForkReceiptStore.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexSessionStore.swift" "$ROOT/src/CodexPersistence.swift" "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPRequestCancellation.swift" "$ROOT/src/Networking/HTTPResponse.swift" "$ROOT/src/DaemonCapabilities.swift" "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/Version.swift" "$ROOT/tests/CodexHandlerRunnerFixture.swift" "$ROOT/tests/CodexHandlerTranscribeFixture.swift" "$ROOT/tests/CodexHandlerTests.swift" -o "$TEMP/handler-tests"
"$TEMP/handler-tests"

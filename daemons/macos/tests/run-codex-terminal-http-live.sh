#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-native-live-terminal.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexSubscriptionPolicy.swift" \
  "$ROOT/src/CodexTerminal.swift" "$ROOT/src/CodexTerminalEntry.swift" "$ROOT/src/CodexTerminalInput.swift" \
  "$ROOT/src/CodexTerminalStart.swift" "$ROOT/src/CodexTerminalRequest.swift" "$ROOT/src/CodexTerminalStream.swift" \
  "$ROOT/src/Handlers/CodexTerminalHandler.swift" "$ROOT/src/Networking/HTTPServer.swift" \
  "$ROOT/src/Networking/HTTPResponse.swift" "$ROOT/src/Networking/HTTPRequest.swift" \
  "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/Routing/DaemonAuth.swift" "$ROOT/src/Routing/AuthMiddleware.swift" \
  "$ROOT/src/Storage/KeychainStore.swift" "$ROOT/src/Version.swift" "$ROOT/src/DaemonCapabilities.swift" \
  "$ROOT/tests/terminal-http/Router.swift" "$ROOT/tests/terminal-http/CodexTerminalHTTPMain.swift" -o "$TEMP/terminal-http"
python3 "$ROOT/tests/terminal-http/verify.py" "$TEMP" "$(command -v codex)"

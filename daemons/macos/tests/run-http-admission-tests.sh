#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-native-http-admission.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
swiftc "$ROOT/src/Networking/HTTPConnection.swift" "$ROOT/src/Networking/HTTPRequest.swift" \
  "$ROOT/src/Networking/HTTPRequestCancellation.swift" "$ROOT/src/Networking/HTTPResponse.swift" \
  "$ROOT/src/Routing/AuthMiddleware.swift" "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/DaemonLifecycle.swift" \
  "$ROOT/tests/http-admission/"*.swift -o "$TEMP/http-fixture"
python3 "$ROOT/tests/http-admission/verify.py" "$TEMP/http-fixture" "$TEMP"

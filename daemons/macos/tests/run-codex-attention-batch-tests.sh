#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d /tmp/afto-native-attention-batch.XXXXXX)"
trap 'rm -rf "$TEMP"' EXIT
mkdir -p "$TEMP/router-fixtures" "$TEMP/codex"
python3 - "$ROOT/src/Routing/Router.swift" "$TEMP/router-fixtures" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text()
handlers = {}
for handler, method in re.findall(r'(\w+Handler)\.(\w+)\(request', source):
    if handler != 'CodexAttentionHandler':
        handlers.setdefault(handler, set()).add(method)
for handler, methods in handlers.items():
    Path(sys.argv[2], handler + '.swift').write_text('enum ' + handler + ' {\n' + '\n'.join(
        '    static func ' + method + '(_ request: HTTPRequest, params: [String: String] = [:]) -> HTTPResponse { HTTPResponse.json(404, ["error": "fixture_unhandled"]) }'
        for method in sorted(methods)) + '\n}\n')
PY
swiftc "$ROOT/src/DaemonLifecycle.swift" "$ROOT/src/CodexClient.swift" "$ROOT/src/CodexSessionStore.swift" \
  "$ROOT/src/CodexPersistence.swift" "$ROOT/src/Handlers/CodexAttentionHandler.swift" "$ROOT/src/Networking/HTTPConnection.swift" \
  "$ROOT/src/Networking/HTTPRequest.swift" "$ROOT/src/Networking/HTTPRequestCancellation.swift" "$ROOT/src/Networking/HTTPResponse.swift" \
  "$ROOT/src/Routing/Router.swift" "$ROOT/src/Routing/RouteMatcher.swift" "$ROOT/src/Routing/AuthMiddleware.swift" \
  "$ROOT/src/DaemonCapabilities.swift" "$ROOT/src/Version.swift" "$TEMP/router-fixtures/"*.swift \
  "$ROOT/tests/attention-batch/DaemonAuth.swift" "$ROOT/tests/attention-batch/AttentionBatchFixture.swift" -o "$TEMP/attention-fixture"
chmod +x "$ROOT/tests/attention-batch/fake-codex.py"
CLOUDE_DATA="$TEMP/state" CODEX_HOME="$TEMP/codex" CLOUDE_CODEX_BIN="$ROOT/tests/attention-batch/fake-codex.py" \
  python3 "$ROOT/tests/attention-batch/verify.py" "$TEMP/attention-fixture" "$TEMP/codex/rpc.jsonl"

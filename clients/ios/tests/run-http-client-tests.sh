#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
server_pid=
trap '[ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true; [ -z "$server_pid" ] || wait "$server_pid" 2>/dev/null || true; rm -rf "$test_dir"' EXIT
python3 tests/http-client/server.py "$test_dir/port" >"$test_dir/server.log" 2>&1 &
server_pid=$!
for attempt in {1..100}; do
  [ -s "$test_dir/port" ] && break
  sleep 0.05
done
[ -s "$test_dir/port" ]
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" src/Core/Networking/HTTPClient.swift src/Core/Networking/HTTPBoundedDownload.swift src/Features/Endpoints/Logic/Endpoint.swift tests/http-client/*.swift -o "$test_dir/http-client-tests"
"$test_dir/http-client-tests" "$(cat "$test_dir/port")"

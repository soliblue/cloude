#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
python3 tests/file-html/server.py "$test_dir/port" &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; rm -rf "$test_dir"' EXIT
for attempt in {1..50}; do
  test -s "$test_dir/port" && break
  sleep 0.1
done
swiftc -parse-as-library -target "$(uname -m)-apple-macosx14.0" \
  src/Features/Files/Logic/FilePreviewHTML{Policy,Controller}.swift \
  tests/file-html/main.swift -o "$test_dir/file-html-tests"
if "$test_dir/file-html-tests" "$(cat "$test_dir/port")" > "$test_dir/result" 2>&1; then
  tail -n 1 "$test_dir/result"
else
  cat "$test_dir/result"
  exit 1
fi

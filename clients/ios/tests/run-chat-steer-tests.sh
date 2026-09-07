#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
python3 - "$test_dir/ChatService.swift" <<'PY'
import pathlib
import sys
source = pathlib.Path('src/Features/Chat/Logic/ChatService.swift').read_text()
start = source.index('    static func steer(')
end = source.index('\n    @MainActor', start)
pathlib.Path(sys.argv[1]).write_text('import Foundation\nimport SwiftData\n@MainActor enum ChatService {\n' + source[start:end] + '\n}\n')
PY
swiftc -parse-as-library -default-isolation MainActor -target "$(uname -m)-apple-macosx14.0" \
  "$test_dir/ChatService.swift" src/Features/Chat/Logic/Chat{Message,Reference,ReviewKind,ReviewTarget,Provider}.swift \
  tests/chat-steer/*.swift -o "$test_dir/steer-tests"
"$test_dir/steer-tests"
